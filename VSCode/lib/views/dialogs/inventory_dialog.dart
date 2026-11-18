import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../services/play_games_service.dart';
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
                      color: const Color(0xFF14161D),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.45),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
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
                                        color: Colors.white,
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
                                        color: Colors.amber.withValues(
                                          alpha: 0.85,
                                        ),
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
                            color: Colors.amber.withValues(alpha: 0.22),
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
                              elementLabel: move.displayLabel(
                                elemental: true,
                                localization: loc,
                              ),
                              isCombatLocked: (move == HandMove.lizard ||
                                      move == HandMove.spock) &&
                                  !isNewHandsActive,
                              lockedStatusText: loc.t(
                                'inventory_locked_combat',
                                fallback:
                                    'Locked in combat (Enable New Hands)',
                              ),
                              activeStatusText: loc.t(
                                'inventory_active_combat',
                                fallback: 'Active in combat',
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
                          key: const ValueKey('inventory_open_shop_button'),
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
                            foregroundColor: Colors.black87,
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
                          foregroundColor: Colors.amber,
                          side: BorderSide(
                            color: Colors.amber.withValues(alpha: 0.55),
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
  final String elementLabel;
  final bool isCombatLocked;
  final String lockedStatusText;
  final String activeStatusText;

  const _ElementalOrbInventoryCard({
    required this.move,
    required this.count,
    required this.orbName,
    required this.elementLabel,
    required this.isCombatLocked,
    required this.lockedStatusText,
    required this.activeStatusText,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = move.elementalPrimaryColor;
    final secondaryColor = move.elementalSecondaryColor;

    return Container(
      key: ValueKey('inventory_orb_row_${move.orbKey}'),
      margin: const EdgeInsets.symmetric(vertical: 4.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C202B).withValues(
          alpha: isCombatLocked ? 0.65 : 0.92,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: isCombatLocked ? 0.28 : 0.52),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isCombatLocked ? 0.06 : 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Glowing Elemental Orb Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.2),
                radius: 0.88,
                colors: [
                  const Color(0xFF0A0C12),
                  Color.lerp(const Color(0xFF0E121B), secondaryColor, 0.45)!,
                  primaryColor.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.8),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 0.8,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                move.elementalIcon,
                size: 20,
                color: primaryColor,
                shadows: [
                  Shadow(
                    color: primaryColor.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Element Name & Combat Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        orbName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($elementLabel)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
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
                          ? Colors.amber.withValues(alpha: 0.75)
                          : Colors.greenAccent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isCombatLocked ? lockedStatusText : activeStatusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isCombatLocked
                              ? Colors.amber.withValues(alpha: 0.78)
                              : Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Current Orb Balance Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '$count',
              key: ValueKey('inventory_orb_count_${move.orbKey}'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
