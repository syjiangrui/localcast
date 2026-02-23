use eframe::egui;

use crate::gui::theme::ThemeColors;

/// Render a custom seekable progress bar. Returns Some(ratio) if the user clicked to seek.
pub fn render(
    ui: &mut egui::Ui,
    progress: f32,
    _elapsed_secs: u64,
    duration_secs: u64,
    width: f32,
) -> Option<f32> {
    let height = 8.0;
    let desired_size = egui::vec2(width, 24.0); // extra height for click target

    let (rect, response) = ui.allocate_exact_size(desired_size, egui::Sense::click_and_drag());

    let bar_rect = egui::Rect::from_min_size(
        egui::pos2(rect.min.x, rect.center().y - height / 2.0),
        egui::vec2(width, height),
    );

    let painter = ui.painter();
    let rounding = (height / 2.0) as u8;

    // Background track
    painter.rect_filled(
        bar_rect,
        egui::CornerRadius::same(rounding),
        ThemeColors::SURFACE_VARIANT,
    );

    // Filled portion
    let filled_width = (width * progress).max(0.0);
    if filled_width > 0.0 {
        let filled_rect = egui::Rect::from_min_size(
            bar_rect.min,
            egui::vec2(filled_width, height),
        );
        painter.rect_filled(
            filled_rect,
            egui::CornerRadius::same(rounding),
            ThemeColors::PRIMARY,
        );
    }

    // Thumb
    let thumb_x = bar_rect.min.x + filled_width;
    let thumb_center = egui::pos2(thumb_x, bar_rect.center().y);
    if response.hovered() || response.dragged() {
        painter.circle_filled(thumb_center, 6.0, ThemeColors::PRIMARY_LIGHT);
    }

    // Hover time preview
    if response.hovered() {
        if let Some(hover_pos) = response.hover_pos() {
            let ratio = ((hover_pos.x - bar_rect.min.x) / width).clamp(0.0, 1.0);
            let hover_secs = (ratio * duration_secs as f32) as u64;
            let h = hover_secs / 3600;
            let m = (hover_secs % 3600) / 60;
            let s = hover_secs % 60;
            let time_str = format!("{h:02}:{m:02}:{s:02}");

            let text_pos = egui::pos2(hover_pos.x, bar_rect.min.y - 14.0);
            painter.text(
                text_pos,
                egui::Align2::CENTER_BOTTOM,
                &time_str,
                egui::FontId::proportional(11.0),
                ThemeColors::TEXT_SECONDARY,
            );
        }
    }

    // Handle click/drag to seek
    let mut seek_ratio = None;
    if response.clicked() || response.dragged() {
        if let Some(pos) = response.interact_pointer_pos() {
            let ratio = ((pos.x - bar_rect.min.x) / width).clamp(0.0, 1.0);
            seek_ratio = Some(ratio);
        }
    }

    seek_ratio
}
