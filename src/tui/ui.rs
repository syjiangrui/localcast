use ratatui::layout::{Constraint, Direction, Layout};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Gauge, List, ListItem, ListState, Paragraph};
use ratatui::Frame;

use crate::dlna::types::{DlnaDevice, PlaybackState, PositionInfo};

/// Render the device browser screen.
pub fn render_device_browser(
    frame: &mut Frame,
    devices: &[DlnaDevice],
    selected: usize,
    scanning: bool,
) {
    let area = frame.area();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(3)])
        .split(area);

    // Device list
    let items: Vec<ListItem> = devices
        .iter()
        .enumerate()
        .map(|(i, d)| {
            let style = if i == selected {
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };
            ListItem::new(Line::from(Span::styled(&d.friendly_name, style)))
        })
        .collect();

    let title = if scanning {
        " Scanning for DLNA devices... "
    } else if devices.is_empty() {
        " No devices found (r to rescan) "
    } else {
        " Select a device "
    };

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .title(title)
            .border_style(Style::default().fg(Color::Cyan)),
    );

    let mut state = ListState::default();
    if !devices.is_empty() {
        state.select(Some(selected));
    }
    frame.render_stateful_widget(list, chunks[0], &mut state);

    // Help bar
    let help = Paragraph::new(Line::from(vec![
        Span::styled(" ↑/k", Style::default().fg(Color::Green)),
        Span::raw(" Up  "),
        Span::styled("↓/j", Style::default().fg(Color::Green)),
        Span::raw(" Down  "),
        Span::styled("Enter", Style::default().fg(Color::Green)),
        Span::raw(" Select  "),
        Span::styled("r", Style::default().fg(Color::Green)),
        Span::raw(" Rescan  "),
        Span::styled("q", Style::default().fg(Color::Green)),
        Span::raw(" Quit"),
    ]))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::DarkGray)),
    );
    frame.render_widget(help, chunks[1]);
}

/// Render the playback control screen.
pub fn render_playback(
    frame: &mut Frame,
    file_name: &str,
    device_name: &str,
    state: &PlaybackState,
    position: &PositionInfo,
) {
    let area = frame.area();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Info
            Constraint::Length(3), // Progress bar
            Constraint::Length(3), // Time display
            Constraint::Min(0),   // Spacer
            Constraint::Length(3), // Help
        ])
        .split(area);

    // Info line
    let state_color = match state {
        PlaybackState::Playing => Color::Green,
        PlaybackState::Paused => Color::Yellow,
        PlaybackState::Stopped => Color::Red,
        _ => Color::Gray,
    };

    let info = Paragraph::new(Line::from(vec![
        Span::styled(" File: ", Style::default().fg(Color::Gray)),
        Span::styled(file_name, Style::default().fg(Color::White)),
        Span::raw("  │  "),
        Span::styled("Device: ", Style::default().fg(Color::Gray)),
        Span::styled(device_name, Style::default().fg(Color::White)),
        Span::raw("  │  "),
        Span::styled(
            state.label(),
            Style::default()
                .fg(state_color)
                .add_modifier(Modifier::BOLD),
        ),
    ]))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Now Casting ")
            .border_style(Style::default().fg(Color::Cyan)),
    );
    frame.render_widget(info, chunks[0]);

    // Progress bar
    let ratio = position.progress_ratio();
    let gauge = Gauge::default()
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::DarkGray)),
        )
        .gauge_style(Style::default().fg(Color::Cyan).bg(Color::DarkGray))
        .ratio(ratio.clamp(0.0, 1.0));
    frame.render_widget(gauge, chunks[1]);

    // Time display
    let time_text = format!(
        "  {} / {}",
        position.elapsed_display(),
        position.duration_display()
    );
    let time = Paragraph::new(Line::from(Span::styled(
        time_text,
        Style::default().fg(Color::White),
    )));
    frame.render_widget(time, chunks[2]);

    // Help bar
    let help = Paragraph::new(Line::from(vec![
        Span::styled(" Space", Style::default().fg(Color::Green)),
        Span::raw(" Play/Pause  "),
        Span::styled("s", Style::default().fg(Color::Green)),
        Span::raw(" Stop  "),
        Span::styled("←/→", Style::default().fg(Color::Green)),
        Span::raw(" ±30s  "),
        Span::styled("Shift+←/→", Style::default().fg(Color::Green)),
        Span::raw(" ±5min  "),
        Span::styled("b", Style::default().fg(Color::Green)),
        Span::raw(" Back  "),
        Span::styled("q", Style::default().fg(Color::Green)),
        Span::raw(" Quit"),
    ]))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::DarkGray)),
    );
    frame.render_widget(help, chunks[4]);
}
