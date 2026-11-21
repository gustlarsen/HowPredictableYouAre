import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameController> createController({
    int currentWeek = 12,
    bool unlockedCrystalBall = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_story_intro': true,
      'animationsEnabled': false,
      'musicEnabled': false,
      'current_week': currentWeek,
      'orbs_fire': 123,
      'orbs_water': 45,
      'orbs_wood': 67,
      'orbs_earth': 89,
      'orbs_metal': 10,
      'unlockedCrystalBall': unlockedCrystalBall,
      'showCrystalBall': unlockedCrystalBall,
    });
    final storage = StorageService();
    await storage.init();
    final localization = LocalizationService();
    await localization.load();
    return GameController(
      storage: storage,
      localization: localization,
      audio: AudioService(),
    );
  }

  for (final isDark in [true, false]) {
    testWidgets(
      'Altar of Offerings / ShopDialog renders 3D ElementalEnergySphere orbs across header, ad card, and single-row cost pills (${isDark ? "Dark" : "Light"} Mode)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = await createController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: isDark
                ? ThemeData.dark(useMaterial3: true)
                : ThemeData.light(useMaterial3: true),
            home: Scaffold(
              body: ShopDialog(controller: controller, fromTemple: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sacred Temple'), findsOneWidget);

        // 1. No flat combat elemental icons anywhere inside ShopDialog
        for (final move in HandMove.values) {
          expect(
            find.descendant(
              of: find.byType(ShopDialog),
              matching: find.byIcon(move.elementalIcon),
            ),
            findsNothing,
          );
        }

        // 2. Top Elemental Balance Header uses 5 3D ElementalEnergySpheres (~16-18px)
        for (final move in HandMove.values) {
          final headerSphereFinder = find.byKey(
            ValueKey('shop_header_orb_sphere_${move.orbKey}'),
          );
          expect(headerSphereFinder, findsOneWidget);
          final sphere = tester.widget<ElementalEnergySphere>(
            headerSphereFinder,
          );
          expect(sphere.primaryColor, move.elementalPrimaryColor);
          expect(sphere.secondaryColor, move.elementalSecondaryColor);
          expect(sphere.isDark, isDark);
          expect(sphere.size, inInclusiveRange(16.0, 18.0));
        }

        // 3. Wing 1 (Consagration): Stat Upgrade Cost Pills (+1 Max HP, +1 Max Mana Pool)
        // use 3D spheres (~13-15px) on one row
        for (final btnKey in const [
          ValueKey('shop_upgrade_max_hp_button'),
          ValueKey('shop_upgrade_max_mana_button'),
        ]) {
          final btnFinder = find.byKey(btnKey);
          expect(btnFinder, findsOneWidget);
          final spheres = tester
              .widgetList<ElementalEnergySphere>(
                find.descendant(
                  of: btnFinder,
                  matching: find.byType(ElementalEnergySphere),
                ),
              )
              .toList();
          expect(spheres.length, 3);
          for (final sphere in spheres) {
            expect(sphere.isDark, isDark);
            expect(sphere.size, inInclusiveRange(13.0, 15.0));
          }
          // All 3 spheres aligned on a single horizontal row
          final yCenters = {
            for (final move in [
              HandMove.rock,
              HandMove.paper,
              HandMove.scissors,
            ])
              tester
                  .getCenter(
                    find.descendant(
                      of: btnFinder,
                      matching: find.byKey(
                        ValueKey('shop_cost_orb_${move.orbKey}'),
                      ),
                    ),
                  )
                  .dy
                  .round(),
          };
          expect(yCenters.length, 1);
        }

        // 4. Wing 5 (Prayer Room): Free Elemental Orbs Rewarded Ad Card uses 3D ElementalEnergySpheres (~18-20px)
        await tester.tap(find.byKey(const ValueKey('temple_tab_prayer')));
        await tester.pumpAndSettle();
        for (final move in HandMove.values) {
          final adOrbFinder = find.byKey(
            ValueKey('shop_ad_orb_icon_${move.name}'),
          );
          expect(adOrbFinder, findsOneWidget);
          final sphere = tester.widget<ElementalEnergySphere>(adOrbFinder);
          expect(sphere.primaryColor, move.elementalPrimaryColor);
          expect(sphere.secondaryColor, move.elementalSecondaryColor);
          expect(sphere.isDark, isDark);
          expect(sphere.size, inInclusiveRange(18.0, 20.0));
        }

        // 5. Wing 2 (Altar of Offerings): Scroll to 5-orb Crystal Ball+ cost pill and verify single-row alignment
        await tester.tap(find.byKey(const ValueKey('temple_tab_offerings')));
        await tester.pumpAndSettle();
        expect(find.text('Altar of Offerings'), findsOneWidget);
        final scrollable = find.descendant(
          of: find.byType(ShopDialog),
          matching: find.byType(Scrollable),
        );
        final cbPlusBtn = find.byKey(
          const ValueKey('diamond_unlock_Crystal Ball+'),
        );
        await tester.scrollUntilVisible(
          cbPlusBtn,
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();

        final cbSpheres = tester
            .widgetList<ElementalEnergySphere>(
              find.descendant(
                of: cbPlusBtn,
                matching: find.byType(ElementalEnergySphere),
              ),
            )
            .toList();
        expect(cbSpheres.length, 5);
        for (final sphere in cbSpheres) {
          expect(sphere.isDark, isDark);
          expect(sphere.size, inInclusiveRange(13.0, 15.0));
        }

        final cbYCenters = {
          for (final move in HandMove.values)
            tester
                .getCenter(
                  find.descendant(
                    of: cbPlusBtn,
                    matching: find.byKey(
                      ValueKey('shop_cost_orb_${move.orbKey}'),
                    ),
                  ),
                )
                .dy
                .round(),
        };
        expect(cbYCenters.length, 1);

        // Also verify Show Markov Algorithm (5 orbs + real money button) fits cleanly
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        final algoBtn = find.byKey(
          const ValueKey(
            'diamond_unlock_${BillingService.productShowAlgorithm}',
          ),
        );
        await tester.scrollUntilVisible(algoBtn, 160, scrollable: scrollable);
        await tester.pumpAndSettle();
        final algoYCenters = {
          for (final move in HandMove.values)
            tester
                .getCenter(
                  find.descendant(
                    of: algoBtn,
                    matching: find.byKey(
                      ValueKey('shop_cost_orb_${move.orbKey}'),
                    ),
                  ),
                )
                .dy
                .round(),
        };
        expect(algoYCenters.length, 1);

        expect(tester.takeException(), isNull);
      },
    );
  }
}
