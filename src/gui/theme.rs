use eframe::egui::{self, Color32, CornerRadius, Stroke, Visuals};

/// Indigo-based color palette matching the Flutter Material 3 theme.
pub struct ThemeColors;

impl ThemeColors {
    pub const PRIMARY: Color32 = Color32::from_rgb(99, 102, 241); // Indigo 500
    pub const PRIMARY_LIGHT: Color32 = Color32::from_rgb(129, 140, 248); // Indigo 400
    pub const PRIMARY_DARK: Color32 = Color32::from_rgb(79, 70, 229); // Indigo 600
    pub const ON_PRIMARY: Color32 = Color32::WHITE;

    pub const SURFACE: Color32 = Color32::from_rgb(30, 30, 46); // Dark surface
    pub const SURFACE_VARIANT: Color32 = Color32::from_rgb(45, 45, 65); // Card background
    pub const BACKGROUND: Color32 = Color32::from_rgb(24, 24, 37); // Window background

    pub const TEXT_PRIMARY: Color32 = Color32::from_rgb(230, 230, 250);
    pub const TEXT_SECONDARY: Color32 = Color32::from_rgb(160, 160, 190);
    pub const TEXT_DISABLED: Color32 = Color32::from_rgb(100, 100, 130);

    pub const ERROR: Color32 = Color32::from_rgb(239, 68, 68); // Red 500
    pub const SUCCESS: Color32 = Color32::from_rgb(34, 197, 94); // Green 500
    pub const WARNING: Color32 = Color32::from_rgb(234, 179, 8); // Yellow 500

    pub const BORDER: Color32 = Color32::from_rgb(60, 60, 85);
    pub const BORDER_HOVER: Color32 = Color32::from_rgb(99, 102, 241);
}

pub fn apply_theme(ctx: &egui::Context) {
    let mut visuals = Visuals::dark();

    visuals.override_text_color = Some(ThemeColors::TEXT_PRIMARY);
    visuals.panel_fill = ThemeColors::BACKGROUND;
    visuals.window_fill = ThemeColors::BACKGROUND;
    visuals.extreme_bg_color = ThemeColors::SURFACE;

    // Widget styling
    visuals.widgets.noninteractive.bg_fill = ThemeColors::SURFACE;
    visuals.widgets.noninteractive.fg_stroke = Stroke::new(1.0, ThemeColors::TEXT_SECONDARY);
    visuals.widgets.noninteractive.corner_radius = CornerRadius::same(8);

    visuals.widgets.inactive.bg_fill = ThemeColors::SURFACE_VARIANT;
    visuals.widgets.inactive.fg_stroke = Stroke::new(1.0, ThemeColors::TEXT_PRIMARY);
    visuals.widgets.inactive.corner_radius = CornerRadius::same(8);

    visuals.widgets.hovered.bg_fill = ThemeColors::PRIMARY_DARK;
    visuals.widgets.hovered.fg_stroke = Stroke::new(1.0, ThemeColors::ON_PRIMARY);
    visuals.widgets.hovered.corner_radius = CornerRadius::same(8);

    visuals.widgets.active.bg_fill = ThemeColors::PRIMARY;
    visuals.widgets.active.fg_stroke = Stroke::new(1.0, ThemeColors::ON_PRIMARY);
    visuals.widgets.active.corner_radius = CornerRadius::same(8);

    visuals.selection.bg_fill = ThemeColors::PRIMARY.gamma_multiply(0.3);
    visuals.selection.stroke = Stroke::new(1.0, ThemeColors::PRIMARY);

    ctx.set_visuals(visuals);

    // Set default font sizes - vision-friendly
    let mut style = (*ctx.style()).clone();
    style.text_styles.insert(
        egui::TextStyle::Heading,
        egui::FontId::proportional(28.0),
    );
    style.text_styles.insert(
        egui::TextStyle::Body,
        egui::FontId::proportional(18.0),
    );
    style.text_styles.insert(
        egui::TextStyle::Button,
        egui::FontId::proportional(18.0),
    );
    style.text_styles.insert(
        egui::TextStyle::Small,
        egui::FontId::proportional(15.0),
    );
    style.spacing.item_spacing = egui::vec2(10.0, 8.0);
    style.spacing.button_padding = egui::vec2(20.0, 12.0);
    ctx.set_style(style);
}
