use std::net::{SocketAddr, UdpSocket};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use axum::extract::State;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::Json;
use tokio::sync::Mutex;

use crate::api::state::ApiState;
use crate::api::types::*;
use crate::discovery;
use crate::dlna::transport;
use crate::dlna::types::PlaybackState;
use crate::server;

const SUPPORTED_EXTENSIONS: &[&str] = &["mp4", "mkv", "avi", "webm", "mov"];

type SharedState = Arc<Mutex<ApiState>>;
type AppState = (SharedState, tokio::sync::watch::Receiver<bool>);

fn err(status: StatusCode, msg: impl Into<String>) -> (StatusCode, Json<ErrorResponse>) {
    (
        status,
        Json(ErrorResponse {
            error: msg.into(),
        }),
    )
}

/// POST /api/select-file
/// Validates file, starts media HTTP server, stores file info.
pub async fn select_file(
    State((state, _first_disc_rx)): State<AppState>,
    Json(req): Json<SelectFileRequest>,
) -> impl IntoResponse {
    let path = PathBuf::from(&req.file_path);

    // Validate file exists
    let path = match path.canonicalize() {
        Ok(p) => p,
        Err(_) => return err(StatusCode::BAD_REQUEST, "File not found").into_response(),
    };

    if !path.is_file() {
        return err(StatusCode::BAD_REQUEST, "Not a file").into_response();
    }

    // Validate extension
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_lowercase())
        .unwrap_or_default();

    if !SUPPORTED_EXTENSIONS.contains(&ext.as_str()) {
        return err(
            StatusCode::BAD_REQUEST,
            format!(
                "Unsupported file type: .{}. Supported: {}",
                ext,
                SUPPORTED_EXTENSIONS.join(", ")
            ),
        )
        .into_response();
    }

    let file_name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let file_size = match std::fs::metadata(&path) {
        Ok(m) => m.len(),
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Cannot read file: {e}")).into_response(),
    };

    let mime_type = mime_guess::from_path(&path)
        .first_or_octet_stream()
        .to_string();

    // Stop previous media server if running
    {
        let mut s = state.lock().await;
        if let Some(handle) = s.media_server_handle.take() {
            handle.abort();
        }
    }

    // Start media server
    let (addr, serve_path, server_handle) = match server::start_server(path.clone(), 0).await {
        Ok(v) => v,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to start media server: {e}")).into_response(),
    };

    let mut s = state.lock().await;
    s.file_path = Some(path.to_string_lossy().to_string());
    s.file_name = Some(file_name.clone());
    s.file_size = file_size;
    s.mime_type = Some(mime_type.clone());
    s.media_server_handle = Some(server_handle);
    s.serve_path = Some(serve_path);
    s.server_port = addr.port();

    (
        StatusCode::OK,
        Json(FileInfoResponse {
            file_name,
            file_size,
            mime_type,
        }),
    )
        .into_response()
}

/// GET /api/discover
/// Returns cached device list. If first discovery hasn't completed yet, waits for it.
pub async fn discover(State((state, first_disc_rx)): State<AppState>) -> impl IntoResponse {
    // Wait until first background discovery has completed
    {
        let mut rx = first_disc_rx.clone();
        // If already true, this returns immediately. Otherwise waits for the sender to set true.
        while !*rx.borrow_and_update() {
            if rx.changed().await.is_err() {
                // Sender dropped — should never happen, but don't block forever
                break;
            }
        }
    }

    let s = state.lock().await;
    (StatusCode::OK, Json(s.device_list_response())).into_response()
}

/// POST /api/discover/refresh
/// Forces a synchronous SSDP scan (5s) and returns the result.
/// Used as a manual refresh fallback when background discovery fails or user wants a fresh scan.
pub async fn discover_refresh(State((state, _first_disc_rx)): State<AppState>) -> impl IntoResponse {
    // If discovery fails (e.g. no network permission), keep existing cache unchanged.
    let devices = match discovery::discover_devices(Duration::from_secs(5)).await {
        Ok(d) => d,
        Err(e) => {
            tracing::warn!("Manual discovery failed: {e}");
            let s = state.lock().await;
            return (StatusCode::OK, Json(s.device_list_response())).into_response();
        }
    };

    let mut s = state.lock().await;
    merge_devices(&mut s, devices);

    // Broadcast updated device list via SSE
    let response = s.device_list_response();
    let _ = s.devices_tx.send(response.clone());

    (StatusCode::OK, Json(response)).into_response()
}

/// POST /api/select-device
/// Stores selected device and resolves control URL.
pub async fn select_device(
    State((state, _first_disc_rx)): State<AppState>,
    Json(req): Json<SelectDeviceRequest>,
) -> impl IntoResponse {
    let device = {
        let s = state.lock().await;
        if req.device_index >= s.devices.len() {
            return err(StatusCode::BAD_REQUEST, "Invalid device index").into_response();
        }
        s.devices[req.device_index].clone()
    };

    // Resolve control URL
    let control_url = match transport::resolve_control_url(&device).await {
        Ok(url) => url,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to resolve control URL: {e}")).into_response(),
    };

    let mut s = state.lock().await;
    s.selected_device = Some(req.device_index);
    s.control_url = Some(control_url);

    (StatusCode::OK, Json(OkResponse::new())).into_response()
}

