use eframe::egui;
use tokio::sync::mpsc;

use crate::gui::i18n::I18n;
use crate::gui::state::{GuiAction, GuiState, Screen};
use crate::gui::theme::ThemeColors;

pub fn render(
    ctx: &egui::Context,
    state: &mut GuiState,
    action_tx: &mpsc::Sender<GuiAction>,
    i18n: &I18n,
) {
    // Auto-discover on first entry
    if !state.auto_discovered {
        state.auto_discovered = true;
        state.scanning = true;
        let _ = action_tx.try_send(GuiAction::DiscoverDevices);
    }

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
                state.screen = Screen::FilePicker;
            }

            ui.with_layout(egui::Layout::left_to_right(egui::Align::Center), |ui| {
                ui.add_space(8.0);
                ui.label(
                    egui::RichText::new(i18n.select_device_title())
                        .size(22.0)
                        .color(ThemeColors::TEXT_PRIMARY),
                );
            });

            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                let rescan_enabled = !state.scanning;
                let btn = egui::Button::new(
                    egui::RichText::new(if state.scanning {
                        "\u{21BB} ..."
                    } else {
                        "\u{21BB}"
                    })
                    .size(20.0)
                    .color(if rescan_enabled {
                        ThemeColors::PRIMARY_LIGHT
                    } else {
                        ThemeColors::TEXT_DISABLED
                    }),
                )
                .frame(false);

                if ui.add_enabled(rescan_enabled, btn).clicked() {
                    state.scanning = true;
                    state.device_error = None;
                    let _ = action_tx.try_send(GuiAction::DiscoverDevices);
                }
            });
        });

        ui.separator();

        ui.add_space(8.0);

        // Content area
        if state.scanning {
            render_scanning(ui, i18n);
        } else if let Some(ref err) = state.device_error.clone() {
            render_error(ui, err, action_tx, state, i18n);
        } else if state.devices.is_empty() {
            render_empty(ui, action_tx, state, i18n);
        } else {
            render_device_list(ui, state, action_tx);
        }
    });
}

fn render_scanning(ui: &mut egui::Ui, i18n: &I18n) {
    ui.vertical_centered(|ui| {
        ui.add_space(60.0);
        ui.spinner();
        ui.add_space(12.0);
        ui.label(
            egui::RichText::new(i18n.scanning_devices())
                .size(17.0)
                .color(ThemeColors::TEXT_SECONDARY),
        );
    });
}

fn render_error(
    ui: &mut egui::Ui,
    err: &str,
    action_tx: &mpsc::Sender<GuiAction>,
    state: &mut GuiState,
    i18n: &I18n,
) {
    ui.vertical_centered(|ui| {
        ui.add_space(60.0);
        ui.label(
            egui::RichText::new(err)
                .size(17.0)
                .color(ThemeColors::ERROR),
        );
        ui.add_space(16.0);
        let btn = egui::Button::new(
            egui::RichText::new(i18n.retry())
                .color(ThemeColors::ON_PRIMARY)
                .size(18.0),
        )
        .fill(ThemeColors::PRIMARY)
        .corner_radius(egui::CornerRadius::same(8))
        .min_size(egui::vec2(120.0, 44.0));

        if ui.add(btn).clicked() {
            state.scanning = true;
            state.device_error = None;
            let _ = action_tx.try_send(GuiAction::DiscoverDevices);
        }
    });
}

fn render_empty(
    ui: &mut egui::Ui,
    action_tx: &mpsc::Sender<GuiAction>,
    state: &mut GuiState,
    i18n: &I18n,
) {
    ui.vertical_centered(|ui| {
        ui.add_space(60.0);
        ui.label(
            egui::RichText::new(i18n.no_devices_found())
                .size(19.0)
                .color(ThemeColors::TEXT_PRIMARY),
        );
        ui.add_space(4.0);
        ui.label(
            egui::RichText::new(i18n.no_devices_hint())
                .size(16.0)
                .color(ThemeColors::TEXT_SECONDARY),
        );
        ui.add_space(16.0);
        let btn = egui::Button::new(
            egui::RichText::new(i18n.scan_again())
                .color(ThemeColors::ON_PRIMARY)
                .size(18.0),
        )
        .fill(ThemeColors::PRIMARY)
        .corner_radius(egui::CornerRadius::same(8))
        .min_size(egui::vec2(140.0, 44.0));

        if ui.add(btn).clicked() {
            state.scanning = true;
            state.device_error = None;
            let _ = action_tx.try_send(GuiAction::DiscoverDevices);
        }
    });
}

fn render_device_list(
    ui: &mut egui::Ui,
    state: &mut GuiState,
    action_tx: &mpsc::Sender<GuiAction>,
) {
    egui::ScrollArea::vertical().show(ui, |ui| {
        for (i, device) in state.devices.clone().iter().enumerate() {
            let response = ui.add_sized(
                [ui.available_width(), 60.0],
                egui::Button::new(
                    egui::RichText::new(&device.friendly_name)
                        .size(18.0)
                        .color(ThemeColors::TEXT_PRIMARY),
                )
                .fill(ThemeColors::SURFACE_VARIANT)
                .corner_radius(egui::CornerRadius::same(8))
                .stroke(egui::Stroke::new(1.0, ThemeColors::BORDER)),
            );

            if response.clicked() {
                state.cast_loading = true;
                let _ = action_tx.try_send(GuiAction::SelectDeviceAndCast(i));
            }

            ui.add_space(4.0);
        }
    });
}
