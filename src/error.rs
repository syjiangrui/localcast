use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("File not found: {0}")]
    FileNotFound(String),

    #[error("Unsupported file type: {0}. Supported: mp4, mkv, avi, webm")]
    UnsupportedFormat(String),

    #[error("No DLNA devices found on the network")]
    NoDevicesFound,

    #[error("DLNA action failed: {0}")]
    DlnaAction(String),

    #[error("HTTP server error: {0}")]
    ServerError(String),

    #[error("Network error: {0}")]
    NetworkError(String),

    #[error("TUI error: {0}")]
    TuiError(String),
}
