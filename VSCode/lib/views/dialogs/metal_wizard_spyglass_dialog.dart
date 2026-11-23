import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/spyglass_lens_frame.dart';
import '../widgets/watchtower_forge_view.dart';
import 'full_screen_spyglass_view.dart';

/// Focused telescope/spyglass observation modal displaying the animated
/// underground forge of the Metal Wizard, with dynamic week-based lore.
class MetalWizardSpyglassDialog extends StatelessWidget {
  final GameController controller;

  const MetalWizardSpyglassDialog({super.key, required this.controller});

  static bool isForgeCoolingDown(GameController controller) {
    return controller.currentWeek >= GameController.maxCampaignWeeks ||
        controller.enemyStage >= 4;
  }

  static String resolveNarrativeCaption(GameController controller) {
    final loc = controller.localization;
    if (isForgeCoolingDown(controller)) {
      return loc.t(
        'observatory_wizard_caption_late',
        fallback:
            'The subterranean forge cools with dying embers as the war across the kingdom reaches its climax...',
      );
    }
    if (controller.currentWeek >= GameController.phase2StartWeek) {
      return loc.t(
        'observatory_wizard_caption_mid',
        fallback:
            'With the Robot Archmage now deployed, the Metal Wizard channels chaotic dark-metal energy in his forge to build an unpredictable Baby Mage Robot prototype for the final invasion...',
      );
    }
    return loc.t(
      'observatory_wizard_caption_early',
      fallback:
          'Deep beneath his lair, the Metal Wizard hammers heavy armor plates and clockwork gears to complete his superior Robot Archmage before Week 10...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final coolingDown = isForgeCoolingDown(controller);
    final caption = resolveNarrativeCaption(controller);

    return Dialog(
      key: const ValueKey('metal_wizard_spyglass_dialog'),
      backgroundColor: palette.isDark
          ? const Color(0xFF0D1119)
          : palette.dialogSurface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: palette.isDark
              ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
              : palette.amberBorder.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(
                        alpha: palette.isDark ? 0.16 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.55),
                      ),
                    ),
                    child: Icon(
                      Icons.precision_manufacturing_rounded,
                      size: 24,
                      color: palette.isDark
                          ? const Color(0xFFFFB300)
                          : const Color(0xFF8C5200),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.t(
                        'observatory_wizard_spyglass_title',
                        fallback: "Metal Wizard's Forge",
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: palette.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive Circular Brass-Framed Spyglass Viewport
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final maxH = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : maxW;
                    final diameter = math.min(maxW, math.min(maxH, 360.0));
                    return Center(
                      child: SizedBox(
                        width: diameter,
                        height: diameter,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  key: const ValueKey(
                                    'metal_wizard_spyglass_lens_tap',
                                  ),
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    controller.audio.playTapVibrate();
                                    Navigator.of(context).push(
                                      FullScreenSpyglassView.route(
                                        controller: controller,
                                        target: SpyglassTarget.metalWizard,
                                      ),
                                    );
                                  },
                                  child: SpyglassLensFrame(
                                    child: WatchtowerForgeView(
                                      isFullScreen: false,
                                      animationsEnabled:
                                          controller.animationsEnabled,
                                      isCoolingDown: coolingDown,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Subtle gold/dark translucent expand/zoom badge on bottom-right rim
                            Positioned(
                              right: diameter * 0.06,
                              bottom: diameter * 0.06,
                              child: IgnorePointer(
                                child: Container(
                                  key: const ValueKey(
                                    'metal_wizard_spyglass_expand_badge',
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0B1018)
                                        .withValues(alpha: 0.84),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFFE082)
                                          .withValues(alpha: 0.85),
                                      width: 1.3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.45),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in_rounded,
                                    size: 18,
                                    color: Color(0xFFFFE082),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Brief localized full-screen tap hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 13.5,
                    color: palette.isDark
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.85)
                        : palette.blueAccent,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      loc.t(
                        'observatory_spyglass_tap_hint',
                        fallback: 'Tap lens to inspect full screen',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: palette.isDark
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.90)
                            : palette.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Bordered RPG lore box updating dynamically by currentWeek
              Container(
                key: const ValueKey('metal_wizard_spyglass_lore_box'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? const Color(0xFF151C28)
                      : palette.rewardedAdCardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.isDark
                        ? const Color(0xFFFFB300).withValues(alpha: 0.45)
                        : palette.amberBorder.withValues(alpha: 0.75),
                    width: 1.1,
                  ),
                ),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                    color: palette.isDark
                        ? const Color(0xFFFFECB3).withValues(alpha: 0.92)
                        : palette.primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Clean Close Button at bottom
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('metal_wizard_spyglass_close_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.isDark
                        ? const Color(0xFFFFE082)
                        : palette.amberText,
                    side: BorderSide(
                      color: palette.isDark
                          ? const Color(0xFFFFB300).withValues(alpha: 0.65)
                          : palette.amberBorder,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    controller.audio.playTapVibrate();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    loc.t('observatory_spyglass_close_btn', fallback: 'Close'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
