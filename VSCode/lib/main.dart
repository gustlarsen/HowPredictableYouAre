import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/localization_service.dart';
import 'services/audio_service.dart';
import 'services/play_games_service.dart';
import 'services/ad_service.dart';
import 'services/billing_service.dart';
import 'services/update_service.dart';
import 'controllers/game_controller.dart';
import 'views/screens/world_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final localization = LocalizationService();
  await localization.load();
  localization.setLanguage(storage.language);

  final audio = AudioService();
  await audio.init();

  final playGames = PlayGamesService(storage: storage);
  final adService = AdService();
  final billingService = BillingService();
  final updateService = UpdateService();
  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: audio,
    playGames: playGames,
    adService: adService,
    billingService: billingService,
    updateService: updateService,
  );
  unawaited(adService.initialize(adsRemoved: controller.unlockedAds));
  unawaited(billingService.initialize());

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const HowPredictableApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(playGames.initialize());
  });
}

class HowPredictableApp extends StatelessWidget {
  final Widget? home;

  const HowPredictableApp({super.key, this.home});

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
          surface: const Color(0xFFFAF6EE),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFFFAF6EE),
          surfaceTintColor: Colors.transparent,
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
      home: home ?? const WorldMapScreen(),
    );
  }
}
