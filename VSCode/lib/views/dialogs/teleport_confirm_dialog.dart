import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/rpg_teleport_portal_icon.dart';

class TeleportConfirmResult {
  final bool confirmed;
  final bool dontShowAgain;

  const TeleportConfirmResult({
    required this.confirmed,
    required this.dontShowAgain,
  });
}

/// Themed RPG confirmation dialog shown before opening the arcane teleport
/// portal to return from battle to [WorldMapScreen] and advance `+1 Week`.
class TeleportConfirmDialog extends StatefulWidget {
  final GameController controller;

  const TeleportConfirmDialog({
    super.key,
    required this.controller,
  });

  /// Shows [TeleportConfirmDialog] and returns `true` if the player confirmed
  /// teleportation. Persists the `"Don't show this again"` preference ONLY when
  /// the player taps **Teleport** with the checkbox checked.
  static Future<bool> show(
    BuildContext context, {
    required GameController controller,
  }) async {
    final result = await showDialog<TeleportConfirmResult>(
      context: context,
      builder: (_) => TeleportConfirmDialog(controller: controller),
    );
    if (result == null || !result.confirmed) {
      return false;
    }
    if (result.dontShowAgain) {
      controller.setConfirmBattleTeleport(false);
    }
    return true;
  }

  @override
  State<TeleportConfirmDialog> createState() => _TeleportConfirmDialogState();
}

