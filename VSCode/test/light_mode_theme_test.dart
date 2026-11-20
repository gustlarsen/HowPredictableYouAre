import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/ad_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/theme/app_theme.dart';
import 'package:how_predictable/views/dialogs/help_dialog.dart';
import 'package:how_predictable/views/dialogs/inventory_dialog.dart';
import 'package:how_predictable/views/dialogs/settings_dialog.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/dialogs/story_gallery_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/adaptive_rewarded_ad_button.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';
import 'package:how_predictable/views/widgets/markov_matrix_view.dart';
import 'package:how_predictable/views/widgets/score_header.dart';
import 'package:how_predictable/views/widgets/versus_arena.dart';

class _TestPlayGamesClient implements PlayGamesClient {
  @override
  Future<String?> signIn() async => 'success';

  @override
  Future<String?> getPlayerName() async => 'LightTester';

  @override
  Future<String?> getPlayerID() async => 'a_2116013489197419559';

  @override
  Future<String?> saveGame({required String data, required String name}) async =>
      'success';

  @override
  Future<String?> loadGame({required String name}) async => null;
}

class _TestAdMobClient extends AdMobClient {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadBanner({
    required String adUnitId,
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Widget? buildBannerWidget() => const SizedBox(width: 320, height: 50);

  @override
  void disposeBanner() {}

  @override
  Future<void> loadRewarded({
    required String adUnitId,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    onLoaded();
  }

  @override
  Future<bool> showRewarded({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onDismissed,
    required VoidCallback onFailedToShow,
  }) async {
    onUserEarnedReward();
    onDismissed();
    return true;
  }

  @override
  void disposeRewarded() {}
}

Future<GameController> _createTestController({
  Map<String, Object> prefs = const {},
  PlayGamesService? playGames,
  AdService? adService,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'darkMode': false,
    'animationsEnabled': false,
    'musicEnabled': false,
    'soundEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  final audio = AudioService();

  return GameController(
    storage: storage,
    localization: localization,
    audio: audio,
    playGames: playGames,
    adService: adService,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lightPalette = AppPalette(isDark: false);

  group('Light Mode Theme Audit', () {
    testWidgets(
      'InventoryDialog (Cleric\'s Backpack) adapts cleanly to Light Mode and keeps Dark Mode intact',
      (WidgetTester tester) async {
        final controller = await _createTestController(
          prefs: {
            'orbs_fire': 12,
            'orbs_water': 8,
            'orbs_wood': 15,
            'orbs_earth': 5,
            'orbs_metal': 3,
            'unlockedNewHands': false,
            'showNewHands': false,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: InventoryDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cardContainer = tester.widget<Container>(
          find.byKey(const ValueKey('inventory_dialog_card')),
        );
        final cardDecoration = cardContainer.decoration! as BoxDecoration;
        expect(cardDecoration.color, lightPalette.dialogSurface);

        final titleText = tester.widget<Text>(find.text("Cleric's Backpack"));
        expect(titleText.style?.color, lightPalette.primaryText);

        final subtitleText = tester.widget<Text>(
          find.text('Elemental Energy Orbs Inventory'),
        );
        expect(subtitleText.style?.color, lightPalette.amberSubtitle);

        // Check pastel backgrounds, crisp borders, and dark orb counts for all 5 elements
        final expectedCounts = <HandMove, String>{
          HandMove.rock: '12',
          HandMove.paper: '8',
          HandMove.scissors: '15',
          HandMove.lizard: '5',
          HandMove.spock: '3',
        };
        for (final move in HandMove.values) {
          final isLocked = move == HandMove.lizard || move == HandMove.spock;
          final rowContainer = tester.widget<Container>(
            find.byKey(ValueKey('inventory_orb_row_${move.orbKey}')),
          );
          final rowDecoration = rowContainer.decoration! as BoxDecoration;
          expect(
            rowDecoration.color,
            lightPalette.elementalCardBackground(move, locked: isLocked),
          );
          expect(
            (rowDecoration.border! as Border).top.color,
            lightPalette.elementalCardBorder(move, locked: isLocked),
          );

          final countText = tester.widget<Text>(
            find.byKey(ValueKey('inventory_orb_count_${move.orbKey}')),
          );
          expect(countText.data, expectedCounts[move]);
          expect(countText.style?.color, lightPalette.primaryText);
        }

        // Verify readable dark status text
        final activeStatus = tester.widget<Text>(
          find.text('Active').first,
        );
        expect(activeStatus.style?.color, lightPalette.secondaryText);

        final lockedStatus = tester.widget<Text>(
          find.text('Locked (Unlock Earth & Metal)').first,
        );
        expect(lockedStatus.style?.color, lightPalette.amberText);

        // Verify Dark Mode still renders dark card surface
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: InventoryDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final darkCard = tester.widget<Container>(
          find.byKey(const ValueKey('inventory_dialog_card')),
        );
        expect(
          (darkCard.decoration! as BoxDecoration).color,
          const Color(0xFF14161D),
        );
      },
    );

    testWidgets(
      'ShopDialog uses warm parchment surfaces, dark amber-bronze subtitles, and crisp Earth orb costs in Light Mode',
      (WidgetTester tester) async {
        final controller = await _createTestController(
          prefs: {
            'orbs_fire': 25,
            'orbs_water': 30,
            'orbs_wood': 18,
            'orbs_earth': 9,
            'orbs_metal': 4,
            'unlockedPredictability': false,
            'unlockedNewHands': false,
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: ShopDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(dialog.backgroundColor, lightPalette.dialogSurface);

        // Top elemental balance bar should be warm sand with dark legible counts
        final summaryBar = tester.widget<Container>(
          find.byKey(const ValueKey('shop_orb_summary_bar')),
        );
        expect(
          (summaryBar.decoration! as BoxDecoration).color,
          lightPalette.summaryBarSurface,
        );
        final fireCountText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('shop_header_orb_fire')),
            matching: find.text('25'),
          ),
        );
        expect(fireCountText.style?.color, lightPalette.primaryText);

        // Free Elemental Orbs rewarded ad card
        final adCard = tester.widget<Card>(
          find.byKey(const ValueKey('shop_rewarded_ad_card')),
        );
        expect(adCard.color, lightPalette.rewardedAdCardSurface);
        final adShape = adCard.shape! as RoundedRectangleBorder;
        expect(adShape.side.color, lightPalette.rewardedAdCardBorder);

        final adSubtitle = tester.widget<Text>(
          find.text('Watch a video ad for +50 of each Elemental Orb'),
        );
        expect(adSubtitle.style?.color, lightPalette.amberText);

        final scrollable = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );

        // Upgrade description subtitles use warm bronze (#7A4E00)
        final predDescFinder = find.text(
          'Unlocks Match Scoreboard (Your Score, PC Score, Total) & Predictability Gauge %',
        );
        await tester.scrollUntilVisible(
          predDescFinder,
          120,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        final predDesc = tester.widget<Text>(predDescFinder);
        expect(predDesc.style?.color, lightPalette.amberSubtitle);

        // "Unlock" labels use dark charcoal (#4A4238)
        final unlockLabel = tester.widget<Text>(find.text('Unlock').first);
        expect(unlockLabel.style?.color, lightPalette.secondaryText);

        // Scroll to Show Markov Algorithm (which includes Earth & Metal orb costs)
        final algoBtn = find.byKey(
          const ValueKey(
            'diamond_unlock_${BillingService.productShowAlgorithm}',
          ),
        );
        await tester.scrollUntilVisible(
          algoBtn,
          160,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();

        final earthCostIcon = tester.widget<Icon>(
          find.descendant(
            of: algoBtn,
            matching: find.byIcon(HandMove.lizard.elementalIcon),
          ),
        );
        expect(earthCostIcon.color, lightPalette.elementalText(HandMove.lizard));
        expect(earthCostIcon.color, const Color(0xFF9A6700));

        final earthCostText = tester.widget<Text>(
          find.descendant(of: algoBtn, matching: find.text('50')).first,
        );
        expect(earthCostText.style?.color, const Color(0xFF9A6700));

        final metalCostIcon = tester.widget<Icon>(
          find.descendant(
            of: algoBtn,
            matching: find.byIcon(HandMove.spock.elementalIcon),
          ),
        );
        expect(metalCostIcon.color, const Color(0xFF435660));
      },
    );

    testWidgets(
      'SettingsDialog uses warm sand cards and high-contrast bronze/charcoal text in Light Mode',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'darkMode': false,
          'animationsEnabled': false,
          'musicEnabled': false,
          'soundEnabled': false,
        });
        final storage = StorageService();
        await storage.init();
        final playGames = PlayGamesService(
          storage: storage,
          client: _TestPlayGamesClient(),
        );
        await playGames.signIn();

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          playGames: playGames,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: SettingsDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(dialog.backgroundColor, lightPalette.dialogSurface);

        // Outer profile section uses warm sand tint
        final profileSection = tester.widget<Container>(
          find.byKey(const ValueKey('settings_player_profile_section')),
        );
        expect(
          (profileSection.decoration! as BoxDecoration).color,
          lightPalette.sandCardSurface,
        );

        // Inner connected profile card uses warm cream instead of dark translucent black
        final innerCard = tester.widget<Container>(
          find.byKey(const ValueKey('play_games_profile_card')),
        );
        final innerDec = innerCard.decoration! as BoxDecoration;
        expect(innerDec.color, lightPalette.dialogCardSurface);
        expect((innerDec.border! as Border).top.color, lightPalette.sandCardBorder);

        final headerText = tester.widget<Text>(find.text('Player Profile'));
        expect(headerText.style?.color, lightPalette.amberText);

        final playerIdText = tester.widget<Text>(
          find.byKey(const ValueKey('play_games_player_id')),
        );
        expect(playerIdText.style?.color, lightPalette.secondaryText);

        final syncedText = tester.widget<Text>(find.text('Synced'));
        expect(syncedText.style?.color, lightPalette.successText);

        // Story Memories & Ok buttons use warm bronze foreground
        final storyBtn = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey('settings_story_memories_button')),
        );
        expect(
          storyBtn.style?.foregroundColor?.resolve({}),
          lightPalette.amberText,
        );

        final okBtn = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey('settings_ok_button')),
        );
        expect(
          okBtn.style?.foregroundColor?.resolve({}),
          lightPalette.amberText,
        );
      },
    );

    testWidgets(
      'HelpDialog, StoryGalleryDialog, and main GameScreen widgets render crisp Light Mode colors without dark-locked containers',
      (WidgetTester tester) async {
        final adService = AdService(client: _TestAdMobClient());
        final controller = await _createTestController(
          adService: adService,
          prefs: {
            'unlockedPredictability': true,
            'showPredictability': true,
            'unlockedAlgorithm': true,
            'showAlgorithm': true,
            'unlockedYourPrediction': true,
            'showYourPrediction': true,
            'unlockedNextMove': true,
            'showNextMove': true,
            'unlockedSuggestion': true,
            'showSuggestion': true,
            'unlockedCrystalBall': true,
            'showCrystalBall': true,
            'unlockedNewHands': true,
            'showNewHands': true,
            'unlockedRandom': true,
            'showRandom': true,
            'unlockedNewSkin': true,
            'showNewSkin': false, // Elemental mode ON
          },
        );
        addTearDown(controller.dispose);

        await adService.initialize(adsRemoved: false);

        // 1. Check HelpDialog in Light Mode
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: HelpDialog(localization: controller.localization),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
          lightPalette.dialogSurface,
        );
        final proTipTitle = tester.widget<Text>(
          find.text('💡 Pro Tip: The Markov Model'),
        );
        expect(proTipTitle.style?.color, lightPalette.amberText);

        // 2. Check StoryGalleryDialog in Light Mode
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: StoryGalleryDialog(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
          lightPalette.dialogSurface,
        );
        final chapterNumberText = tester.widget<Text>(find.text('#1'));
        expect(chapterNumberText.style?.color, isNot(Colors.white54));

        // 3. Check full GameScreen in Light Mode (`darkMode: false`)
        controller.userScore = 4;
        controller.pcScore = 6;
        controller.totalRounds = 10;
        controller.crystalBallMove = HandMove.lizard; // Earth
        controller.playTurn(HandMove.rock); // Fire round

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Rewarded Ad pill adapts to light parchment instead of hardcoded #151821
        final adButtonFinder = find.byKey(
          const ValueKey('watch_rewarded_ad_button'),
        );
        expect(adButtonFinder, findsOneWidget);
        final adPillContainer = tester.widget<Container>(
          find.descendant(
            of: adButtonFinder,
            matching: find.byType(Container),
          ),
        );
        expect(
          (adPillContainer.decoration! as BoxDecoration).color,
          isNot(const Color(0xFF151821).withValues(alpha: 0.90)),
        );

        // ScoreHeader uses light card & high-contrast Light Mode amber-bronze gauge
        expect(find.byType(ScoreHeader), findsOneWidget);
        expect(
          ScoreHeader.gaugeColor(40.0, isDark: false),
          ScoreHeader.lightAmberBronze,
        );

        // HintsBar, VersusArena, and MarkovMatrixView are present cleanly
        expect(find.byType(HintsBar), findsOneWidget);
        expect(find.byType(VersusArena), findsOneWidget);
        expect(find.byType(MarkovMatrixView), findsOneWidget);
        expect(find.byType(AdaptiveRewardedAdButton), findsOneWidget);

        // Elemental hand buttons do NOT stay stuck on dark #10131C in Light Mode
        final earthBtnFinder = find.byKey(
          const ValueKey('hand_button_lizard'),
        );
        expect(earthBtnFinder, findsOneWidget);
        final earthContainers = tester.widgetList<Container>(
          find.descendant(
            of: earthBtnFinder,
            matching: find.byType(Container),
          ),
        );
        expect(
          earthContainers.first.decoration,
          isA<BoxDecoration>().having(
            (d) => d.color,
            'Light Mode Earth card background',
            lightPalette.elementalCardBackground(HandMove.lizard),
          ),
        );

        // Earth label uses high-contrast #9A6700 instead of #FFB300
        final earthLabel = tester.widget<Text>(
          find.descendant(
            of: earthBtnFinder,
            matching: find.text('EARTH'),
          ),
        );
        expect(earthLabel.style?.color, const Color(0xFF9A6700));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