/// POST /api/cast
/// Sets AV transport URI + Play, starts status poller.
pub async fn cast(State((state, _first_disc_rx)): State<AppState>) -> impl IntoResponse {
    let (device, control_url, serve_path, server_port, file_name, mime_type, file_size) = {
        let s = state.lock().await;
        let device = match s.current_device().cloned() {
            Some(d) => d,
            None => return err(StatusCode::BAD_REQUEST, "No device selected").into_response(),
        };
        let control_url = match &s.control_url {
            Some(u) => u.clone(),
            None => return err(StatusCode::BAD_REQUEST, "No control URL resolved").into_response(),
        };
        let serve_path = match &s.serve_path {
            Some(p) => p.clone(),
            None => return err(StatusCode::BAD_REQUEST, "No file selected").into_response(),
        };
        let file_name = s.file_name.clone().unwrap_or_default();
        let mime_type = s.mime_type.clone().unwrap_or_default();
        (device, control_url, serve_path, s.server_port, file_name, mime_type, s.file_size)
    };

    // Build media URL based on device IP
    let media_url = match media_url_for_device(&device, server_port, &serve_path) {
        Ok(u) => u,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Cannot determine media URL: {e}")).into_response(),
    };

    // Set URI
    if let Err(e) = transport::set_av_transport_uri(
        &device,
        &control_url,
        &media_url,
        &file_name,
        &mime_type,
        file_size,
    )
    .await
    {
        return err(StatusCode::INTERNAL_SERVER_ERROR, format!("SetAVTransportURI failed: {e}")).into_response();
    }

    // Play
    if let Err(e) = transport::play(&device, &control_url).await {
        return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Play failed: {e}")).into_response();
    }

    // Update state and start poller
    {
        let mut s = state.lock().await;
        s.playback_state = PlaybackState::Playing;

        // Stop previous poller
        if let Some(handle) = s.poller_handle.take() {
            handle.abort();
        }

        // Start poller
        let poller_device = device.clone();
        let poller_control_url = control_url.clone();
        let poller_state = state.clone();
        let handle = tokio::spawn(async move {
            playback_poller(poller_device, poller_control_url, poller_state).await;
        });
        s.poller_handle = Some(handle);
    }

    (StatusCode::OK, Json(OkResponse::new())).into_response()
}

/// POST /api/play
pub async fn play(State((state, _first_disc_rx)): State<AppState>) -> impl IntoResponse {
    let (device, control_url) = {
        let s = state.lock().await;
        match (s.current_device().cloned(), s.control_url.clone()) {
            (Some(d), Some(u)) => (d, u),
            _ => return err(StatusCode::BAD_REQUEST, "No device selected").into_response(),
        }
    };

    if let Err(e) = transport::play(&device, &control_url).await {
        return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Play failed: {e}")).into_response();
    }

    state.lock().await.playback_state = PlaybackState::Playing;
    (StatusCode::OK, Json(OkResponse::new())).into_response()
}

/// POST /api/pause
pub async fn pause(State((state, _first_disc_rx)): State<AppState>) -> impl IntoResponse {
    let (device, control_url) = {
        let s = state.lock().await;
        match (s.current_device().cloned(), s.control_url.clone()) {
            (Some(d), Some(u)) => (d, u),
            _ => return err(StatusCode::BAD_REQUEST, "No device selected").into_response(),
        }
    };

    if let Err(e) = transport::pause(&device, &control_url).await {
        return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Pause failed: {e}")).into_response();
    }

    state.lock().await.playback_state = PlaybackState::Paused;
    (StatusCode::OK, Json(OkResponse::new())).into_response()
}

/// POST /api/stop
pub async fn stop(State((state, _first_disc_rx)): State<AppState>) -> impl IntoResponse {
    let (device, control_url) = {
        let s = state.lock().await;
        match (s.current_device().cloned(), s.control_url.clone()) {
            (Some(d), Some(u)) => (d, u),
            _ => return err(StatusCode::BAD_REQUEST, "No device selected").into_response(),
        }
    };

    if let Err(e) = transport::stop(&device, &control_url).await {
        return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Stop failed: {e}")).into_response();
    }

    let mut s = state.lock().await;
    s.playback_state = PlaybackState::Stopped;

    // Stop poller
    if let Some(handle) = s.poller_handle.take() {
        handle.abort();
    }

    (StatusCode::OK, Json(OkResponse::new())).into_response()
}

