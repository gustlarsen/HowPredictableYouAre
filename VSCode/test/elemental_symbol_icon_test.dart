import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElementalSymbolIcon & Glossy 3D Action Orb Tests', () {
    testWidgets(
      'All 5 ElementalSymbolIcon emblems render cleanly at 16px mini-icon and 36px orb sizes',
      (WidgetTester tester) async {
        for (final size in const [16.0, 36.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: Scaffold(
                body: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final move in HandMove.values)
                      ElementalSymbolIcon(move: move, size: size),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(ElementalSymbolIcon), findsNWidgets(5));
          for (final move in HandMove.values) {
            final widget = tester.widget<ElementalSymbolIcon>(
              find.byWidgetPredicate(
                (w) => w is ElementalSymbolIcon && w.move == move,
              ),
            );
            expect(widget.size, size);
          }
        }
      },
    );

    testWidgets(
      'GameScreen bottom 3D orbs contain ElementalEnergySphere, ElementalSymbolIcon, bold white shadowed labels, and active flame aura',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'unlockedNewHands': true,
          'showNewHands': true,
        });
        final storage = StorageService();
        await storage.init();
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
        );
        addTearDown(controller.dispose);
        controller.playTurn(HandMove.rock);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ChangeNotifierProvider.value(
              value: controller,
              child: const GameScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final move in HandMove.values) {
          final orbFinder = find.byKey(ValueKey('hand_orb_${move.name}'));
          expect(orbFinder, findsOneWidget);
          expect(
            find.descendant(
              of: orbFinder,
              matching: find.byType(ElementalEnergySphere),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: orbFinder,
              matching: find.byWidgetPredicate(
                (w) => w is ElementalSymbolIcon && w.move == move,
              ),
            ),
            findsOneWidget,
          );
          final label = tester.widget<Text>(
            find.descendant(
              of: orbFinder,
              matching: find.text(move.elementalLabel.toUpperCase()),
            ),
          );
          expect(label.style?.color, Colors.white);
          expect(label.style?.shadows, isNotEmpty);
        }

        expect(
          find.byKey(const ValueKey('active_orb_flame_aura_rock')),
          findsOneWidget,
        );
      },
    );
  });
}
