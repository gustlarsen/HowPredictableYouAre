import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'services/localization_service.dart';
import 'services/audio_service.dart';
import 'services/play_games_service.dart';
import 'services/ad_service.dart';
import 'services/billing_service.dart';
import 'services/update_service.dart';
import 'controllers/game_controller.dart';
import 'views/screens/intro_story_screen.dart';
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
  unawaited(() async {
    await billingService.initialize();
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        billingService.isAvailable) {
      await billingService.restorePurchases(silent: true);
    }
  }());

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const HowPredictableApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(adService.initialize(adsRemoved: controller.isRemoveAdsActive));
    unawaited(playGames.initialize());
  });
}

class HowPredictableApp extends StatefulWidget {
  final Widget? home;

  const HowPredictableApp({super.key, this.home});

  @override
  State<HowPredictableApp> createState() => _HowPredictableAppState();
}

class _HowPredictableAppState extends State<HowPredictableApp>
    with WidgetsBindingObserver {
  static const MethodChannel _viewportChannel = MethodChannel(
    'com.gustlarsen.howpredictable/viewport',
  );

  bool _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyEdgeToEdgeSystemUi();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncMetricsWithController();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    _syncMetricsWithController();
    _scheduleSafeRebuild();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      _applyEdgeToEdgeSystemUi();
      unawaited(_requestNativeViewportSync());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncMetricsWithController();
        _scheduleSafeRebuild();
      });
    }
  }

  void _applyEdgeToEdgeSystemUi() {
    try {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    } catch (_) {
      // Ignore on unsupported platforms or test bindings.
    }
  }

  Future<void> _requestNativeViewportSync() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _viewportChannel.invokeMethod<bool>('syncViewport');
    } catch (_) {
      // Ignore MissingPluginException in tests or unsupported runners.
    }
  }

  void _syncMetricsWithController() {
    final view = View.maybeOf(context) ??
        WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return;
    final dpr = view.devicePixelRatio;
    if (dpr <= 0) return;
    final logicalSize = view.physicalSize / dpr;
    if (logicalSize.isEmpty) return;

    try {
      context.read<GameController>().handleMetricsChanged(
        devicePixelRatio: dpr,
        logicalSize: logicalSize,
      );
    } catch (_) {
      // Ignore if provider is absent in isolated widget tests.
    }
  }

  void _scheduleSafeRebuild() {
    if (_rebuildScheduled || !mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

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
      home: widget.home ?? const _AppEntryGate(),
    );
  }
}

class _AppEntryGate extends StatelessWidget {
  const _AppEntryGate();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    return AnimatedSwitcher(
      duration: controller.animationsEnabled
          ? const Duration(milliseconds: 320)
          : Duration.zero,
      child: controller.hasSeenIntro
          ? const WorldMapScreen(key: ValueKey('entry_world_map'))
          : IntroStoryScreen(
              key: const ValueKey('entry_intro_story'),
              onFinished: controller.completeIntroStory,
            ),
    );
  }
}
