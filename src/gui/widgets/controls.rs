use eframe::egui;
use tokio::sync::mpsc;

use crate::dlna::types::PlaybackState;
use crate::gui::i18n::I18n;
use crate::gui::state::{GuiAction, GuiState};
use crate::gui::theme::ThemeColors;

pub fn render(
    ui: &mut egui::Ui,
    state: &GuiState,
    action_tx: &mpsc::Sender<GuiAction>,
    i18n: &I18n,
) {
    let item_spacing = 8.0;
    let button_padding = ui.spacing().button_padding.x;
    let text_width = |text: &str, font_size: f32| {
        ui.fonts(|fonts| {
            fonts
                .layout_no_wrap(
                    text.to_owned(),
                    egui::FontId::proportional(font_size),
                    ThemeColors::TEXT_PRIMARY,
                )
                .size()
                .x
        })
    };
    let button_width = |text: &str, font_size: f32, min_width: f32| {
        (text_width(text, font_size) + button_padding * 2.0).max(min_width)
    };
    let play_pause_width = button_width("\u{25B6}", 24.0, 52.0)
        .max(button_width("\u{23F8}", 24.0, 52.0));
    let row_width = button_width(i18n.seek_backward_5min(), 15.0, 56.0)
        + button_width(i18n.seek_backward_30s(), 15.0, 48.0)
        + play_pause_width
        + button_width(i18n.seek_forward_30s(), 15.0, 48.0)
        + button_width(i18n.seek_forward_5min(), 15.0, 56.0)
        + item_spacing * 4.0;
    let row_width = row_width.min(ui.available_width());

    ui.allocate_ui_with_layout(
        egui::vec2(row_width, 0.0),
        egui::Layout::left_to_right(egui::Align::Center),
        |ui| {
            ui.spacing_mut().item_spacing.x = item_spacing;

            // -5 min
            let btn = egui::Button::new(
                egui::RichText::new(i18n.seek_backward_5min())
                    .size(15.0)
                    .color(ThemeColors::TEXT_PRIMARY),
            )
            .fill(ThemeColors::SURFACE_VARIANT)
            .corner_radius(egui::CornerRadius::same(6))
            .min_size(egui::vec2(56.0, 52.0));
            if ui.add(btn).clicked() {
                let _ = action_tx.try_send(GuiAction::SeekRelative(-300));
            }

            // -30s
            let btn = egui::Button::new(
                egui::RichText::new(i18n.seek_backward_30s())
                    .size(15.0)
                    .color(ThemeColors::TEXT_PRIMARY),
            )
            .fill(ThemeColors::SURFACE_VARIANT)
            .corner_radius(egui::CornerRadius::same(6))
            .min_size(egui::vec2(48.0, 52.0));
            if ui.add(btn).clicked() {
                let _ = action_tx.try_send(GuiAction::SeekRelative(-30));
            }

            // Play/Pause (large)
            let is_playing = state.playback_state == PlaybackState::Playing;
            let icon = if is_playing { "\u{23F8}" } else { "\u{25B6}" };
            let play_btn = egui::Button::new(
                egui::RichText::new(icon)
                    .size(24.0)
                    .color(ThemeColors::ON_PRIMARY),
            )
            .fill(ThemeColors::PRIMARY)
            .corner_radius(egui::CornerRadius::same(26))
            .min_size(egui::vec2(52.0, 52.0));
            if ui.add(play_btn).clicked() {
                if is_playing {
                    let _ = action_tx.try_send(GuiAction::Pause);
                } else {
                    let _ = action_tx.try_send(GuiAction::Play);
                }
            }

            // +30s
            let btn = egui::Button::new(
                egui::RichText::new(i18n.seek_forward_30s())
                    .size(15.0)
                    .color(ThemeColors::TEXT_PRIMARY),
            )
            .fill(ThemeColors::SURFACE_VARIANT)
            .corner_radius(egui::CornerRadius::same(6))
            .min_size(egui::vec2(48.0, 52.0));
            if ui.add(btn).clicked() {
                let _ = action_tx.try_send(GuiAction::SeekRelative(30));
            }

            // +5 min
            let btn = egui::Button::new(
                egui::RichText::new(i18n.seek_forward_5min())
                    .size(15.0)
                    .color(ThemeColors::TEXT_PRIMARY),
            )
            .fill(ThemeColors::SURFACE_VARIANT)
            .corner_radius(egui::CornerRadius::same(6))
            .min_size(egui::vec2(56.0, 52.0));
            if ui.add(btn).clicked() {
                let _ = action_tx.try_send(GuiAction::SeekRelative(300));
            }
        },
    );
}
