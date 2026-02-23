use clap::Parser;
use std::path::PathBuf;

/// Cast local video files to DLNA-compatible TVs
#[derive(Parser, Debug)]
#[command(name = "localcast", version, about)]
pub struct Args {
    /// Path to the video file to cast (launches TUI mode)
    pub file: Option<PathBuf>,

    /// Port for the HTTP media server (0 = auto-assign)
    #[arg(short, long, default_value_t = 0)]
    pub port: u16,
}
