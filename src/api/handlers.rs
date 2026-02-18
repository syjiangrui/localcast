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

const SUPPORTED_EXTENSIONS: &[&str] = &["mp4", "mkv", "avi", "webm"];

type SharedState = Arc<Mutex<ApiState>>;

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
    State(state): State<SharedState>,
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
/// Runs SSDP discovery and returns device list.
pub async fn discover(State(state): State<SharedState>) -> impl IntoResponse {
    let devices = match discovery::discover_devices(Duration::from_secs(5)).await {
        Ok(d) => d,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, format!("Discovery failed: {e}")).into_response(),
    };

    let response_devices: Vec<DeviceResponse> = devices
        .iter()
        .enumerate()
        .map(|(i, d)| DeviceResponse {
            index: i,
            friendly_name: d.friendly_name.clone(),
            device_url: d.device_url.to_string(),
        })
        .collect();

    let mut s = state.lock().await;
    s.devices = devices;
    s.selected_device = None;
    s.control_url = None;

    (StatusCode::OK, Json(DeviceListResponse { devices: response_devices })).into_response()
}

/// POST /api/select-device
/// Stores selected device and resolves control URL.
pub async fn select_device(
    State(state): State<SharedState>,
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
pub async fn cast(State(state): State<SharedState>) -> impl IntoResponse {
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
pub async fn play(State(state): State<SharedState>) -> impl IntoResponse {
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
pub async fn pause(State(state): State<SharedState>) -> impl IntoResponse {
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
pub async fn stop(State(state): State<SharedState>) -> impl IntoResponse {
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
    State(state): State<SharedState>,
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
pub async fn status(State(state): State<SharedState>) -> impl IntoResponse {
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
