import 'package:flutter/widgets.dart';

class S {
  final Locale locale;

  S(this.locale);

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S) ?? S(const Locale('en'));
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
  ];

  bool get _isZh => locale.languageCode == 'zh';

  // ---- App ----
  String get appTitle => 'LocalCast';

  // ---- File Picker Screen ----
  String get selectVideoTitle =>
      _isZh ? '选择要投屏的视频文件' : 'Select a video file to cast';
  String get dropVideoHere => _isZh ? '将视频文件拖放到此处' : 'Drop video file here';
  String get supportedFormats =>
      _isZh ? '支持格式：MP4、MKV、AVI、WebM' : 'Supported formats: MP4, MKV, AVI, WebM';
  String get dragAndDropHint =>
      _isZh ? '拖放视频文件到此处，或' : 'Drag & drop a video file here, or';
  String get selectVideoFile => _isZh ? '选择视频文件' : 'Select Video File';
  String get chooseDevice => _isZh ? '选择设备' : 'Choose Device';
  String unsupportedFileType(String ext, String supported) => _isZh
      ? '不支持的文件格式：.$ext。支持：$supported'
      : 'Unsupported file type: .$ext. Supported: $supported';

  // ---- Device List Screen ----
  String get selectDeviceTitle => _isZh ? '选择设备' : 'Select Device';
  String get rescan => _isZh ? '重新扫描' : 'Rescan';
  String get scanningDevices => _isZh ? '正在扫描 DLNA 设备...' : 'Scanning for DLNA devices...';
  String get retry => _isZh ? '重试' : 'Retry';
  String get noDevicesFound => _isZh ? '未找到 DLNA 设备' : 'No DLNA devices found';
  String get noDevicesHint =>
      _isZh ? '请确保电视已开启并连接到同一网络' : 'Make sure your TV is on and connected to the same network';
  String get scanAgain => _isZh ? '重新扫描' : 'Scan Again';

  // ---- Playback Screen ----
  String get nowPlaying => _isZh ? '正在播放' : 'Now Playing';
  String get noFile => _isZh ? '无文件' : 'No file';
  String castingTo(String device) => _isZh ? '投屏到 $device' : 'Casting to $device';
  String get noDevice => _isZh ? '无设备' : 'No device';

  // ---- Playback State Labels ----
  String playbackStateLabel(String state) {
    if (!_isZh) return state;
    switch (state) {
      case 'Playing':
        return '播放中';
      case 'Paused':
        return '已暂停';
      case 'Stopped':
        return '已停止';
      case 'Loading...':
        return '加载中...';
      case 'No Media':
        return '无媒体';
      default:
        return state;
    }
  }

  // ---- Playback Controls ----
  String get seekBackward5Min => _isZh ? '后退5分钟' : '-5 min';
  String get seekBackward30s => _isZh ? '后退30秒' : '-30s';
  String get seekForward30s => _isZh ? '前进30秒' : '+30s';
  String get seekForward5Min => _isZh ? '前进5分钟' : '+5 min';
  String get stop => _isZh ? '停止' : 'Stop';
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) async => S(locale);

  @override
  bool shouldReload(_SDelegate old) => false;
}
