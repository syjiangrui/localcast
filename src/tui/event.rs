use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

/// Actions the user can trigger from the TUI.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AppAction {
    Quit,
    MoveUp,
    MoveDown,
    Select,
    Rescan,
    TogglePlayPause,
    Stop,
    SeekForward30,
    SeekBackward30,
    SeekForward5Min,
    SeekBackward5Min,
    BackToDevices,
    None,
}

/// Map a key event in device browser screen to an action.
pub fn map_browser_key(key: KeyEvent) -> AppAction {
    match key.code {
        KeyCode::Char('q') => AppAction::Quit,
        KeyCode::Up | KeyCode::Char('k') => AppAction::MoveUp,
        KeyCode::Down | KeyCode::Char('j') => AppAction::MoveDown,
        KeyCode::Enter => AppAction::Select,
        KeyCode::Char('r') => AppAction::Rescan,
        _ => AppAction::None,
    }
}

/// Map a key event in playback screen to an action.
pub fn map_playback_key(key: KeyEvent) -> AppAction {
    let shift = key.modifiers.contains(KeyModifiers::SHIFT);
    match key.code {
        KeyCode::Char('q') => AppAction::Quit,
        KeyCode::Char(' ') => AppAction::TogglePlayPause,
        KeyCode::Char('s') => AppAction::Stop,
        KeyCode::Left if shift => AppAction::SeekBackward5Min,
        KeyCode::Right if shift => AppAction::SeekForward5Min,
        KeyCode::Left => AppAction::SeekBackward30,
        KeyCode::Right => AppAction::SeekForward30,
        KeyCode::Char('b') => AppAction::BackToDevices,
        _ => AppAction::None,
    }
}