/// POST /api/seek
pub async fn seek(
    State((state, _first_disc_rx)): State<AppState>,
    Json(req): Json<SeekRequest>,
) -> impl IntoResponse {
    let (device, control_url) = {
        let s = state.lock().await;
        match (s.current_device().cloned(), s.control_url.clone()) {
            (Some(d), Some(u)) => (d, u),
            _ => return err(StatusCode::BAD_REQUEST, "No device selected").into_response(),
        }
    };

    if let Err(e) = transport::seek(&device, &control_url, req.position_secs).await {
        return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Seek failed: {e}")).into_response();
    }

    (StatusCode::OK, Json(OkResponse::new())).into_response()
}

/// GET /api/status
pub async fn status(State((state, _first_disc_rx)): State<AppState>) -> impl IntoResponse {
    let s = state.lock().await;
    (StatusCode::OK, Json(s.status_response()))
}

// --- Helpers ---

fn local_ip_for(target: &str) -> anyhow::Result<std::net::IpAddr> {
    let target_addr: SocketAddr = if target.contains(':') {
        target.parse()?
    } else {
        format!("{target}:80").parse()?
    };
    let socket = UdpSocket::bind("0.0.0.0:0")?;
    socket.connect(target_addr)?;
    Ok(socket.local_addr()?.ip())
}

fn media_url_for_device(
    device: &crate::dlna::types::DlnaDevice,
    server_port: u16,
    serve_path: &str,
) -> anyhow::Result<String> {
    let device_host = device
        .device_url
        .host()
        .ok_or_else(|| anyhow::anyhow!("Device URL has no host"))?;
    let local_ip = local_ip_for(device_host)?;
    Ok(format!("http://{}:{}{}", local_ip, server_port, serve_path))
}

/// Background poller that queries the device for position/state and updates ApiState + broadcasts via SSE.
async fn playback_poller(
    device: crate::dlna::types::DlnaDevice,
    control_url: String,
    state: SharedState,
) {
    let mut interval = tokio::time::interval(Duration::from_secs(1));
    loop {
        interval.tick().await;

        // Get position info
        if let Ok(pos) = transport::get_position_info(&device, &control_url).await {
            let mut s = state.lock().await;
            s.position = pos;
        }

        // Get transport state
        if let Ok(new_state) = transport::get_transport_info(&device, &control_url).await {
            let mut s = state.lock().await;
            s.playback_state = new_state;
        }

        // Broadcast status update
        let status = {
            let s = state.lock().await;
            s.status_response()
        };
        let s = state.lock().await;
        let _ = s.status_tx.send(status);
    }
}

/// Background loop that continuously discovers DLNA devices.
/// Runs every 5 seconds on success, or retries after 1 second on failure (e.g. no network permission).
pub async fn background_discovery_loop(state: SharedState, first_disc_tx: tokio::sync::watch::Sender<bool>) {
    let mut is_first = true;
    loop {
        tracing::debug!("Background discovery: starting scan");
        let scan_failed = match discovery::discover_devices(Duration::from_secs(5)).await {
            Ok(new_devices) => {
                let mut s = state.lock().await;
                merge_devices(&mut s, new_devices);

                // Broadcast device list update via SSE
                let response = s.device_list_response();
                let _ = s.devices_tx.send(response);

                tracing::debug!("Background discovery: found {} devices", s.devices.len());
                false
            }
            Err(e) => {
                tracing::warn!("Background discovery failed: {e}");
                true
            }
        };

        if is_first {
            is_first = false;
            let _ = first_disc_tx.send(true);
        }

        let sleep_secs = if scan_failed { 1 } else { 5 };
        tokio::time::sleep(Duration::from_secs(sleep_secs)).await;
    }
}

/// Merge newly discovered devices into the existing list with stable ordering:
/// - Existing devices keep their position (matched by device_url)
/// - Devices no longer found are removed
/// - New devices are appended at the end
/// - If a device was selected, its selection is preserved by matching device_url
fn merge_devices(state: &mut ApiState, new_devices: Vec<crate::dlna::types::DlnaDevice>) {
    use std::collections::HashSet;

    let new_urls: HashSet<String> = new_devices.iter().map(|d| d.device_url.to_string()).collect();

    // Remember selected device URL before mutation
    let selected_url = state.current_device().map(|d| d.device_url.to_string());

    // Keep existing devices that are still present, in their original order
    let mut merged: Vec<crate::dlna::types::DlnaDevice> = state
        .devices
        .drain(..)
        .filter(|d| new_urls.contains(&d.device_url.to_string()))
        .collect();

    // Collect URLs of devices we kept
    let existing_urls: HashSet<String> = merged.iter().map(|d| d.device_url.to_string()).collect();

    // Append new devices that weren't in the old list
    for device in new_devices {
        if !existing_urls.contains(&device.device_url.to_string()) {
            merged.push(device);
        }
    }

    state.devices = merged;

    // Restore selected_device index by matching URL
    if let Some(url) = selected_url {
        state.selected_device = state.devices.iter().position(|d| d.device_url.to_string() == url);
        if state.selected_device.is_none() {
            // Selected device disappeared from the network
            state.control_url = None;
        }
    }
}
