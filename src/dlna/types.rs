use std::sync::Arc;

use http02::Uri;

/// Represents a discovered DLNA MediaRenderer device.
#[derive(Debug, Clone)]
pub struct DlnaDevice {
    pub friendly_name: String,
    pub service: Arc<rupnp::Service>,
    pub device_url: Uri,
}

/// Playback transport state as reported by the TV.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlaybackState {
    Stopped,
    Playing,
    Paused,
    Transitioning,
    NoMediaPresent,
    Unknown(String),
}

impl PlaybackState {
    pub fn from_transport_state(s: &str) -> Self {
        match s {
            "STOPPED" => Self::Stopped,
            "PLAYING" => Self::Playing,
            "PAUSED_PLAYBACK" => Self::Paused,
            "TRANSITIONING" => Self::Transitioning,
            "NO_MEDIA_PRESENT" => Self::NoMediaPresent,
            other => Self::Unknown(other.to_string()),
        }
    }

    pub fn label(&self) -> &str {
        match self {
            Self::Stopped => "Stopped",
            Self::Playing => "Playing",
            Self::Paused => "Paused",
            Self::Transitioning => "Loading...",
            Self::NoMediaPresent => "No Media",
            Self::Unknown(s) => s.as_str(),
        }
    }
}

/// Position and duration info from GetPositionInfo.
#[derive(Debug, Clone, Default)]
pub struct PositionInfo {
    pub elapsed_secs: u64,
    pub duration_secs: u64,
}

impl PositionInfo {
    pub fn elapsed_display(&self) -> String {
        format_duration(self.elapsed_secs)
    }

    pub fn duration_display(&self) -> String {
        format_duration(self.duration_secs)
    }

    pub fn progress_ratio(&self) -> f64 {
        if self.duration_secs == 0 {
            0.0
        } else {
            self.elapsed_secs as f64 / self.duration_secs as f64
        }
    }
}

/// Format seconds as HH:MM:SS.
pub fn format_duration(total_secs: u64) -> String {
    let h = total_secs / 3600;
    let m = (total_secs % 3600) / 60;
    let s = total_secs % 60;
    format!("{h:02}:{m:02}:{s:02}")
}

/// Parse a DLNA time string "HH:MM:SS" or "H:MM:SS.xxx" into total seconds.
pub fn parse_duration(time_str: &str) -> u64 {
    let time_str = time_str.trim();
    // Strip fractional seconds
    let time_str = time_str.split('.').next().unwrap_or(time_str);
    let parts: Vec<&str> = time_str.split(':').collect();
    if parts.len() != 3 {
        return 0;
    }
    let h: u64 = parts[0].parse().unwrap_or(0);
    let m: u64 = parts[1].parse().unwrap_or(0);
    let s: u64 = parts[2].parse().unwrap_or(0);
    h * 3600 + m * 60 + s
}
