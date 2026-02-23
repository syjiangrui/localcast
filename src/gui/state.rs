use std::path::PathBuf;
use std::time::Duration;

use eframe::egui;
use tokio::sync::mpsc;

use crate::dlna::types::{DlnaDevice, PlaybackState};
use crate::{discovery, server};
use crate::dlna::transport;

/// Which screen is currently displayed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Screen {
    FilePicker,
    DeviceList,
    Playback,
}

/// Actions sent from the GUI thread to the async dispatcher.
#[derive(Debug)]
pub enum GuiAction {
    SelectFile(PathBuf),
    PickFile,
    DiscoverDevices,
    SelectDeviceAndCast(usize),
    Play,
    Pause,
    TogglePlayPause,
    Stop,
    Seek(u64),
    SeekRelative(i64),
}

/// Results sent from the async dispatcher back to the GUI thread.
#[derive(Debug)]
pub enum GuiResult {
    FileSelected {
        name: String,
        size: u64,
        mime: String,
    },
    FileError(String),
    DevicesFound(Vec<DeviceInfo>),
    DeviceError(String),
    CastStarted {
        device_name: String,
    },
    CastError(String),
    PlaybackUpdate {
        state: PlaybackState,
        elapsed: u64,
        duration: u64,
    },
    ActionError(String),
}

/// Simplified device info for the GUI (the real DlnaDevice isn't Send-friendly for display).
#[derive(Debug, Clone)]
pub struct DeviceInfo {
    pub friendly_name: String,
    pub device_url: String,
}

/// GUI state shared within the GUI thread.
pub struct GuiState {
    pub screen: Screen,

    // File picker
    pub file_name: Option<String>,
    pub file_size: Option<u64>,
    pub file_mime: Option<String>,
    pub file_error: Option<String>,

    // Device list
    pub devices: Vec<DeviceInfo>,
    pub scanning: bool,
    pub device_error: Option<String>,
    pub auto_discovered: bool,

    // Playback
    pub device_name: String,
    pub playback_state: PlaybackState,
    pub elapsed_secs: u64,
    pub duration_secs: u64,
    pub playback_error: Option<String>,
    pub cast_loading: bool,

    // Drag-and-drop state
    pub drag_hovering: bool,
}

impl GuiState {
    pub fn new() -> Self {
        Self {
            screen: Screen::FilePicker,
            file_name: None,
            file_size: None,
            file_mime: None,
            file_error: None,
            devices: Vec::new(),
            scanning: false,
            device_error: None,
            auto_discovered: false,
            device_name: String::new(),
            playback_state: PlaybackState::Stopped,
            elapsed_secs: 0,
            duration_secs: 0,
            playback_error: None,
            cast_loading: false,
            drag_hovering: false,
        }
    }

    pub fn apply_result(&mut self, result: GuiResult) {
        match result {
            GuiResult::FileSelected { name, size, mime } => {
                self.file_name = Some(name);
                self.file_size = Some(size);
                self.file_mime = Some(mime);
                self.file_error = None;
                // Auto-navigate to device list screen
                self.screen = Screen::DeviceList;
                self.auto_discovered = false;
            }
            GuiResult::FileError(msg) => {
                self.file_error = Some(msg);
            }
            GuiResult::DevicesFound(devices) => {
                self.devices = devices;
                self.scanning = false;
                self.device_error = None;
            }
            GuiResult::DeviceError(msg) => {
                self.scanning = false;
                self.device_error = Some(msg);
            }
            GuiResult::CastStarted { device_name } => {
                self.device_name = device_name;
                self.playback_state = PlaybackState::Playing;
                self.cast_loading = false;
                self.playback_error = None;
                self.elapsed_secs = 0;
                self.duration_secs = 0;
                self.screen = Screen::Playback;
            }
            GuiResult::CastError(msg) => {
                self.cast_loading = false;
                self.playback_error = Some(msg);
            }
            GuiResult::PlaybackUpdate {
                state,
                elapsed,
                duration,
            } => {
                self.playback_state = state;
                self.elapsed_secs = elapsed;
                self.duration_secs = duration;
            }
            GuiResult::ActionError(msg) => {
                self.playback_error = Some(msg);
            }
        }
    }

    pub fn progress_ratio(&self) -> f32 {
        if self.duration_secs == 0 {
            0.0
        } else {
            (self.elapsed_secs as f32 / self.duration_secs as f32).clamp(0.0, 1.0)
        }
    }

    pub fn elapsed_display(&self) -> String {
        format_time(self.elapsed_secs)
    }

    pub fn duration_display(&self) -> String {
        format_time(self.duration_secs)
    }
}

fn format_time(secs: u64) -> String {
    let h = secs / 3600;
    let m = (secs % 3600) / 60;
    let s = secs % 60;
    format!("{h:02}:{m:02}:{s:02}")
}

