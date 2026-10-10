import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/localization_service.dart';
import 'services/audio_service.dart';
import 'controllers/game_controller.dart';
import 'views/screens/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final localization = LocalizationService();
  await localization.load();
  localization.setLanguage(storage.language);

  final audio = AudioService();
  await audio.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameController(
        storage: storage,
        localization: localization,
        audio: audio,
      ),
      child: const HowPredictableApp(),
    ),
  );
}

class HowPredictableApp extends StatelessWidget {
  const HowPredictableApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    return MaterialApp(
      title: 'How Predictable You Are',
      debugShowCheckedModeBanner: false,
      themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
          surface: const Color(0xFF16181D),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0E12),
      ),
      home: const GameScreen(),
    );
  }
}
