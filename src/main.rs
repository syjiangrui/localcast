mod app;
mod cli;
mod discovery;
mod dlna;
mod error;
mod gui;
mod server;
mod tui;

use std::time::Duration;

use anyhow::{bail, Context, Result};
use clap::Parser;
use tokio::sync::mpsc;

use crate::app::{App, AppScreen, PollerMessage};
use crate::cli::Args;
use crate::dlna::transport;
use crate::dlna::types::PlaybackState;
use crate::tui::event::AppAction;

const SUPPORTED_EXTENSIONS: &[&str] = &["mp4", "mkv", "avi", "webm"];

fn main() -> Result<()> {
    let args = Args::parse();

    // Set up file-based logging in current directory, truncate on each run
    let log_path = std::env::current_dir()
        .unwrap_or_default()
        .join("localcast.log");
    let _ = std::fs::write(&log_path, ""); // truncate
    let log_file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .context("Failed to open log file")?;
    tracing_subscriber::fmt()
        .with_writer(std::sync::Mutex::new(log_file))
        .with_env_filter("localcast=trace")
        .with_ansi(false)
        .init();

    tracing::info!("LocalCast starting");

    match args.file {
        Some(file) => {
            // TUI mode: build a tokio runtime and run the TUI event loop
            let rt = tokio::runtime::Runtime::new()?;
            rt.block_on(run_tui(file, args.port))
        }
        None => {
            // GUI mode
            gui::run()
        }
    }
}

async fn run_tui(file: std::path::PathBuf, port: u16) -> Result<()> {
    // Validate file
    let file_path = file.canonicalize().context("File not found")?;
    if !file_path.is_file() {
        bail!("Not a file: {}", file_path.display());
    }

    let ext = file_path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_lowercase())
        .unwrap_or_default();

    if !SUPPORTED_EXTENSIONS.contains(&ext.as_str()) {
        bail!(
            "Unsupported file type: .{}. Supported: {}",
            ext,
            SUPPORTED_EXTENSIONS.join(", ")
        );
    }

    let file_name = file_path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    let file_size = std::fs::metadata(&file_path)?.len();

    let mime_type = mime_guess::from_path(&file_path)
        .first_or_octet_stream()
        .to_string();

    // Start HTTP media server (bind on all interfaces)
    let (addr, serve_path, _server_handle) = server::start_server(file_path.clone(), port)
        .await
        .context("Failed to start HTTP server")?;

    let server_port = addr.port();

    // Initialize TUI
    let mut terminal = tui::init_terminal().context("Failed to initialize terminal")?;
    let mut app = App::new(file_name, String::new(), mime_type.clone(), file_size);

    // Initial device discovery
    let devices = discovery::discover_devices(Duration::from_secs(5)).await?;
    app.devices = devices;
    app.scanning = false;

    // Channel for playback poller -> TUI
    let (poller_tx, mut poller_rx) = mpsc::channel::<PollerMessage>(32);
    let mut poller_handle: Option<tokio::task::JoinHandle<()>> = None;

    // Main TUI event loop
    let result = run_event_loop(
        &mut terminal,
        &mut app,
        &serve_path,
        server_port,
        &mime_type,
        file_size,
        &poller_tx,
        &mut poller_rx,
        &mut poller_handle,
    )
    .await;

    // Cleanup
    if let Some(handle) = poller_handle.take() {
        handle.abort();
    }
    tui::restore_terminal(&mut terminal)?;

    if let Err(e) = result {
        eprintln!("Error: {e:#}");
        std::process::exit(1);
    }

    Ok(())
}

