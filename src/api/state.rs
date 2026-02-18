use tokio::sync::broadcast;
use tokio::task::JoinHandle;

use crate::api::types::StatusResponse;
use crate::dlna::types::{DlnaDevice, PlaybackState, PositionInfo};

pub struct ApiState {
    // Discovered devices
    pub devices: Vec<DlnaDevice>,
    pub selected_device: Option<usize>,
    pub control_url: Option<String>,

    // File info
    pub file_path: Option<String>,
    pub file_name: Option<String>,
    pub file_size: u64,
    pub mime_type: Option<String>,

    // Media server
    pub media_server_handle: Option<JoinHandle<()>>,
    pub serve_path: Option<String>,
    pub server_port: u16,

    // Playback
    pub playback_state: PlaybackState,
    pub position: PositionInfo,

    // Poller
    pub poller_handle: Option<JoinHandle<()>>,

    // SSE broadcast
    pub status_tx: broadcast::Sender<StatusResponse>,
}

impl ApiState {
    pub fn new() -> Self {
        let (status_tx, _) = broadcast::channel(64);
        Self {
            devices: Vec::new(),
            selected_device: None,
            control_url: None,
            file_path: None,
            file_name: None,
            file_size: 0,
            mime_type: None,
            media_server_handle: None,
            serve_path: None,
            server_port: 0,
            playback_state: PlaybackState::Stopped,
            position: PositionInfo::default(),
            poller_handle: None,
            status_tx,
        }
    }

    pub fn current_device(&self) -> Option<&DlnaDevice> {
        self.selected_device
            .and_then(|i| self.devices.get(i))
    }

    pub fn device_name(&self) -> String {
        self.current_device()
            .map(|d| d.friendly_name.clone())
            .unwrap_or_default()
    }

    pub fn status_response(&self) -> StatusResponse {
        StatusResponse {
            playback_state: self.playback_state.label().to_string(),
            elapsed_secs: self.position.elapsed_secs,
            duration_secs: self.position.duration_secs,
            elapsed_display: self.position.elapsed_display(),
            duration_display: self.position.duration_display(),
            progress: self.position.progress_ratio(),
            file_name: self.file_name.clone().unwrap_or_default(),
            device_name: self.device_name(),
        }
    }
}