class _TeleportConfirmDialogState extends State<TeleportConfirmDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final loc = widget.controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;
    final isTempleMaster = widget.controller.isTempleMasterBoss;
    final isBabyMage = widget.controller.isBabyMageBoss;
    final isMoralWarning = isTempleMaster || isBabyMage;

    final Color accentColor = isTempleMaster
        ? const Color(0xFFFFB74D)
        : (isBabyMage
            ? const Color(0xFFBA68C8)
            : (isDark ? const Color(0xFF00E5FF) : palette.amberBorder));

    final Color weekBadgeBg = isDark
        ? (isMoralWarning ? const Color(0xFF22161E) : const Color(0xFF1C202B))
        : palette.dialogCardSurface;
    final Color weekBadgeBorder = isMoralWarning
        ? Colors.redAccent.withValues(alpha: 0.55)
        : (isDark
            ? const Color(0xFF00E5FF).withValues(alpha: 0.45)
            : palette.amberBorder.withValues(alpha: 0.75));
    final Color orbsCardBg = isDark
        ? const Color(0xFF16241D)
        : const Color(0xFFEAF3E8);
    final Color orbsCardBorder = isDark
        ? Colors.greenAccent.withValues(alpha: 0.35)
        : palette.successText.withValues(alpha: 0.42);

    final String titleText;
    final String bodyText;
    final String badgeText;
    final String confirmLabel;

    if (isTempleMaster) {
      titleText = loc.t(
        'teleport_temple_master_title',
        fallback: 'Abandon the Princess to Sacrifice?',
      );
      bodyText = loc.t(
        'teleport_temple_master_body',
        fallback:
            'Fleeing the Sacred Temple now abandons Princess Aria to the Temple High Master, who will immediately carry out the sacrifice at the altar!\n\nConfirming will end your run and trigger Ending: The Sacred Sacrifice.',
      );
      badgeText = loc.t(
        'teleport_temple_master_badge',
        fallback: 'Triggers Ending: The Sacred Sacrifice',
      );
      confirmLabel = loc.t(
        'teleport_temple_master_confirm_action',
        fallback: 'Flee & Abandon Her',
      );
    } else if (isBabyMage) {
      titleText = loc.t(
        'teleport_baby_mage_title',
        fallback: 'Flee & Abandon the Kingdom?',
      );
      bodyText = loc.t(
        'teleport_baby_mage_body',
        fallback:
            'Fleeing the Sacred Temple leaves the awakened Baby Mage Robot completely unchecked to destroy the Royal Capital!\n\nConfirming will end your run and trigger Ending: The Deserter.',
      );
      badgeText = loc.t(
        'teleport_baby_mage_badge',
        fallback: 'Triggers Ending: The Deserter',
      );
      confirmLabel = loc.t(
        'teleport_baby_mage_confirm_action',
        fallback: 'Flee as a Deserter',
      );
    } else {
      titleText = loc.t(
        'teleport_confirm_title',
        fallback: 'Teleport to World Map?',
      );
      bodyText = loc.t(
        'teleport_confirm_body',
        fallback:
            'Opening an arcane portal will return you to the World Map and advance the campaign by +1 Week.\n\nAll Elemental Orbs collected during this battle will be kept!',
      );
      badgeText = loc.t(
        'teleport_confirm_week_badge',
        fallback: '+1 Week will pass',
      );
      confirmLabel = loc.t('teleport_confirm_action', fallback: 'Teleport');
    }

    return Dialog(
      key: const ValueKey('teleport_confirm_dialog'),
      backgroundColor: isDark ? const Color(0xFF14161D) : palette.dialogSurface,
      surfaceTintColor: isDark ? null : Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isMoralWarning
              ? Colors.redAccent.withValues(alpha: 0.65)
              : accentColor.withValues(alpha: isDark ? 0.35 : 0.65),
          width: 1.4,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Arcane Portal Icon & Title
              Row(
                children: [
                  const RpgTeleportPortalIcon(size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titleText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isMoralWarning
                            ? (isDark
                                ? Colors.red.shade200
                                : const Color(0xFF8E1B1B))
                            : palette.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 20, color: palette.divider),

              // Main warning & reassurance body
              Container(
                key: const ValueKey('teleport_confirm_message_card'),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: weekBadgeBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: weekBadgeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bodyText,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.42,
                        color: palette.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Highlight pill
                    Row(
                      children: [
                        Icon(
                          isMoralWarning
                              ? Icons.warning_amber_rounded
                              : Icons.calendar_today_rounded,
                          size: 15,
                          color: isMoralWarning
                              ? Colors.redAccent
                              : (isDark
                                  ? const Color(0xFF00E5FF)
                                  : palette.amberIcon),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: isMoralWarning
                                  ? Colors.redAccent
                                  : (isDark
                                      ? const Color(0xFF00E5FF)
                                      : palette.amberText),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (!isMoralWarning) ...[
                // Elemental Orbs preserved reassurance badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: orbsCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: orbsCardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: palette.successText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.t(
                            'teleport_confirm_orbs_kept',
                            fallback: 'Collected Elemental Orbs are kept',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: palette.successText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // "Don't show this again" interactive checkbox
                InkWell(
                  key: const ValueKey('teleport_dont_show_again_row'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _dontShowAgain = !_dontShowAgain;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            key: const ValueKey(
                              'teleport_dont_show_again_checkbox',
                            ),
                            value: _dontShowAgain,
                            activeColor: palette.amberIcon,
                            checkColor:
                                isDark ? const Color(0xFF14161D) : Colors.white,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.amber.withValues(alpha: 0.7)
                                  : palette.secondaryText,
                              width: 1.5,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              setState(() {
                                _dontShowAgain = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.t(
                              'teleport_dont_show_again',
                              fallback: "Don't show this again",
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: palette.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ] else
                const SizedBox(height: 6),

              // Footer Actions: Cancel & Teleport
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('teleport_cancel_button'),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.secondaryText,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      widget.controller.audio.playTapVibrate();
                      Navigator.of(context).pop(
                        const TeleportConfirmResult(
                          confirmed: false,
                          dontShowAgain: false,
                        ),
                      );
                    },
                    child: Text(
                      loc.t('teleport_cancel', fallback: 'Cancel'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton.icon(
                      key: const ValueKey('teleport_confirm_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMoralWarning
                            ? const Color(0xFFC62828)
                            : (isDark
                                ? const Color(0xFF00B0FF)
                                : palette.amberBorder),
                        foregroundColor: isMoralWarning
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF07131E)
                                : const Color(0xFF231F1A)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        widget.controller.audio.playTapVibrate();
                        Navigator.of(context).pop(
                          TeleportConfirmResult(
                            confirmed: true,
                            dontShowAgain: !isMoralWarning && _dontShowAgain,
                          ),
                        );
                      },
                      icon: Icon(
                        isMoralWarning
                            ? Icons.directions_run_rounded
                            : Icons.auto_fix_high_rounded,
                        size: 17,
                      ),
                      label: Text(
                        confirmLabel,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