async fn run_event_loop(
    terminal: &mut tui::Tui,
    app: &mut App,
    serve_path: &str,
    server_port: u16,
    mime_type: &str,
    file_size: u64,
    poller_tx: &mpsc::Sender<PollerMessage>,
    poller_rx: &mut mpsc::Receiver<PollerMessage>,
    poller_handle: &mut Option<tokio::task::JoinHandle<()>>,
) -> Result<()> {
    loop {
        // Render current state
        tui::render(terminal, app)?;

        // Drain poller messages (non-blocking)
        while let Ok(msg) = poller_rx.try_recv() {
            app.apply_poller_message(msg);
        }

        // Poll for key events (100ms timeout)
        let maybe_key = tui::read_key_event(Duration::from_millis(100))?;
        let action = match maybe_key {
            Some(key) => tui::map_key(&app.screen, key),
            None => continue,
        };

        match (&app.screen, &action) {
            // --- Device Browser actions ---
            (AppScreen::DeviceBrowser, AppAction::Quit) => {
                app.should_quit = true;
                break;
            }
            (AppScreen::DeviceBrowser, AppAction::MoveUp) => app.select_prev(),
            (AppScreen::DeviceBrowser, AppAction::MoveDown) => app.select_next(),
            (AppScreen::DeviceBrowser, AppAction::Rescan) => {
                app.scanning = true;
                tui::render(terminal, app)?;
                let devices = discovery::discover_devices(Duration::from_secs(5)).await?;
                app.devices = devices;
                app.selected_device = 0;
                app.scanning = false;
            }
            (AppScreen::DeviceBrowser, AppAction::Select) => {
                if let Some(device) = app.current_device().cloned() {
                    let control_url = transport::resolve_control_url(&device).await?;
                    let media_url =
                        server::media_url_for_device(&device, server_port, serve_path)?;

                    transport::set_av_transport_uri(
                        &device,
                        &control_url,
                        &media_url,
                        &app.file_name,
                        mime_type,
                        file_size,
                    )
                    .await?;
                    transport::play(&device, &control_url).await?;
                    app.media_url = media_url;
                    app.control_url = control_url.clone();
                    app.playback_state = PlaybackState::Playing;
                    app.screen = AppScreen::Playback;

                    let poller_device = device.clone();
                    let poller_control_url = control_url;
                    let tx = poller_tx.clone();
                    let handle = tokio::spawn(async move {
                        playback_poller(poller_device, poller_control_url, tx).await;
                    });
                    *poller_handle = Some(handle);
                }
            }

            // --- Playback actions ---
            (AppScreen::Playback, AppAction::Quit) => {
                if let Some(device) = app.current_device() {
                    let _ = transport::stop(device, &app.control_url).await;
                }
                app.should_quit = true;
                break;
            }
            (AppScreen::Playback, AppAction::TogglePlayPause) => {
                if let Some(device) = app.current_device() {
                    match app.playback_state {
                        PlaybackState::Playing => {
                            transport::pause(device, &app.control_url).await?;
                            app.playback_state = PlaybackState::Paused;
                        }
                        PlaybackState::Paused | PlaybackState::Stopped => {
                            transport::play(device, &app.control_url).await?;
                            app.playback_state = PlaybackState::Playing;
                        }
                        _ => {}
                    }
                }
            }
            (AppScreen::Playback, AppAction::Stop) => {
                if let Some(device) = app.current_device() {
                    transport::stop(device, &app.control_url).await?;
                    app.playback_state = PlaybackState::Stopped;
                }
            }
            (AppScreen::Playback, AppAction::SeekForward30) => {
                seek_relative(app, 30).await?;
            }
            (AppScreen::Playback, AppAction::SeekBackward30) => {
                seek_relative(app, -30).await?;
            }
            (AppScreen::Playback, AppAction::SeekForward5Min) => {
                seek_relative(app, 300).await?;
            }
            (AppScreen::Playback, AppAction::SeekBackward5Min) => {
                seek_relative(app, -300).await?;
            }
            (AppScreen::Playback, AppAction::BackToDevices) => {
                if let Some(device) = app.current_device() {
                    let _ = transport::stop(device, &app.control_url).await;
                }
                if let Some(handle) = poller_handle.take() {
                    handle.abort();
                }
                app.playback_state = PlaybackState::Stopped;
                app.position = Default::default();
                app.screen = AppScreen::DeviceBrowser;
            }

            _ => {}
        }
    }
    Ok(())
}

async fn seek_relative(app: &mut App, delta_secs: i64) -> Result<()> {
    if let Some(device) = app.current_device() {
        let current = app.position.elapsed_secs as i64;
        let target = (current + delta_secs).max(0) as u64;
        let target = if app.position.duration_secs > 0 {
            target.min(app.position.duration_secs)
        } else {
            target
        };
        transport::seek(device, &app.control_url, target).await?;
    }
    Ok(())
}

/// Background task that polls the device for position and transport state.
async fn playback_poller(device: dlna::types::DlnaDevice, control_url: String, tx: mpsc::Sender<PollerMessage>) {
    let mut interval = tokio::time::interval(Duration::from_secs(1));
    loop {
        interval.tick().await;

        match transport::get_position_info(&device, &control_url).await {
            Ok(pos) => {
                if tx.send(PollerMessage::PositionUpdate(pos)).await.is_err() {
                    break;
                }
            }
            Err(e) => tracing::warn!("Poller GetPositionInfo error: {e}"),
        }

        match transport::get_transport_info(&device, &control_url).await {
            Ok(state) => {
                if tx.send(PollerMessage::StateUpdate(state)).await.is_err() {
                    break;
                }
            }
            Err(e) => tracing::warn!("Poller GetTransportInfo error: {e}"),
        }
    }
}