pub fn format_file_size(bytes: u64) -> String {
    if bytes < 1024 {
        format!("{} B", bytes)
    } else if bytes < 1024 * 1024 {
        format!("{:.1} KB", bytes as f64 / 1024.0)
    } else if bytes < 1024 * 1024 * 1024 {
        format!("{:.1} MB", bytes as f64 / (1024.0 * 1024.0))
    } else {
        format!("{:.2} GB", bytes as f64 / (1024.0 * 1024.0 * 1024.0))
    }
}

const SUPPORTED_EXTENSIONS: &[&str] = &["mp4", "mkv", "avi", "webm"];

/// The async dispatcher runs on the tokio runtime. It receives GuiActions,
/// performs async operations (discovery, transport, server), and sends GuiResults back.
pub async fn async_dispatcher(
    mut action_rx: mpsc::Receiver<GuiAction>,
    result_tx: mpsc::Sender<GuiResult>,
    ctx: egui::Context,
) {
    // Persistent state across actions
    let mut devices: Vec<DlnaDevice> = Vec::new();
    let mut control_url: Option<String> = None;
    let mut selected_device: Option<DlnaDevice> = None;
    let mut server_port: u16 = 0;
    let mut serve_path: String = String::new();
    let mut file_path: Option<PathBuf> = None;
    let mut file_name: String = String::new();
    let mut mime_type: String = String::new();
    let mut file_size: u64 = 0;
    let mut _server_handle: Option<tokio::task::JoinHandle<()>> = None;
    let mut poller_handle: Option<tokio::task::JoinHandle<()>> = None;

    while let Some(action) = action_rx.recv().await {
        match action {
            GuiAction::SelectFile(path) => {
                let res = handle_select_file(
                    &path,
                    &mut file_path,
                    &mut file_name,
                    &mut mime_type,
                    &mut file_size,
                    &mut server_port,
                    &mut serve_path,
                    &mut _server_handle,
                )
                .await;
                let _ = result_tx.send(res).await;
                ctx.request_repaint();
            }
            GuiAction::PickFile => {
                // File picking happens on the GUI thread via rfd, this is just a fallback
                // The GUI thread handles rfd::FileDialog directly and sends SelectFile
            }
            GuiAction::DiscoverDevices => {
                match discovery::discover_devices(Duration::from_secs(5)).await {
                    Ok(found) => {
                        let infos: Vec<DeviceInfo> = found
                            .iter()
                            .map(|d| DeviceInfo {
                                friendly_name: d.friendly_name.clone(),
                                device_url: d.device_url.to_string(),
                            })
                            .collect();
                        devices = found;
                        let _ = result_tx.send(GuiResult::DevicesFound(infos)).await;
                    }
                    Err(e) => {
                        let _ = result_tx
                            .send(GuiResult::DeviceError(format!("{e}")))
                            .await;
                    }
                }
                ctx.request_repaint();
            }
            GuiAction::SelectDeviceAndCast(index) => {
                if index >= devices.len() {
                    let _ = result_tx
                        .send(GuiResult::CastError("Invalid device index".into()))
                        .await;
                    ctx.request_repaint();
                    continue;
                }

                let device = devices[index].clone();
                let device_name = device.friendly_name.clone();

                // Resolve control URL
                let ctrl = match transport::resolve_control_url(&device).await {
                    Ok(url) => url,
                    Err(e) => {
                        let _ = result_tx
                            .send(GuiResult::CastError(format!(
                                "Failed to resolve control URL: {e}"
                            )))
                            .await;
                        ctx.request_repaint();
                        continue;
                    }
                };

                // Build media URL
                let media_url =
                    match server::media_url_for_device(&device, server_port, &serve_path) {
                        Ok(u) => u,
                        Err(e) => {
                            let _ = result_tx
                                .send(GuiResult::CastError(format!(
                                    "Cannot determine media URL: {e}"
                                )))
                                .await;
                            ctx.request_repaint();
                            continue;
                        }
                    };

                // Set URI and play
                if let Err(e) = transport::set_av_transport_uri(
                    &device,
                    &ctrl,
                    &media_url,
                    &file_name,
                    &mime_type,
                    file_size,
                )
                .await
                {
                    let _ = result_tx
                        .send(GuiResult::CastError(format!(
                            "SetAVTransportURI failed: {e}"
                        )))
                        .await;
                    ctx.request_repaint();
                    continue;
                }

                if let Err(e) = transport::play(&device, &ctrl).await {
                    let _ = result_tx
                        .send(GuiResult::CastError(format!("Play failed: {e}")))
                        .await;
                    ctx.request_repaint();
                    continue;
                }

                control_url = Some(ctrl.clone());
                selected_device = Some(device.clone());

                // Start poller
                if let Some(h) = poller_handle.take() {
                    h.abort();
                }
                let poller_device = device.clone();
                let poller_ctrl = ctrl.clone();
                let poller_tx = result_tx.clone();
                let poller_ctx = ctx.clone();
                poller_handle = Some(tokio::spawn(async move {
                    playback_poller(poller_device, poller_ctrl, poller_tx, poller_ctx).await;
                }));

                let _ = result_tx
                    .send(GuiResult::CastStarted { device_name })
                    .await;
                ctx.request_repaint();
            }
            GuiAction::Play => {
                if let (Some(device), Some(ctrl)) = (&selected_device, &control_url) {
                    if let Err(e) = transport::play(device, ctrl).await {
                        let _ = result_tx
                            .send(GuiResult::ActionError(format!("Play failed: {e}")))
                            .await;
                    }
                }
                ctx.request_repaint();
            }
            GuiAction::Pause => {
                if let (Some(device), Some(ctrl)) = (&selected_device, &control_url) {
                    if let Err(e) = transport::pause(device, ctrl).await {
                        let _ = result_tx
                            .send(GuiResult::ActionError(format!("Pause failed: {e}")))
                            .await;
                    }
                }
                ctx.request_repaint();
            }
            GuiAction::TogglePlayPause => {
                if let (Some(device), Some(ctrl)) = (&selected_device, &control_url) {
                    // We don't track state here; just try pause, if it fails try play
                    // The poller will update the actual state
                    let _ = transport::pause(device, ctrl).await;
                }
                ctx.request_repaint();
            }
            GuiAction::Stop => {
                if let (Some(device), Some(ctrl)) = (&selected_device, &control_url) {
                    let _ = transport::stop(device, ctrl).await;
                }
                if let Some(h) = poller_handle.take() {
                    h.abort();
                }
                ctx.request_repaint();
            }
            GuiAction::Seek(secs) => {
                if let (Some(device), Some(ctrl)) = (&selected_device, &control_url) {
                    if let Err(e) = transport::seek(device, ctrl, secs).await {
                        let _ = result_tx
                            .send(GuiResult::ActionError(format!("Seek failed: {e}")))
                            .await;
                    }
                }
                ctx.request_repaint();
            }
            GuiAction::SeekRelative(delta) => {
                if let (Some(device), Some(ctrl)) = (&selected_device, &control_url) {
                    // Get current position from poller info
                    if let Ok(pos) = transport::get_position_info(device, ctrl).await {
                        let current = pos.elapsed_secs as i64;
                        let target = (current + delta).max(0) as u64;
                        let target = if pos.duration_secs > 0 {
                            target.min(pos.duration_secs)
                        } else {
                            target
                        };
                        let _ = transport::seek(device, ctrl, target).await;
                    }
                }
                ctx.request_repaint();
            }
        }
    }
}

