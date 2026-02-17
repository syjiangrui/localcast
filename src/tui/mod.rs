pub mod event;
pub mod ui;

use std::io;

use crossterm::event as ct_event;
use crossterm::execute;
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;

use crate::app::{App, AppScreen};
use crate::tui::event::{map_browser_key, map_playback_key, AppAction};
use crate::tui::ui::{render_device_browser, render_playback};

pub type Tui = Terminal<CrosstermBackend<io::Stdout>>;

/// Initialize the terminal for TUI rendering.
pub fn init_terminal() -> anyhow::Result<Tui> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let terminal = Terminal::new(backend)?;
    Ok(terminal)
}

/// Restore the terminal to its original state.
pub fn restore_terminal(terminal: &mut Tui) -> anyhow::Result<()> {
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}

/// Read a raw key event with timeout. Returns None if no event.
pub fn read_key_event(timeout: std::time::Duration) -> anyhow::Result<Option<crossterm::event::KeyEvent>> {
    if ct_event::poll(timeout)? {
        if let ct_event::Event::Key(key) = ct_event::read()? {
            if key.kind != ct_event::KeyEventKind::Press {
                return Ok(None);
            }
            return Ok(Some(key));
        }
    }
    Ok(None)
}

/// Render the current app state to the terminal.
pub fn render(terminal: &mut Tui, app: &App) -> anyhow::Result<()> {
    terminal.draw(|frame| match &app.screen {
        AppScreen::DeviceBrowser => {
            render_device_browser(frame, &app.devices, app.selected_device, app.scanning);
        }
        AppScreen::Playback => {
            render_playback(
                frame,
                &app.file_name,
                &app.current_device_name(),
                &app.playback_state,
                &app.position,
            );
        }
    })?;
    Ok(())
}

/// Map a key event to an action based on the current screen.
pub fn map_key(screen: &AppScreen, key: crossterm::event::KeyEvent) -> AppAction {
    match screen {
        AppScreen::DeviceBrowser => map_browser_key(key),
        AppScreen::Playback => map_playback_key(key),
    }
}
