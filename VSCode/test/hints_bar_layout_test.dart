import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HintsBar Layout & Localization Tests', () {
    testWidgets('Renders Your Choice and PC\'s Choice side-by-side on a single row', (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedYourPrediction': true,
        'showYourPrediction': true,
        'unlockedNextMove': true,
        'showNextMove': true,
        'unlockedSuggestion': true,
        'showSuggestion': true,
        'unlockedCrystalBall': true,
        'showCrystalBall': true,
        'animationsEnabled': false,
      });
      final storage = StorageService();
      await storage.init();
      final localization = LocalizationService();
      final controller = GameController(
        storage: storage,
        localization: localization,
        audio: AudioService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: HintsBar(controller: controller),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your Choice:'), findsOneWidget);
      expect(find.text("PC's Choice:"), findsOneWidget);
      expect(find.text('Suggestion:'), findsOneWidget);
      expect(find.text('Crystal Ball:'), findsOneWidget);

      final yourChip = find.ancestor(
        of: find.text('Your Choice:'),
        matching: find.byType(Container),
      ).first;
      final pcChip = find.ancestor(
        of: find.text("PC's Choice:"),
        matching: find.byType(Container),
      ).first;
      final suggChip = find.ancestor(
        of: find.text('Suggestion:'),
        matching: find.byType(Container),
      ).first;
      final cbChip = find.ancestor(
        of: find.text('Crystal Ball:'),
        matching: find.byType(Container),
      ).first;

      // Row 1: side-by-side
      expect(tester.getTopLeft(yourChip).dy, equals(tester.getTopLeft(pcChip).dy));
      // Row 2: side-by-side
      expect(tester.getTopLeft(suggChip).dy, equals(tester.getTopLeft(cbChip).dy));
      // Row 2 is below Row 1
      expect(tester.getTopLeft(suggChip).dy, greaterThan(tester.getTopLeft(yourChip).dy));

      // Check mini icons are present
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('Single prediction upgrade occupies the row cleanly without empty gaps', (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedYourPrediction': true,
        'showYourPrediction': true,
        'showNextMove': false,
        'showSuggestion': false,
        'showCrystalBall': false,
        'animationsEnabled': false,
      });
      final storage = StorageService();
      await storage.init();
      final localization = LocalizationService();
      final controller = GameController(
        storage: storage,
        localization: localization,
        audio: AudioService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: HintsBar(controller: controller),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your Choice:'), findsOneWidget);
      expect(find.text("PC's Choice:"), findsNothing);

      final chipFinder = find.ancestor(
        of: find.text('Your Choice:'),
        matching: find.byType(Container),
      ).first;
      expect(tester.getSize(chipFinder).width, equals(360.0));
    });

    testWidgets('Narrow screen with up to 4 tied moves renders without layout overflow', (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedYourPrediction': true,
        'showYourPrediction': true,
        'unlockedNextMove': true,
        'showNextMove': true,
        'showSuggestion': true,
        'showCrystalBall': false,
        'showNewSkin': true, // Classic emojis
        'showNewHands': true, // 5 hands
        'animationsEnabled': false,
      });
      final storage = StorageService();
      await storage.init();
      final localization = LocalizationService();
      final controller = GameController(
        storage: storage,
        localization: localization,
        audio: AudioService(),
      );

      controller.predictedUserMoves = [
        HandMove.rock,
        HandMove.paper,
        HandMove.scissors,
        HandMove.lizard,
      ];
      controller.pcNextMoves = [
        HandMove.rock,
        HandMove.paper,
        HandMove.scissors,
        HandMove.spock,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: HintsBar(controller: controller),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Your Choice:'), findsOneWidget);
      expect(find.text("PC's Choice:"), findsOneWidget);

      final yourChip = find.ancestor(
        of: find.text('Your Choice:'),
        matching: find.byType(Container),
      ).first;
      final pcChip = find.ancestor(
        of: find.text("PC's Choice:"),
        matching: find.byType(Container),
      ).first;
      expect(tester.getTopLeft(yourChip).dy, equals(tester.getTopLeft(pcChip).dy));
    });

    testWidgets('Elemental mode with up to 4 tied moves renders without overflow', (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedYourPrediction': true,
        'showYourPrediction': true,
        'unlockedNextMove': true,
        'showNextMove': true,
        'showSuggestion': false,
        'showCrystalBall': false,
        'showNewSkin': false, // Elemental mode
        'showNewHands': true,
        'animationsEnabled': false,
      });
      final storage = StorageService();
      await storage.init();
      final localization = LocalizationService();
      final controller = GameController(
        storage: storage,
        localization: localization,
        audio: AudioService(),
      );

      controller.predictedUserMoves = [
        HandMove.rock,
        HandMove.paper,
        HandMove.scissors,
        HandMove.lizard,
      ];
      controller.pcNextMoves = [
        HandMove.rock,
        HandMove.paper,
        HandMove.scissors,
        HandMove.spock,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: HintsBar(controller: controller),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Your Choice:'), findsOneWidget);
      expect(find.text("PC's Choice:"), findsOneWidget);

      final yourChip = find.ancestor(
        of: find.text('Your Choice:'),
        matching: find.byType(Container),
      ).first;
      final pcChip = find.ancestor(
        of: find.text("PC's Choice:"),
        matching: find.byType(Container),
      ).first;
      expect(tester.getTopLeft(yourChip).dy, equals(tester.getTopLeft(pcChip).dy));
    });

    testWidgets('HintsBar pills maintain the exact same fixed height (34.0) whether showing ? or element icons or classic emojis without shifting VersusArena', (tester) async {
      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedYourPrediction': true,
        'showYourPrediction': true,
        'unlockedNextMove': true,
        'showNextMove': true,
        'unlockedSuggestion': true,
        'showSuggestion': true,
        'unlockedCrystalBall': true,
        'showCrystalBall': true,
        'animationsEnabled': false,
      });
      final storage = StorageService();
      await storage.init();
      final localization = LocalizationService();
      final controller = GameController(
        storage: storage,
        localization: localization,
        audio: AudioService(),
      );

      final arenaKey = const ValueKey('test_versus_arena_box');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 360,
                      child: HintsBar(controller: controller),
                    ),
                    Container(
                      key: arenaKey,
                      width: 360,
                      height: 150,
                      color: Colors.black,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // 1. Initial state: Your Choice, PC's Choice, and Suggestion show '?' (no prior Markov history)
      expect(controller.predictedUserMoves, isEmpty);
      expect(controller.pcNextMoves, isEmpty);
      expect(controller.suggestedMoves, isEmpty);
      expect(find.text('?'), findsNWidgets(3));

      final yourChipFinder = find.ancestor(
        of: find.text('Your Choice:'),
        matching: find.byType(Container),
      ).first;
      final pcChipFinder = find.ancestor(
        of: find.text("PC's Choice:"),
        matching: find.byType(Container),
      ).first;
      final suggChipFinder = find.ancestor(
        of: find.text('Suggestion:'),
        matching: find.byType(Container),
      ).first;
      final cbChipFinder = find.ancestor(
        of: find.text('Crystal Ball:'),
        matching: find.byType(Container),
      ).first;

      final initialHintsBarHeight = tester.getSize(find.byType(HintsBar)).height;
      final initialArenaTop = tester.getTopLeft(find.byKey(arenaKey)).dy;

      expect(tester.getSize(yourChipFinder).height, equals(34.0));
      expect(tester.getSize(pcChipFinder).height, equals(34.0));
      expect(tester.getSize(suggChipFinder).height, equals(34.0));
      expect(tester.getSize(cbChipFinder).height, equals(34.0));

      // 2. Elemental mode with single element icon in each pill
      controller.predictedUserMoves = [HandMove.rock];
      controller.pcNextMoves = [HandMove.paper];
      controller.suggestedMoves = [HandMove.scissors];
      controller.notifyListeners();
      await tester.pump();

      expect(find.text('?'), findsNothing);
      expect(tester.getSize(yourChipFinder).height, equals(34.0));
      expect(tester.getSize(pcChipFinder).height, equals(34.0));
      expect(tester.getSize(suggChipFinder).height, equals(34.0));
      expect(tester.getSize(cbChipFinder).height, equals(34.0));
      expect(tester.getSize(find.byType(HintsBar)).height, equals(initialHintsBarHeight));
      expect(tester.getTopLeft(find.byKey(arenaKey)).dy, equals(initialArenaTop));

      // 3. Elemental mode with multiple tied element icons
      controller.predictedUserMoves = [HandMove.rock, HandMove.paper];
      controller.pcNextMoves = [HandMove.paper, HandMove.scissors];
      controller.suggestedMoves = [HandMove.scissors, HandMove.rock];
      controller.notifyListeners();
      await tester.pump();

      expect(tester.getSize(yourChipFinder).height, equals(34.0));
      expect(tester.getSize(pcChipFinder).height, equals(34.0));
      expect(tester.getSize(suggChipFinder).height, equals(34.0));
      expect(tester.getSize(cbChipFinder).height, equals(34.0));
      expect(tester.getSize(find.byType(HintsBar)).height, equals(initialHintsBarHeight));
      expect(tester.getTopLeft(find.byKey(arenaKey)).dy, equals(initialArenaTop));

      // 4. Classic Hands mode (emojis) and back to '?'
      controller.toggleShowNewSkin(true);
      await tester.pump();

      expect(tester.getSize(yourChipFinder).height, equals(34.0));
      expect(tester.getSize(pcChipFinder).height, equals(34.0));
      expect(tester.getSize(suggChipFinder).height, equals(34.0));
      expect(tester.getSize(cbChipFinder).height, equals(34.0));
      expect(tester.getSize(find.byType(HintsBar)).height, equals(initialHintsBarHeight));
      expect(tester.getTopLeft(find.byKey(arenaKey)).dy, equals(initialArenaTop));

      controller.resetGame();
      await tester.pump();
      expect(find.text('?'), findsNWidgets(3));
      expect(tester.getSize(yourChipFinder).height, equals(34.0));
      expect(tester.getSize(pcChipFinder).height, equals(34.0));
      expect(tester.getSize(suggChipFinder).height, equals(34.0));
      expect(tester.getSize(cbChipFinder).height, equals(34.0));
      expect(tester.getSize(find.byType(HintsBar)).height, equals(initialHintsBarHeight));
      expect(tester.getTopLeft(find.byKey(arenaKey)).dy, equals(initialArenaTop));
    });

    test('Localization strings JSON in en, pt, es, de are concise and correct', () {
      final jsonFile = File('assets/data/stringsHowPredict.json');
      final data = json.decode(jsonFile.readAsStringSync()) as Map<String, dynamic>;

      // English
      expect(data['en_string12'], 'Your Choice:');
      expect(data['en_string13'], "PC's Choice:");
      expect(data['en_string14'], 'Suggestion:');

      // Portuguese
      expect(data['pt_string12'], 'Sua Escolha:');
      expect(data['pt_string13'], 'Escolha PC:');
      expect(data['pt_string14'], 'Sugestão:');

      // Spanish
      expect(data['es_string12'], 'Su Elección:');
      expect(data['es_string13'], 'Elección PC:');
      expect(data['es_string14'], 'Sugerencia:');

      // German
      expect(data['de_string12'], 'Deine Wahl:');
      expect(data['de_string13'], 'PC-Wahl:');
      expect(data['de_string14'], 'Vorschlag:');
    });
  });
}
