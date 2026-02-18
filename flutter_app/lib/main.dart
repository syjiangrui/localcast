import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/device_provider.dart';
import 'providers/file_provider.dart';
import 'providers/playback_provider.dart';
import 'screens/file_picker_screen.dart';
import 'services/api_service.dart';
import 'services/sse_service.dart';

void main() {
  final apiService = ApiService();
  final sseService = SseService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DeviceProvider(apiService)),
        ChangeNotifierProvider(
          create: (_) => PlaybackProvider(apiService, sseService),
        ),
      ],
      child: const LocalCastApp(),
    ),
  );
}

class LocalCastApp extends StatelessWidget {
  const LocalCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalCast',
      debugShowCheckedModeBanner: false,
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
