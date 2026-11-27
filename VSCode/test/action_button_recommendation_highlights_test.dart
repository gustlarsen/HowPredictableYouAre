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
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/theme/app_theme.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';

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

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
  AdService? adService,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_story_intro': true,
    'darkMode': true,
    'animationsEnabled': false,
    'musicEnabled': false,
    'soundEnabled': false,
    'unlockedNewHands': true,
    'showNewHands': true,
    'unlockedNewSkin': true,
    'showNewSkin': false, // Elemental mode
    'unlockedSuggestion': true,
    'showSuggestion': false,
    'unlockedCrystalBall': true,
    'showCrystalBall': false,
    'unlockedCrystalBallPlus': true,
    'showCrystalBallPlus': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  return GameController(
    storage: storage,
    localization: LocalizationService(),
    audio: AudioService(),
    adService: adService,
  );
}

RecommendationHighlightBorderPainter? _borderPainterFor(
  WidgetTester tester,
  HandMove move,
) {
  final finder = find.byKey(ValueKey('hand_button_highlight_border_${move.name}'));
  if (finder.evaluate().isEmpty) return null;
  final paint = tester.widget<CustomPaint>(finder);
  return paint.painter as RecommendationHighlightBorderPainter?;
}

double _scaleFor(WidgetTester tester, HandMove move) {
  final transform = tester.widget<Transform>(
    find.byKey(ValueKey('hand_button_scale_${move.name}')),
  );
  return transform.transform.storage[0];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Action Button Recommendation Highlights', () {
    testWidgets(
      'Suggestion-only element shows warm golden border/glow, top-left lightbulb badge, subtle scale lift, and leaves other buttons clean',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'darkMode': true,
            'showSuggestion': true,
            'showCrystalBall': false,
            'showCrystalBallPlus': false,
          },
        );
        addTearDown(controller.dispose);

        controller.suggestedMoves = [HandMove.wood];

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // WOOD (scissors) is highlighted with golden Suggestion styling + top-left lightbulb badge
        final woodBorder = _borderPainterFor(tester, HandMove.wood);
        expect(woodBorder, isNotNull);
        expect(woodBorder!.kind, ActionButtonHighlightKind.suggestionOnly);
        expect(woodBorder.isDark, isTrue);
        expect(woodBorder.suggestionPrimary, const Color(0xFFFFD54F));
        expect(woodBorder.suggestionSecondary, const Color(0xFFF5C22B));

        final woodSuggestionBadge = find.byKey(
          const ValueKey('hand_button_suggestion_badge_scissors'),
        );
        final woodCbBadge = find.byKey(
          const ValueKey('hand_button_crystal_ball_plus_badge_scissors'),
        );
        expect(woodSuggestionBadge, findsOneWidget);
        expect(woodCbBadge, findsNothing);

        // Badge is circular ~16px-18px anchored at the top-left of the button card
        final woodBtnRect = tester.getRect(
          find.byKey(const ValueKey('hand_button_scissors')),
        );
        final badgeRect = tester.getRect(woodSuggestionBadge);
        expect(badgeRect.width, inInclusiveRange(15.5, 19.5));
        expect(badgeRect.height, inInclusiveRange(15.5, 19.5));
        expect(badgeRect.center.dx, lessThan(woodBtnRect.center.dx));
        expect(badgeRect.center.dy, lessThan(woodBtnRect.center.dy));

        // Subtle lift applied to WOOD while non-recommended buttons remain at scale 1.0
        expect(_scaleFor(tester, HandMove.wood), inInclusiveRange(1.04, 1.06));
        for (final other in [
          HandMove.fire,
          HandMove.water,
          HandMove.earth,
          HandMove.metal,
        ]) {
          expect(_borderPainterFor(tester, other), isNull);
          expect(
            find.byKey(ValueKey('hand_button_suggestion_badge_${other.name}')),
            findsNothing,
          );
          expect(
            find.byKey(
              ValueKey('hand_button_crystal_ball_plus_badge_${other.name}'),
            ),
            findsNothing,
          );
          expect(_scaleFor(tester, other), equals(1.0));
        }

        // Central elemental artwork stays present and unobstructed
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('hand_button_scissors')),
            matching: find.byType(ElementalSymbolIcon),
          ),
          findsOneWidget,
        );

        // When Suggestion ties across all 5 elements (shown as '?'), no button highlights
        controller.suggestedMoves = List<HandMove>.from(HandMove.values);
        controller.notifyListeners();
        await tester.pumpAndSettle();
        for (final move in HandMove.values) {
          expect(_borderPainterFor(tester, move), isNull);
        }
      },
    );

    testWidgets(
      'Standard Crystal Ball does NOT highlight player attack buttons, while Crystal Ball+ highlights winning counters with purple-cyan border and top-right badge',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'darkMode': true,
            'showSuggestion': false,
            'showCrystalBall': true,
            'showCrystalBallPlus': false, // Standard Crystal Ball ONLY
          },
        );
        addTearDown(controller.dispose);

        // Opponent is predicted to play FIRE -> winning counters would be WATER & EARTH
        controller.crystalBallMove = HandMove.fire;

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Standard Crystal Ball must NOT falsely highlight FIRE or any attack button
        expect(controller.activeCrystalBallPlusMoves, isEmpty);
        for (final move in HandMove.values) {
          expect(_borderPainterFor(tester, move), isNull);
          expect(
            find.byKey(
              ValueKey('hand_button_crystal_ball_plus_badge_${move.name}'),
            ),
            findsNothing,
          );
          expect(_scaleFor(tester, move), equals(1.0));
        }

        // Now enable Crystal Ball+ -> WATER & EARTH (which beat FIRE) highlight with purple-cyan border + top-right badge
        controller.toggleShowCrystalBallPlus(true);
        await tester.pumpAndSettle();

        expect(
          controller.activeCrystalBallPlusMoves,
          unorderedEquals([HandMove.water, HandMove.earth]),
        );

        for (final move in [HandMove.water, HandMove.earth]) {
          final border = _borderPainterFor(tester, move);
          expect(border, isNotNull);
          expect(border!.kind, ActionButtonHighlightKind.crystalBallPlusOnly);
          expect(border.crystalBallPrimary, const Color(0xFF9C27B0));
          expect(border.crystalBallSecondary, const Color(0xFF00E5FF));

          final cbBadge = find.byKey(
            ValueKey('hand_button_crystal_ball_plus_badge_${move.name}'),
          );
          expect(cbBadge, findsOneWidget);
          expect(
            find.byKey(ValueKey('hand_button_suggestion_badge_${move.name}')),
            findsNothing,
          );

          // Badge anchored at top-right of button card
          final btnRect = tester.getRect(
            find.byKey(ValueKey('hand_button_${move.name}')),
          );
          final badgeRect = tester.getRect(cbBadge);
          expect(badgeRect.center.dx, greaterThan(btnRect.center.dx));
          expect(badgeRect.center.dy, lessThan(btnRect.center.dy));
          expect(_scaleFor(tester, move), inInclusiveRange(1.04, 1.06));
        }

        // FIRE (opponent's predicted move), WOOD, and METAL remain unhighlighted
        for (final nonCounter in [
          HandMove.fire,
          HandMove.wood,
          HandMove.metal,
        ]) {
          expect(_borderPainterFor(tester, nonCounter), isNull);
          expect(
            find.byKey(
              ValueKey(
                'hand_button_crystal_ball_plus_badge_${nonCounter.name}',
              ),
            ),
            findsNothing,
          );
          expect(_scaleFor(tester, nonCounter), equals(1.0));
        }
      },
    );

    testWidgets(
      'Dual match combines golden + purple-cyan split border, shows both top-left and top-right badges, and respects Animations setting',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'darkMode': true,
            'animationsEnabled': false, // Static mode first
            'showSuggestion': true,
            'showCrystalBall': true,
            'showCrystalBallPlus': true,
          },
        );
        addTearDown(controller.dispose);

        // Opponent predicted FIRE -> Crystal Ball+ recommends [WATER, EARTH]
        // Suggestion recommends [WOOD, EARTH]
        // Result: WOOD = Suggestion only, WATER = Crystal Ball+ only, EARTH = Both!
        controller.crystalBallMove = HandMove.fire;
        controller.suggestedMoves = [HandMove.wood, HandMove.earth];

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _borderPainterFor(tester, HandMove.wood)?.kind,
          ActionButtonHighlightKind.suggestionOnly,
        );
        expect(
          _borderPainterFor(tester, HandMove.water)?.kind,
          ActionButtonHighlightKind.crystalBallPlusOnly,
        );

        final earthBorder = _borderPainterFor(tester, HandMove.earth);
        expect(earthBorder, isNotNull);
        expect(earthBorder!.kind, ActionButtonHighlightKind.both);
        // Animations OFF: static glow & lift with pulse locked at 0.0
        expect(earthBorder.pulse, equals(0.0));
        expect(_scaleFor(tester, HandMove.earth), equals(1.05));

        final earthSuggestionBadge = find.byKey(
          const ValueKey('hand_button_suggestion_badge_lizard'),
        );
        final earthCbBadge = find.byKey(
          const ValueKey('hand_button_crystal_ball_plus_badge_lizard'),
        );
        expect(earthSuggestionBadge, findsOneWidget);
        expect(earthCbBadge, findsOneWidget);

        // Lightbulb badge sits cleanly on top-left and crystal ball badge on top-right without overlapping
        final leftBadgeRect = tester.getRect(earthSuggestionBadge);
        final rightBadgeRect = tester.getRect(earthCbBadge);
        expect(leftBadgeRect.right, lessThan(rightBadgeRect.left));

        // Animations OFF remains static across elapsed time
        await tester.pump(const Duration(milliseconds: 750));
        expect(_borderPainterFor(tester, HandMove.earth)!.pulse, equals(0.0));
        expect(_scaleFor(tester, HandMove.earth), equals(1.05));

        // Now turn Animations ON -> synchronized ~1.5s gentle pulse animates on dual-matched EARTH
        controller.toggleAnimations(true);
        await tester.pump();
        final pulseAtStart = _borderPainterFor(tester, HandMove.earth)!.pulse;
        final scaleAtStart = _scaleFor(tester, HandMove.earth);

        await tester.pump(const Duration(milliseconds: 750));
        final pulseAtPeak = _borderPainterFor(tester, HandMove.earth)!.pulse;
        final scaleAtPeak = _scaleFor(tester, HandMove.earth);

        expect(pulseAtPeak, greaterThan(pulseAtStart + 0.5));
        expect(scaleAtPeak, greaterThan(scaleAtStart));
        expect(scaleAtPeak, inInclusiveRange(1.04, 1.07));
      },
    );

    testWidgets(
      'Light Mode warm parchment uses bronze-gold Suggestion colors, preserves pastel card fill, and avoids overlap with adjacent buttons or AdMob banner',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final adService = AdService(client: _TestAdMobClient());
        await adService.initialize(adsRemoved: false);

        final controller = await _createController(
          adService: adService,
          prefs: {
            'darkMode': false,
            'animationsEnabled': false,
            'showSuggestion': true,
            'showCrystalBall': true,
            'showCrystalBallPlus': true,
          },
        );
        addTearDown(controller.dispose);

        controller.crystalBallMove = HandMove.fire; // Crystal Ball+ -> WATER, EARTH
        controller.suggestedMoves = [HandMove.wood, HandMove.earth];

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(home: GameScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Light Mode golden-bronze border tokens (#C88A00 / #8A5A00)
        final woodBorder = _borderPainterFor(tester, HandMove.wood);
        expect(woodBorder, isNotNull);
        expect(woodBorder!.isDark, isFalse);
        expect(woodBorder.suggestionPrimary, const Color(0xFFC88A00));
        expect(woodBorder.suggestionSecondary, const Color(0xFF8A5A00));

        // Light Mode Earth card still keeps its warm pastel elemental background
        const lightPalette = AppPalette(isDark: false);
        final earthBtn = find.byKey(const ValueKey('hand_button_lizard'));
        final earthContainers = tester.widgetList<Container>(
          find.descendant(of: earthBtn, matching: find.byType(Container)),
        );
        expect(
          (earthContainers.first.decoration! as BoxDecoration).color,
          lightPalette.elementalCardBackground(HandMove.earth),
        );
        expect(
          (earthContainers.first.decoration! as BoxDecoration).boxShadow,
          isNotEmpty,
        );

        // Adjacent 5-element buttons do not overlap horizontally, and card stays safely above AdMob banner
        final moveOrder = [
          HandMove.fire,
          HandMove.water,
          HandMove.wood,
          HandMove.earth,
          HandMove.metal,
        ];
        final rects = moveOrder
            .map(
              (m) => tester.getRect(find.byKey(ValueKey('hand_button_${m.name}'))),
            )
            .toList();
        for (int i = 0; i < rects.length - 1; i++) {
          expect(rects[i].right, lessThanOrEqualTo(rects[i + 1].left));
        }

        // Facing badges between adjacent WATER (top-right) and WOOD (top-left) do not collide
        final waterCbBadgeRect = tester.getRect(
          find.byKey(const ValueKey('hand_button_crystal_ball_plus_badge_paper')),
        );
        final woodSuggBadgeRect = tester.getRect(
          find.byKey(const ValueKey('hand_button_suggestion_badge_scissors')),
        );
        expect(waterCbBadgeRect.right, lessThanOrEqualTo(woodSuggBadgeRect.left));

        // Safe spacing above bottom AdMob banner preserved
        final moveCardRect = tester.getRect(
          find.byKey(const ValueKey('move_selection_card')),
        );
        final bannerRect = tester.getRect(
          find.byKey(const ValueKey('bottom_banner_ad_container')),
        );
        expect(bannerRect.top - moveCardRect.bottom, greaterThanOrEqualTo(8.0));
      },
    );
  });
}
