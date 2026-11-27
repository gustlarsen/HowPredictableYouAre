import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../services/play_games_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/elemental_energy_sphere.dart';
import '../widgets/rpg_backpack_icon.dart';
import 'shop_dialog.dart';

class InventoryDialog extends StatefulWidget {
  final GameController controller;

  const InventoryDialog({super.key, required this.controller});

  @override
  State<InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<InventoryDialog>
    with TickerProviderStateMixin {
  static const double _backpackSize = 86.0;
  static const double _topOverhang = 24.0;

  late final AnimationController _openController;
  late final Animation<double> _openCurve;
  late final Animation<double> _bounceCurve;
  late final AnimationController _glowController;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _openCurve = CurvedAnimation(
      parent: _openController,
      curve: Curves.easeOutCubic,
    );
    _bounceCurve = CurvedAnimation(
      parent: _openController,
      curve: Curves.easeOutBack,
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _syncAnimations(fromStart: true);
    controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _syncAnimations(fromStart: false);
  }

  void _syncAnimations({required bool fromStart}) {
    if (controller.animationsEnabled) {
      if (fromStart) {
        _openController.forward(from: 0.0);
      }
      if (!_glowController.isAnimating) {
        _glowController.repeat();
      }
    } else {
      _openController.stop();
      _openController.value = 1.0;
      _glowController.stop();
      _glowController.value = 0.25;
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _openController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleBackpackIconTap(BuildContext context) {
    final granted = controller.registerBackpackQaTap();
    if (granted && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(PlayGamesService.qaBonusSnackBarMessage),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final loc = controller.localization;
        final theme = Theme.of(context);
        final palette = AppPalette.of(context);
        final isNewHandsActive = controller.showNewHands;
        final ownedOrbs = {
          for (final move in HandMove.values)
            if (controller.orbsFor(move) > 0) move,
        };

        return Dialog(
          key: const ValueKey('inventory_dialog'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18.0,
            vertical: 20.0,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Dialog Card Body (offset downward so open backpack overlaps top-left)
                Padding(
                  padding: const EdgeInsets.only(top: _topOverhang),
                  child: Container(
                    key: const ValueKey('inventory_dialog_card'),
                    decoration: BoxDecoration(
                      color: palette.dialogSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: palette.amberBorder.withValues(
                          alpha: palette.isDark ? 0.45 : 0.55,
                        ),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: palette.isDark ? 0.55 : 0.22,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        18.0,
                        16.0,
                        18.0,
                        14.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header text positioned to the right of the overlapping backpack
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 54),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 88.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.t(
                                        'inventory_title',
                                        fallback: "Cleric's Backpack",
                                      ),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: palette.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      loc.t(
                                        'inventory_subtitle',
                                        fallback:
                                            'Elemental Energy Orbs Inventory',
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: palette.isDark
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                        color: palette.amberSubtitle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: palette.divider,
                          ),
                          const SizedBox(height: 12),

                          // 5 Elemental Orb Cards
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final move in HandMove.values)
                                    _ElementalOrbInventoryCard(
                                      move: move,
                                      count: controller.orbsFor(move),
                                      orbName: move.elementalOrbName(loc),
                                      isCombatLocked: (move == HandMove.lizard ||
                                              move == HandMove.spock) &&
                                          !isNewHandsActive,
                                      lockedStatusText: loc.t(
                                        'inventory_locked_status',
                                        fallback: 'Locked',
                                      ),
                                      lockedRequirementText: loc.t(
                                        'inventory_locked_requirement',
                                        fallback: '(Learn Earth & Metal)',
                                      ),
                                      activeStatusText: loc.t(
                                        'inventory_active_combat',
                                        fallback: 'Active',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          // Footer Actions: Open Shop / Altar & Close
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  key: const ValueKey(
                                    'inventory_open_shop_button',
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    showDialog(
                                      context: context,
                                      builder: (_) =>
                                          ShopDialog(controller: controller),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: const Color(0xFF231F1A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 17,
                                  ),
                                  label: Text(
                                    loc.t(
                                      'inventory_open_shop',
                                      fallback: 'Open Shop / Altar',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                key: const ValueKey('inventory_close_button'),
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.amberText,
                                  side: BorderSide(
                                    color: palette.amberBorder.withValues(
                                      alpha: palette.isDark ? 0.55 : 0.70,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  loc.t('string36', fallback: 'Close'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Overlapping Open Backpack Illustration at Top-Left Corner (No Square Box)
                Positioned(
                  top: 0,
                  left: 10,
                  child: GestureDetector(
                    key: const ValueKey('inventory_header_backpack_icon'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleBackpackIconTap(context),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _openController,
                        _glowController,
                      ]),
                      builder: (context, _) {
                        final animationsEnabled = controller.animationsEnabled;
                        final openProgress = animationsEnabled
                            ? _openCurve.value.clamp(0.0, 1.0)
                            : 1.0;
                        final bounceScale = animationsEnabled
                            ? 0.80 + 0.20 * _bounceCurve.value
                            : 1.0;
                        final ambientGlowPhase =
                            animationsEnabled ? _glowController.value : 0.25;

                        return Transform.scale(
                          scale: bounceScale,
                          alignment: Alignment.bottomCenter,
                          child: RpgBackpackIcon(
                            size: _backpackSize,
                            isOpen: true,
                            openProgress: openProgress,
                            ambientGlowPhase: ambientGlowPhase,
                            ownedOrbs: ownedOrbs,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ElementalOrbInventoryCard extends StatelessWidget {
  final HandMove move;
  final int count;
  final String orbName;
  final bool isCombatLocked;
  final String lockedStatusText;
  final String lockedRequirementText;
  final String activeStatusText;

  const _ElementalOrbInventoryCard({
    required this.move,
    required this.count,
    required this.orbName,
    required this.isCombatLocked,
    required this.lockedStatusText,
    required this.lockedRequirementText,
    required this.activeStatusText,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primaryColor = move.elementalPrimaryColor;
    final secondaryColor = move.elementalSecondaryColor;
    final textElementColor = palette.elementalText(move);
    final lockedLineColor = palette.isDark
        ? Colors.amber.withValues(alpha: 0.78)
        : palette.amberText;
    final lockedRequirementColor = palette.isDark
        ? Colors.amber.withValues(alpha: 0.68)
        : palette.amberText.withValues(alpha: 0.82);

    return Container(
      key: ValueKey('inventory_orb_row_${move.orbKey}'),
      margin: const EdgeInsets.symmetric(vertical: 4.5),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isCombatLocked ? 8.5 : 10,
      ),
      decoration: BoxDecoration(
        color: palette.elementalCardBackground(move, locked: isCombatLocked),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: palette.elementalCardBorder(move, locked: isCombatLocked),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: textElementColor.withValues(
              alpha: palette.isDark
                  ? (isCombatLocked ? 0.06 : 0.14)
                  : (isCombatLocked ? 0.04 : 0.10),
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Glowing 3D Translucent Elemental Energy Sphere (no combat symbols)
          ElementalEnergySphere(
            key: ValueKey('inventory_orb_sphere_${move.orbKey}'),
            size: 38,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            isLocked: isCombatLocked,
            isDark: palette.isDark,
          ),
          const SizedBox(width: 12),

          // Element Orb Name & Simplified Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orbName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textElementColor,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      isCombatLocked
                          ? Icons.lock_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 12,
                      color: isCombatLocked
                          ? (palette.isDark
                                ? Colors.amber.withValues(alpha: 0.75)
                                : palette.amberText)
                          : (palette.isDark
                                ? Colors.greenAccent.withValues(alpha: 0.8)
                                : palette.successText),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isCombatLocked ? lockedStatusText : activeStatusText,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: palette.isDark
                                ? FontWeight.normal
                                : FontWeight.w500,
                            color: isCombatLocked
                                ? lockedLineColor
                                : (palette.isDark
                                      ? Colors.white.withValues(alpha: 0.65)
                                      : palette.secondaryText),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isCombatLocked) ...[
                  const SizedBox(height: 1.5),
                  FittedBox(
                    key: ValueKey(
                      'inventory_orb_locked_requirement_fit_${move.orbKey}',
                    ),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      lockedRequirementText,
                      key: ValueKey(
                        'inventory_orb_locked_requirement_${move.orbKey}',
                      ),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: palette.isDark
                            ? FontWeight.normal
                            : FontWeight.w500,
                        color: lockedRequirementColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Current Orb Balance Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: textElementColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: textElementColor.withValues(
                  alpha: palette.isDark ? 0.4 : 0.5,
                ),
              ),
            ),
            child: Text(
              '$count',
              key: ValueKey('inventory_orb_count_${move.orbKey}'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: palette.isDark
                    ? Colors.white.withValues(alpha: 0.95)
                    : palette.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
