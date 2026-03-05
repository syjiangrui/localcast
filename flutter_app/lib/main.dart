import 'dart:io';

import 'package:flutter/material.dart';
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

Future<bool> _waitForBackend() async {
  const timeout = Duration(seconds: 10);
  const interval = Duration(milliseconds: 200);
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:8080/api/status'))
          .timeout(const Duration(seconds: 1));
      if (response.statusCode == 200) return true;
    } catch (_) {
      // Backend not ready yet
    }
    await Future.delayed(interval);
  }
  return false;
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

Widget _buildMainApp(HistoryService historyService) {
  final apiService = ApiService();
  final sseService = SseService();
  final deviceSseService = DeviceSseService();
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

  @override
  void initState() {
    super.initState();
    _ready = _waitForBackend();
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
          return _buildMainApp(widget.historyService);
        }
        return const _ErrorScreen();
      },
    );
  }
}

class _SplashScreen extends MaterialApp {
  const _SplashScreen()
      : super(
          debugShowCheckedModeBanner: false,
          home: const _SplashBody(),
        );
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

class _ErrorScreen extends MaterialApp {
  const _ErrorScreen()
      : super(
          debugShowCheckedModeBanner: false,
          home: const _ErrorBody(),
        );
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const FilePickerScreen(),
    );
  }
}