async fn handle_select_file(
    path: &PathBuf,
    file_path: &mut Option<PathBuf>,
    file_name: &mut String,
    mime_type: &mut String,
    file_size_out: &mut u64,
    server_port: &mut u16,
    serve_path: &mut String,
    server_handle: &mut Option<tokio::task::JoinHandle<()>>,
) -> GuiResult {
    let path = match path.canonicalize() {
        Ok(p) => p,
        Err(_) => return GuiResult::FileError("File not found".into()),
    };

    if !path.is_file() {
        return GuiResult::FileError("Not a file".into());
    }

    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_lowercase())
        .unwrap_or_default();

    if !SUPPORTED_EXTENSIONS.contains(&ext.as_str()) {
        return GuiResult::FileError(format!(
            "Unsupported file type: .{}. Supported: {}",
            ext,
            SUPPORTED_EXTENSIONS.join(", ")
        ));
    }

    let name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let size = match std::fs::metadata(&path) {
        Ok(m) => m.len(),
        Err(e) => return GuiResult::FileError(format!("Cannot read file: {e}")),
    };

    let mime = mime_guess::from_path(&path)
        .first_or_octet_stream()
        .to_string();

    // Stop previous server
    if let Some(h) = server_handle.take() {
        h.abort();
    }

    // Start media server
    match server::start_server(path.clone(), 0).await {
        Ok((addr, sp, handle)) => {
            *server_port = addr.port();
            *serve_path = sp;
            *server_handle = Some(handle);
        }
        Err(e) => {
            return GuiResult::FileError(format!("Failed to start media server: {e}"));
        }
    }

    *file_path = Some(path);
    *file_name = name.clone();
    *mime_type = mime.clone();
    *file_size_out = size;

    GuiResult::FileSelected {
        name,
        size,
        mime,
    }
}

async fn playback_poller(
    device: DlnaDevice,
    control_url: String,
    tx: mpsc::Sender<GuiResult>,
    ctx: egui::Context,
) {
    let mut interval = tokio::time::interval(Duration::from_secs(1));
    loop {
        interval.tick().await;

        let mut state = PlaybackState::Unknown("N/A".into());
        let mut elapsed = 0u64;
        let mut duration = 0u64;

        if let Ok(pos) = transport::get_position_info(&device, &control_url).await {
            elapsed = pos.elapsed_secs;
            duration = pos.duration_secs;
        }

        if let Ok(s) = transport::get_transport_info(&device, &control_url).await {
            state = s;
        }

        if tx
            .send(GuiResult::PlaybackUpdate {
                state,
                elapsed,
                duration,
            })
            .await
            .is_err()
        {
            break;
        }
        ctx.request_repaint();
    }
}
