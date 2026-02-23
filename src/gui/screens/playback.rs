use eframe::egui;
use tokio::sync::mpsc;

use crate::dlna::types::PlaybackState;
use crate::gui::i18n::I18n;
use crate::gui::state::{GuiAction, GuiState, Screen};
use crate::gui::theme::ThemeColors;
use crate::gui::widgets::{controls, progress_bar};

const BAR_MAX_WIDTH: f32 = 320.0;

pub fn render(
    ctx: &egui::Context,
    state: &mut GuiState,
    action_tx: &mpsc::Sender<GuiAction>,
    i18n: &I18n,
) {
    egui::CentralPanel::default().show(ctx, |ui| {
        // Top bar
        ui.horizontal(|ui| {
            if ui
                .add(
                    egui::Button::new(
                        egui::RichText::new("\u{2190} Back").size(18.0).color(ThemeColors::TEXT_PRIMARY),
                    )
                    .frame(false),
                )
                .clicked()
            {
                let _ = action_tx.try_send(GuiAction::Stop);
                state.screen = Screen::DeviceList;
                state.auto_discovered = false;
            }

            ui.add_space(8.0);
            ui.label(
                egui::RichText::new(i18n.now_playing())
                    .size(22.0)
                    .color(ThemeColors::TEXT_PRIMARY),
            );
        });

        ui.separator();

        ui.add_space(20.0);

        ui.vertical_centered(|ui| {
            // Cast icon
            ui.label(egui::RichText::new("\u{1F4E1}").size(56.0));

            ui.add_space(12.0);

            // File name
            let file_name = state
                .file_name
                .as_deref()
                .unwrap_or(i18n.no_file());
            ui.label(
                egui::RichText::new(file_name)
                    .size(19.0)
                    .color(ThemeColors::TEXT_PRIMARY),
            );

            ui.add_space(4.0);

            // Device name
            let casting_text = i18n.casting_to(&state.device_name);
            ui.label(
                egui::RichText::new(&casting_text)
                    .size(16.0)
                    .color(ThemeColors::TEXT_SECONDARY),
            );

            ui.add_space(8.0);

            // State chip - wrap in horizontal so it doesn't stretch full width
            render_state_chip(ui, &state.playback_state, i18n);

            ui.add_space(24.0);

            // Progress bar - use full available width with padding
            let bar_width = ui.available_width() - 32.0; // 16px padding on each side
            let new_ratio = progress_bar::render(
                ui,
                state.progress_ratio(),
                state.elapsed_secs,
                state.duration_secs,
                bar_width,
            );
            if let Some(ratio) = new_ratio {
                let target = (ratio * state.duration_secs as f32) as u64;
                let _ = action_tx.try_send(GuiAction::Seek(target));
            }

            ui.add_space(4.0);

            // Time labels - matching bar width
            ui.allocate_ui_with_layout(
                egui::vec2(bar_width, 16.0),
                egui::Layout::left_to_right(egui::Align::Center),
                |ui| {
                    ui.label(
                        egui::RichText::new(state.elapsed_display())
                            .size(15.0)
                            .color(ThemeColors::TEXT_SECONDARY),
                    );
                    ui.with_layout(
                        egui::Layout::right_to_left(egui::Align::Center),
                        |ui| {
                            ui.label(
                                egui::RichText::new(state.duration_display())
                                    .size(15.0)
                                    .color(ThemeColors::TEXT_SECONDARY),
                            );
                        },
                    );
                },
            );

            ui.add_space(24.0);

            // Control buttons - centered
            controls::render(ui, state, action_tx, i18n);

            ui.add_space(16.0);

            // Stop button
            let stop_btn = egui::Button::new(
                egui::RichText::new(i18n.stop())
                    .color(ThemeColors::ERROR)
                    .size(18.0),
            )
            .fill(egui::Color32::TRANSPARENT)
            .stroke(egui::Stroke::new(1.0, ThemeColors::ERROR))
            .corner_radius(egui::CornerRadius::same(8))
            .min_size(egui::vec2(140.0, 44.0));

            if ui.add(stop_btn).clicked() {
                let _ = action_tx.try_send(GuiAction::Stop);
                state.playback_state = PlaybackState::Stopped;
            }

            // Error display
            if let Some(ref err) = state.playback_error.clone() {
                ui.add_space(12.0);
                ui.label(
                    egui::RichText::new(err)
                        .color(ThemeColors::ERROR)
                        .size(16.0),
                );
            }
        });
    });
}

fn render_state_chip(ui: &mut egui::Ui, state: &PlaybackState, i18n: &I18n) {
    let label = state.label();
    let localized = i18n.playback_state_label_zh(label);
    let color = match state {
        PlaybackState::Playing => ThemeColors::SUCCESS,
        PlaybackState::Paused => ThemeColors::WARNING,
        PlaybackState::Stopped => ThemeColors::TEXT_SECONDARY,
        PlaybackState::Transitioning => ThemeColors::PRIMARY_LIGHT,
        PlaybackState::NoMediaPresent => ThemeColors::TEXT_DISABLED,
        PlaybackState::Unknown(_) => ThemeColors::TEXT_DISABLED,
    };

    // Add a centered label, then paint a pill background behind it
    let padding = egui::vec2(14.0, 6.0);
    let response = ui.label(
        egui::RichText::new(&localized)
            .size(15.0)
            .color(color),
    );
    let chip_rect = response.rect.expand2(padding);
    let painter = ui.painter();
    painter.rect_filled(chip_rect, egui::CornerRadius::same(12), color.gamma_multiply(0.2));
    // Re-draw the text on top of the background
    painter.text(
        chip_rect.center(),
        egui::Align2::CENTER_CENTER,
        &localized,
        egui::FontId::proportional(15.0),
        color,
    );
}
