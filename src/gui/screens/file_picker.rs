use eframe::egui;
use tokio::sync::mpsc;

use crate::gui::i18n::I18n;
use crate::gui::state::{format_file_size, GuiAction, GuiState, Screen};
use crate::gui::theme::ThemeColors;

pub fn render(
    ctx: &egui::Context,
    state: &mut GuiState,
    action_tx: &mpsc::Sender<GuiAction>,
    i18n: &I18n,
) {
    // Handle drag and drop
    handle_drag_and_drop(ctx, state, action_tx);

    egui::CentralPanel::default().show(ctx, |ui| {
        ui.vertical_centered(|ui| {
            ui.add_space(40.0);

            // Video icon
            ui.label(
                egui::RichText::new("\u{1F3AC}")
                    .size(64.0),
            );

            ui.add_space(16.0);

            // Title
            ui.label(
                egui::RichText::new(i18n.select_video_title())
                    .size(24.0)
                    .color(ThemeColors::TEXT_PRIMARY),
            );

            ui.add_space(4.0);

            // Subtitle
            ui.label(
                egui::RichText::new(i18n.supported_formats())
                    .size(16.0)
                    .color(ThemeColors::TEXT_SECONDARY),
            );

            ui.add_space(24.0);

            // Drop zone
            render_drop_zone(ui, state, action_tx, i18n);

            ui.add_space(16.0);

            // File card (when file is selected)
            if let Some(ref name) = state.file_name.clone() {
                render_file_card(ui, state, name);
                ui.add_space(16.0);
            }

            // Error display
            if let Some(ref err) = state.file_error.clone() {
                ui.label(
                    egui::RichText::new(err)
                        .color(ThemeColors::ERROR)
                        .size(16.0),
                );
                ui.add_space(8.0);
            }

            // Choose Device button (only when file is selected)
            if state.file_name.is_some() {
                let btn = egui::Button::new(
                    egui::RichText::new(i18n.choose_device())
                        .color(ThemeColors::ON_PRIMARY)
                        .size(18.0),
                )
                .fill(ThemeColors::PRIMARY)
                .corner_radius(egui::CornerRadius::same(8))
                .min_size(egui::vec2(220.0, 48.0));

                if ui.add(btn).clicked() {
                    state.screen = Screen::DeviceList;
                    state.auto_discovered = false;
                }
            }
        });
    });

    // Draw drag overlay
    if state.drag_hovering {
        let painter = ctx.layer_painter(egui::LayerId::new(
            egui::Order::Foreground,
            egui::Id::new("drag_overlay"),
        ));
        let screen_rect = ctx.screen_rect();
        painter.rect_filled(
            screen_rect,
            egui::CornerRadius::ZERO,
            ThemeColors::PRIMARY.gamma_multiply(0.15),
        );
        painter.rect_stroke(
            screen_rect,
            egui::CornerRadius::ZERO,
            egui::Stroke::new(3.0, ThemeColors::PRIMARY),
            egui::StrokeKind::Outside,
        );
        painter.text(
            screen_rect.center(),
            egui::Align2::CENTER_CENTER,
            i18n.drop_video_here(),
            egui::FontId::proportional(24.0),
            ThemeColors::PRIMARY_LIGHT,
        );
    }
}

fn render_drop_zone(
    ui: &mut egui::Ui,
    state: &mut GuiState,
    action_tx: &mpsc::Sender<GuiAction>,
    i18n: &I18n,
) {
    let available_width = ui.available_width() - 32.0; // 16px padding on each side

    egui::Frame::NONE
        .fill(ThemeColors::SURFACE_VARIANT)
        .corner_radius(egui::CornerRadius::same(12))
        .stroke(egui::Stroke::new(
            1.5,
            if state.drag_hovering {
                ThemeColors::PRIMARY
            } else {
                ThemeColors::BORDER
            },
        ))
        .inner_margin(egui::Margin::same(24))
        .show(ui, |ui| {
            ui.set_width(available_width - 48.0);
            ui.vertical_centered(|ui| {
                ui.label(
                    egui::RichText::new(i18n.drag_and_drop_hint())
                        .size(16.0)
                        .color(ThemeColors::TEXT_SECONDARY),
                );
                ui.add_space(12.0);

                let btn = egui::Button::new(
                    egui::RichText::new(i18n.select_video_file())
                        .color(ThemeColors::ON_PRIMARY)
                        .size(18.0),
                )
                .fill(ThemeColors::PRIMARY)
                .corner_radius(egui::CornerRadius::same(8))
                .min_size(egui::vec2(200.0, 44.0));

                if ui.add(btn).clicked() {
                    // Open native file dialog
                    if let Some(path) = rfd::FileDialog::new()
                        .add_filter("Video files", &["mp4", "mkv", "avi", "webm"])
                        .pick_file()
                    {
                        let _ = action_tx.try_send(GuiAction::SelectFile(path));
                    }
                }
            });
        });
}

fn render_file_card(ui: &mut egui::Ui, state: &mut GuiState, name: &str) {
    let available_width = ui.available_width() - 32.0; // 16px padding on each side
    let size_text = state
        .file_size
        .map(|s| format_file_size(s))
        .unwrap_or_default();

    egui::Frame::NONE
        .fill(ThemeColors::SURFACE_VARIANT)
        .corner_radius(egui::CornerRadius::same(8))
        .stroke(egui::Stroke::new(1.0, ThemeColors::BORDER))
        .inner_margin(egui::Margin::same(12))
        .show(ui, |ui| {
            ui.set_width(available_width - 24.0);
            ui.horizontal(|ui| {
                ui.vertical(|ui| {
                    ui.set_max_width(available_width - 60.0); // Reserve space for close button
                    ui.label(
                        egui::RichText::new(name)
                            .size(17.0)
                            .color(ThemeColors::TEXT_PRIMARY),
                    );
                    if !size_text.is_empty() {
                        ui.label(
                            egui::RichText::new(&size_text)
                                .size(15.0)
                                .color(ThemeColors::TEXT_SECONDARY),
                        );
                    }
                });
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let close_btn = ui.add(
                        egui::Button::new(
                            egui::RichText::new("×").size(18.0).color(ThemeColors::TEXT_SECONDARY),
                        )
                        .frame(false),
                    );
                    if close_btn.clicked() {
                        state.file_name = None;
                        state.file_size = None;
                        state.file_mime = None;
                    }
                });
            });
        });
}

fn handle_drag_and_drop(
    ctx: &egui::Context,
    state: &mut GuiState,
    action_tx: &mpsc::Sender<GuiAction>,
) {
    // Check for hovering files
    let has_hover = ctx.input(|i| !i.raw.hovered_files.is_empty());
    state.drag_hovering = has_hover;

    // Check for dropped files
    let dropped: Vec<_> = ctx.input(|i| {
        i.raw
            .dropped_files
            .iter()
            .filter_map(|f| f.path.clone())
            .collect()
    });

    if let Some(path) = dropped.into_iter().next() {
        state.drag_hovering = false;
        let _ = action_tx.try_send(GuiAction::SelectFile(path));
    }
}
