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

  runApp(needsWait
      ? BackendGate(historyService: historyService)
      : _buildMainApp(historyService));
}

Widget _buildMainApp(HistoryService historyService, {int port = 8080}) {
  final apiService = ApiService(port: port);
  final sseService = SseService(port: port);
  final deviceSseService = DeviceSseService(port: port);
  final fileProvider = FileProvider(apiService);
  final historyProvider = HistoryProvider(historyService);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: fileProvider),
      ChangeNotifierProvider(create: (_) => DeviceProvider(apiService, deviceSseService)),
      ChangeNotifierProvider.value(value: historyProvider),
      ChangeNotifierProvider(
        create: (_) => PlaybackProvider(apiService, sseService, historyProvider, fileProvider),
      ),
    ],
    child: const LocalCastApp(),
  );
}

class BackendGate extends StatefulWidget {
  final HistoryService historyService;

  const BackendGate({super.key, required this.historyService});

  @override
  State<BackendGate> createState() => _BackendGateState();
}

class _BackendGateState extends State<BackendGate> {
  late Future<bool> _ready;
  int _port = 8080;

  @override
  void initState() {
    super.initState();
    _ready = _initBackend();
  }

  Future<bool> _initBackend() async {
    _port = await _getBackendPort();
    return _waitForBackend(_port);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        if (snapshot.data == true) {
          return _buildMainApp(widget.historyService, port: _port);
        }
        return const _ErrorScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _SplashBody(),
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

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _ErrorBody(),
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

class LocalCastApp extends StatelessWidget {
  const LocalCastApp({super.key});

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
      home: const FilePickerScreen(),
    );
  }
}
