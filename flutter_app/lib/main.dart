import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/device_provider.dart';
import 'providers/file_provider.dart';
import 'providers/history_provider.dart';
import 'providers/playback_provider.dart';
import 'screens/file_picker_screen.dart';
import 'services/api_service.dart';
import 'services/history_service.dart';
import 'services/sse_service.dart';

const _channel = MethodChannel('com.localcast/backend');
const _seedColor = Color(0xFF00897B); // Teal 600

Future<int> _getBackendPort() async {
  try {
    final port = await _channel.invokeMethod<int>('getPort');
    return port ?? 8080;
  } catch (_) {
    return 8080;
  }
}

Future<bool> _waitForBackend(int port) async {
  const timeout = Duration(seconds: 10);
  const interval = Duration(milliseconds: 200);
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/status'))
          .timeout(const Duration(seconds: 1));
      if (response.statusCode == 200) return true;
    } catch (_) {
      // Backend not ready yet
    }
    await Future.delayed(interval);
  }
  return false;
}

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surfaceContainer,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: colorScheme.surfaceContainerHighest,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final historyService = HistoryService();
  await historyService.init();

  // On macOS/Windows the backend is bundled and spawned by the native runner.
  // On other platforms (or during development) assume it is already running.
  final needsWait = Platform.isMacOS || Platform.isWindows;

  runApp(LocalCastApp(
    historyService: historyService,
    needsBackendWait: needsWait,
  ));
}

class LocalCastApp extends StatefulWidget {
  final HistoryService historyService;
  final bool needsBackendWait;

  const LocalCastApp({
    super.key,
    required this.historyService,
    required this.needsBackendWait,
  });

  @override
  State<LocalCastApp> createState() => _LocalCastAppState();
}

class _LocalCastAppState extends State<LocalCastApp> {
  Future<int>? _portFuture;

  @override
  void initState() {
    super.initState();
    if (widget.needsBackendWait) {
      _portFuture = _initBackend();
    }
  }

  Future<int> _initBackend() async {
    final port = await _getBackendPort();
    final ok = await _waitForBackend(port);
    if (!ok) throw Exception('Backend failed to start');
    return port;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '本地投屏助手',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: _portFuture == null
          ? _MainHome(historyService: widget.historyService, port: 8080)
          : FutureBuilder<int>(
              future: _portFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _SplashBody();
                }
                if (snapshot.hasData) {
                  return _MainHome(
                    historyService: widget.historyService,
                    port: snapshot.data!,
                  );
                }
                return const _ErrorBody();
              },
            ),
    );
  }
}

/// Wraps providers + FilePickerScreen so they are only created once the port is known.
class _MainHome extends StatefulWidget {
  final HistoryService historyService;
  final int port;

  const _MainHome({required this.historyService, required this.port});

  @override
  State<_MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<_MainHome> {
  late final ApiService _apiService;
  late final SseService _sseService;
  late final DeviceSseService _deviceSseService;
  late final FileProvider _fileProvider;
  late final HistoryProvider _historyProvider;
  late final DeviceProvider _deviceProvider;
  late final PlaybackProvider _playbackProvider;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(port: widget.port);
    _sseService = SseService(port: widget.port);
    _deviceSseService = DeviceSseService(port: widget.port);
    _fileProvider = FileProvider(_apiService);
    _historyProvider = HistoryProvider(widget.historyService);
    _deviceProvider = DeviceProvider(_apiService, _deviceSseService);
    _playbackProvider = PlaybackProvider(
      _apiService, _sseService, _historyProvider, _fileProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _fileProvider),
        ChangeNotifierProvider.value(value: _deviceProvider),
        ChangeNotifierProvider.value(value: _historyProvider),
        ChangeNotifierProvider.value(value: _playbackProvider),
      ],
      child: const FilePickerScreen(),
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在启动后台服务...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Failed to start backend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('后台服务未能在规定时间内响应。'),
          ],
        ),
      ),
    );
  }
}
