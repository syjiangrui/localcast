use std::net::{SocketAddr, UdpSocket};
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::{Context, Result};
use axum::extract::{Request, State};
use axum::http::{header, HeaderMap, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use axum::Router;
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncSeekExt};
use tokio_util::io::ReaderStream;

use crate::dlna::types::DlnaDevice;

/// Shared state for the HTTP server.
#[derive(Clone)]
pub struct ServerState {
    pub file_path: Arc<PathBuf>,
    pub file_size: u64,
    pub mime_type: String,
    pub file_name: String,
}

/// Start the HTTP media server. Returns (bound address, serve path, task handle).
pub async fn start_server(
    file_path: PathBuf,
    port: u16,
) -> anyhow::Result<(SocketAddr, String, tokio::task::JoinHandle<()>)> {
    let metadata = tokio::fs::metadata(&file_path).await?;
    let file_size = metadata.len();

    let file_name = file_path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let mime_type = mime_guess::from_path(&file_path)
        .first_or_octet_stream()
        .to_string();

    let state = ServerState {
        file_path: Arc::new(file_path),
        file_size,
        mime_type,
        file_name,
    };

    // Use a simple fixed path to avoid issues with complex filenames on DLNA TVs
    let ext = std::path::Path::new(&state.file_name)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("mp4");
    let serve_path = format!("/media/stream.{ext}");

    let app = Router::new()
        .route(&serve_path, get(serve_media))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await?;
    let bound_addr = listener.local_addr()?;

    let handle = tokio::spawn(async move {
        if let Err(e) = axum::serve(listener, app).await {
            tracing::error!("HTTP server error: {e}");
        }
    });

    tracing::info!("HTTP server listening on {bound_addr}, path: {serve_path}");
    Ok((bound_addr, serve_path, handle))
}

/// Handle GET requests for the media file, with Range support.
async fn serve_media(State(state): State<ServerState>, request: Request) -> Response {
    let range_header = request
        .headers()
        .get(header::RANGE)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    let file_size = state.file_size;

    // Parse Range header: "bytes=START-END" or "bytes=START-"
    let (start, end) = match &range_header {
        Some(range) => match parse_range(range, file_size) {
            Some((s, e)) => (s, e),
            None => {
                return (
                    StatusCode::RANGE_NOT_SATISFIABLE,
                    [(header::CONTENT_RANGE, format!("bytes */{file_size}"))],
                    "Invalid Range",
                )
                    .into_response();
            }
        },
        None => (0, file_size - 1),
    };

    let content_length = end - start + 1;

    // Open file and seek to start position
    let file = match File::open(state.file_path.as_ref()).await {
        Ok(f) => f,
        Err(e) => {
            tracing::error!("Failed to open file: {e}");
            return StatusCode::INTERNAL_SERVER_ERROR.into_response();
        }
    };

    let mut file = file;
    if start > 0 {
        if let Err(e) = file.seek(std::io::SeekFrom::Start(start)).await {
            tracing::error!("Failed to seek: {e}");
            return StatusCode::INTERNAL_SERVER_ERROR.into_response();
        }
    }

    // Limit read to content_length bytes
    let limited = file.take(content_length);
    let stream = ReaderStream::new(limited);
    let body = axum::body::Body::from_stream(stream);

    let status = if range_header.is_some() {
        StatusCode::PARTIAL_CONTENT
    } else {
        StatusCode::OK
    };

    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_str(&state.mime_type).unwrap_or(HeaderValue::from_static("application/octet-stream")),
    );
    headers.insert(
        header::CONTENT_LENGTH,
        HeaderValue::from_str(&content_length.to_string()).unwrap(),
    );
    headers.insert(header::ACCEPT_RANGES, HeaderValue::from_static("bytes"));

    if range_header.is_some() {
        let range_val = format!("bytes {start}-{end}/{file_size}");
        headers.insert(
            header::CONTENT_RANGE,
            HeaderValue::from_str(&range_val).unwrap(),
        );
    }

    (status, headers, body).into_response()
}

/// Parse a Range header value like "bytes=0-1023" or "bytes=1024-".
/// Returns Some((start, end)) inclusive, or None if invalid.
fn parse_range(range: &str, file_size: u64) -> Option<(u64, u64)> {
    let range = range.strip_prefix("bytes=")?;
    let mut parts = range.splitn(2, '-');
    let start_str = parts.next()?.trim();
    let end_str = parts.next()?.trim();

    if start_str.is_empty() {
        // Suffix range: "bytes=-500" means last 500 bytes
        let suffix: u64 = end_str.parse().ok()?;
        if suffix > file_size {
            return Some((0, file_size - 1));
        }
        let start = file_size - suffix;
        return Some((start, file_size - 1));
    }

    let start: u64 = start_str.parse().ok()?;
    let end = if end_str.is_empty() {
        file_size - 1
    } else {
        end_str.parse::<u64>().ok()?
    };

    if start > end || start >= file_size {
        return None;
    }

    let end = end.min(file_size - 1);
    Some((start, end))
}

/// Determine the local IP that can reach a given target IP by
/// connecting a UDP socket (no actual traffic is sent).
pub fn local_ip_for(target: &str) -> Result<std::net::IpAddr> {
    let target_addr: SocketAddr = if target.contains(':') {
        target.parse().context("Invalid target address")?
    } else {
        format!("{target}:80").parse().context("Invalid target address")?
    };
    let socket = UdpSocket::bind("0.0.0.0:0")?;
    socket.connect(target_addr)?;
    let local_addr = socket.local_addr()?;
    Ok(local_addr.ip())
}

/// Build the media URL using the local IP that can reach the device.
pub fn media_url_for_device(
    device: &DlnaDevice,
    server_port: u16,
    serve_path: &str,
) -> Result<String> {
    let device_host = device
        .device_url
        .host()
        .context("Device URL has no host")?;
    let local_ip = local_ip_for(device_host)?;
    let url = format!("http://{}:{}{}", local_ip, server_port, serve_path);
    tracing::info!("Media URL for {}: {}", device.friendly_name, url);
    Ok(url)
}
