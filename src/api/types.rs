use serde::{Deserialize, Serialize};

// --- Requests ---

#[derive(Debug, Deserialize)]
pub struct SelectFileRequest {
    pub file_path: String,
}

#[derive(Debug, Deserialize)]
pub struct SelectDeviceRequest {
    pub device_index: usize,
}

#[derive(Debug, Deserialize)]
pub struct SeekRequest {
    pub position_secs: u64,
}

// --- Responses ---

#[derive(Debug, Serialize)]
pub struct FileInfoResponse {
    pub file_name: String,
    pub file_size: u64,
    pub mime_type: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct DeviceResponse {
    pub index: usize,
    pub friendly_name: String,
    pub device_url: String,
}

#[derive(Debug, Serialize)]
pub struct DeviceListResponse {
    pub devices: Vec<DeviceResponse>,
}

#[derive(Debug, Serialize, Clone)]
pub struct StatusResponse {
    pub playback_state: String,
    pub elapsed_secs: u64,
    pub duration_secs: u64,
    pub elapsed_display: String,
    pub duration_display: String,
    pub progress: f64,
    pub file_name: String,
    pub device_name: String,
}

#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
}

#[derive(Debug, Serialize)]
pub struct OkResponse {
    pub ok: bool,
}

impl OkResponse {
    pub fn new() -> Self {
        Self { ok: true }
    }
}
