import 'package:flutter/material.dart';
import 'controllers/game_controller.dart';
import 'services/audio_service.dart';
import 'services/localization_service.dart';
import 'services/markov_engine.dart';
import 'services/storage_service.dart';
import 'views/screens/screen1.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = GameController(
    storage: StorageService(),
    localization: LocalizationService(),
    markovEngine: MarkovEngine(),
    audio: AudioService(),
  );
  await controller.initialize();

  runApp(HowPredictableApp(controller: controller));
}

class HowPredictableApp extends StatelessWidget {
  final GameController controller;

  const HowPredictableApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDark = controller.darkMode == 1;
        return MaterialApp(
          title: 'How Predictable You Are',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF3F51B5),
            scaffoldBackgroundColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3F51B5),
              secondary: const Color(0xFFFEC007),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF3F51B5),
            scaffoldBackgroundColor: Colors.black,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3F51B5),
              secondary: const Color(0xFFFEC007),
              brightness: Brightness.dark,
            ),
          ),
          home: Screen1(controller: controller),
        );
      },
    );
  }
}
