pub mod i18n;
pub mod screens;
pub mod state;
pub mod theme;
pub mod widgets;

use std::time::Duration;

use anyhow::Result;
use eframe::egui;
use tokio::sync::mpsc;

use crate::gui::i18n::I18n;
use crate::gui::screens::{device_list, file_picker, playback};
use crate::gui::state::{async_dispatcher, GuiAction, GuiResult, GuiState, Screen};
use crate::gui::theme::apply_theme;

/// Launch the egui GUI. This is the main entry point when no file argument is given.
pub fn run() -> Result<()> {
    let rt = tokio::runtime::Runtime::new()?;

    let (action_tx, action_rx) = mpsc::channel::<GuiAction>(64);
    let (result_tx, result_rx) = mpsc::channel::<GuiResult>(64);

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([480.0, 640.0])
            .with_min_inner_size([380.0, 500.0]),
        ..Default::default()
    };

    let app = GuiApp {
        state: GuiState::new(),
        action_tx,
        result_rx,
        i18n: I18n::detect(),
        theme_applied: false,
        rt: Some(rt),
        action_rx_taken: Some(action_rx),
        result_tx_taken: Some(result_tx),
        dispatcher_spawned: false,
    };

    eframe::run_native("LocalCast", options, Box::new(|cc| {
        configure_fonts(&cc.egui_ctx);
        Ok(Box::new(app))
    }))
    .map_err(|e| anyhow::anyhow!("eframe error: {e}"))?;

    Ok(())
}

struct GuiApp {
    state: GuiState,
    action_tx: mpsc::Sender<GuiAction>,
    result_rx: mpsc::Receiver<GuiResult>,
    i18n: I18n,
    theme_applied: bool,
    rt: Option<tokio::runtime::Runtime>,
    action_rx_taken: Option<mpsc::Receiver<GuiAction>>,
    result_tx_taken: Option<mpsc::Sender<GuiResult>>,
    dispatcher_spawned: bool,
}

/// Load a system CJK font so Chinese characters render correctly.
fn configure_fonts(ctx: &egui::Context) {
    let mut fonts = egui::FontDefinitions::default();

    // Try to load a system CJK font from known paths (macOS / Windows / Linux)
    let cjk_font_paths: &[&str] = &[
        // macOS
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Supplemental/Songti.ttc",
        // Windows
        "C:\\Windows\\Fonts\\msyh.ttc",   // Microsoft YaHei
        "C:\\Windows\\Fonts\\simsun.ttc",  // SimSun
        // Linux
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/google-noto-cjk/NotoSansCJK-Regular.ttc",
    ];

    for path in cjk_font_paths {
        if let Ok(data) = std::fs::read(path) {
            // Use tweak to adjust baseline alignment for CJK fonts
            let font_data = egui::FontData::from_owned(data)
                .tweak(egui::FontTweak {
                    y_offset_factor: 0.0,
                    y_offset: 0.0,
                    scale: 1.0,
                    baseline_offset_factor: 0.20, // Adjust baseline to align with Latin text
                });

            fonts.font_data.insert(
                "cjk_font".to_owned(),
                font_data.into(),
            );

            // Add as fallback to the default proportional and monospace families
            if let Some(family) = fonts.families.get_mut(&egui::FontFamily::Proportional) {
                family.push("cjk_font".to_owned());
            }
            if let Some(family) = fonts.families.get_mut(&egui::FontFamily::Monospace) {
                family.push("cjk_font".to_owned());
            }

            tracing::info!("Loaded CJK font from: {path}");
            break;
        }
    }

    ctx.set_fonts(fonts);
}

impl eframe::App for GuiApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Spawn the async dispatcher once on the first frame
        if !self.dispatcher_spawned {
            if let (Some(rt), Some(action_rx), Some(result_tx)) = (
                self.rt.as_ref(),
                self.action_rx_taken.take(),
                self.result_tx_taken.take(),
            ) {
                let repaint_ctx = ctx.clone();
                rt.spawn(async_dispatcher(action_rx, result_tx, repaint_ctx));
                self.dispatcher_spawned = true;
            }
        }

        // Apply theme once
        if !self.theme_applied {
            apply_theme(ctx);
            self.theme_applied = true;
        }

        // Drain all pending results
        while let Ok(result) = self.result_rx.try_recv() {
            self.state.apply_result(result);
        }

        // Render current screen
        match self.state.screen {
            Screen::FilePicker => {
                file_picker::render(ctx, &mut self.state, &self.action_tx, &self.i18n);
            }
            Screen::DeviceList => {
                device_list::render(ctx, &mut self.state, &self.action_tx, &self.i18n);
            }
            Screen::Playback => {
                playback::render(ctx, &mut self.state, &self.action_tx, &self.i18n);
                // Request periodic repaint for smooth playback updates
                ctx.request_repaint_after(Duration::from_millis(200));
            }
        }
    }
}
