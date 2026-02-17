use crate::dlna::types::{DlnaDevice, PlaybackState, PositionInfo};

/// Which screen the TUI is displaying.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AppScreen {
    DeviceBrowser,
    Playback,
}

/// Message sent from the playback poller task to the TUI.
#[derive(Debug, Clone)]
pub enum PollerMessage {
    PositionUpdate(PositionInfo),
    StateUpdate(PlaybackState),
}

/// Application state shared across the TUI.
pub struct App {
    pub screen: AppScreen,
    pub devices: Vec<DlnaDevice>,
    pub selected_device: usize,
    pub scanning: bool,

    pub file_name: String,
    pub media_url: String,
    pub control_url: String,
    pub mime_type: String,
    pub file_size: u64,

    pub playback_state: PlaybackState,
    pub position: PositionInfo,

    pub should_quit: bool,
}

impl App {
    pub fn new(file_name: String, media_url: String, mime_type: String, file_size: u64) -> Self {
        Self {
            screen: AppScreen::DeviceBrowser,
            devices: Vec::new(),
            selected_device: 0,
            scanning: true,

            file_name,
            media_url,
            control_url: String::new(),
            mime_type,
            file_size,

            playback_state: PlaybackState::Stopped,
            position: PositionInfo::default(),

            should_quit: false,
        }
    }

    pub fn current_device(&self) -> Option<&DlnaDevice> {
        self.devices.get(self.selected_device)
    }

    pub fn current_device_name(&self) -> String {
        self.current_device()
            .map(|d| d.friendly_name.clone())
            .unwrap_or_else(|| "Unknown".into())
    }

    pub fn select_next(&mut self) {
        if !self.devices.is_empty() {
            self.selected_device = (self.selected_device + 1) % self.devices.len();
        }
    }

    pub fn select_prev(&mut self) {
        if !self.devices.is_empty() {
            if self.selected_device == 0 {
                self.selected_device = self.devices.len() - 1;
            } else {
                self.selected_device -= 1;
            }
        }
    }

    pub fn apply_poller_message(&mut self, msg: PollerMessage) {
        match msg {
            PollerMessage::PositionUpdate(pos) => self.position = pos,
            PollerMessage::StateUpdate(state) => self.playback_state = state,
        }
    }
}
