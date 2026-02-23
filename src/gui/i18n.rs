/// Localization support with English and Chinese.
pub struct I18n {
    is_zh: bool,
}

impl I18n {
    pub fn detect() -> Self {
        let locale = sys_locale::get_locale().unwrap_or_else(|| "en".to_string());
        let is_zh = locale.starts_with("zh");
        Self { is_zh }
    }

    // App
    pub fn app_title(&self) -> &str {
        "LocalCast"
    }

    // File Picker Screen
    pub fn select_video_title(&self) -> &str {
        if self.is_zh {
            "选择要投屏的视频文件"
        } else {
            "Select a video file to cast"
        }
    }

    pub fn supported_formats(&self) -> &str {
        if self.is_zh {
            "支持格式：MP4、MKV、AVI、WebM"
        } else {
            "Supported formats: MP4, MKV, AVI, WebM"
        }
    }

    pub fn drag_and_drop_hint(&self) -> &str {
        if self.is_zh {
            "拖放视频文件到此处，或"
        } else {
            "Drag & drop a video file here, or"
        }
    }

    pub fn select_video_file(&self) -> &str {
        if self.is_zh {
            "选择视频文件"
        } else {
            "Select Video File"
        }
    }

    pub fn choose_device(&self) -> &str {
        if self.is_zh {
            "选择设备"
        } else {
            "Choose Device"
        }
    }

    pub fn drop_video_here(&self) -> &str {
        if self.is_zh {
            "将视频文件拖放到此处"
        } else {
            "Drop video file here"
        }
    }

    // Device List Screen
    pub fn select_device_title(&self) -> &str {
        if self.is_zh {
            "选择设备"
        } else {
            "Select Device"
        }
    }

    pub fn rescan(&self) -> &str {
        if self.is_zh {
            "重新扫描"
        } else {
            "Rescan"
        }
    }

    pub fn scanning_devices(&self) -> &str {
        if self.is_zh {
            "正在扫描 DLNA 设备..."
        } else {
            "Scanning for DLNA devices..."
        }
    }

    pub fn retry(&self) -> &str {
        if self.is_zh {
            "重试"
        } else {
            "Retry"
        }
    }

    pub fn no_devices_found(&self) -> &str {
        if self.is_zh {
            "未找到 DLNA 设备"
        } else {
            "No DLNA devices found"
        }
    }

    pub fn no_devices_hint(&self) -> &str {
        if self.is_zh {
            "请确保电视已开启并连接到同一网络"
        } else {
            "Make sure your TV is on and connected to the same network"
        }
    }

    pub fn scan_again(&self) -> &str {
        if self.is_zh {
            "重新扫描"
        } else {
            "Scan Again"
        }
    }

    // Playback Screen
    pub fn now_playing(&self) -> &str {
        if self.is_zh {
            "正在播放"
        } else {
            "Now Playing"
        }
    }

    pub fn no_file(&self) -> &str {
        if self.is_zh {
            "无文件"
        } else {
            "No file"
        }
    }

    pub fn casting_to(&self, device: &str) -> String {
        if self.is_zh {
            format!("投屏到 {device}")
        } else {
            format!("Casting to {device}")
        }
    }

    pub fn playback_state_label<'a>(&self, state: &'a str) -> &'a str {
        if !self.is_zh {
            return state;
        }
        // For Chinese we return static string references, but they don't
        // come from `state`, so we need to use a different approach.
        // We'll just return the English label for non-matching states.
        state
    }

    pub fn playback_state_label_zh(&self, state: &str) -> String {
        if !self.is_zh {
            return state.to_string();
        }
        match state {
            "Playing" => "播放中".to_string(),
            "Paused" => "已暂停".to_string(),
            "Stopped" => "已停止".to_string(),
            "Loading..." => "加载中...".to_string(),
            "No Media" => "无媒体".to_string(),
            _ => state.to_string(),
        }
    }

    pub fn seek_backward_5min(&self) -> &str {
        if self.is_zh {
            "-5分钟"
        } else {
            "-5 min"
        }
    }

    pub fn seek_backward_30s(&self) -> &str {
        if self.is_zh {
            "-30秒"
        } else {
            "-30s"
        }
    }

    pub fn seek_forward_30s(&self) -> &str {
        if self.is_zh {
            "+30秒"
        } else {
            "+30s"
        }
    }

    pub fn seek_forward_5min(&self) -> &str {
        if self.is_zh {
            "+5分钟"
        } else {
            "+5 min"
        }
    }

    pub fn stop(&self) -> &str {
        if self.is_zh {
            "停止"
        } else {
            "Stop"
        }
    }
}
