import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/elemental_energy_sphere.dart';
import '../widgets/temple_wing_icons.dart';

/// Welcome-Back harvest modal shown on [WorldMapScreen] when returning after
/// being offline for at least 2 minutes with accumulated Offertory orbs.
class OfflineOffertoryDialog extends StatefulWidget {
  final GameController controller;
  final Duration offlineDuration;

  const OfflineOffertoryDialog({
    super.key,
    required this.controller,
    required this.offlineDuration,
  });

  static const Color _goldFill = Color(0xFFFFD54F);
  static const Color _goldDarkInk = Color(0xFF231F1A);
  static const Color _lightParchmentSurface = Color(0xFFF5EFE2);

  /// Formats an offline away duration as `"3h 42m"` (or `"8h 00m"` at cap),
  /// and `"5m"` when under one hour.
  static String formatOfflineDuration(Duration duration) {
    final totalMinutes = duration.isNegative ? 0 : duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m';
  }

  static String formatGroupedInt(int value, LocalizationService loc) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    if (digits.length <= 3) return '$sign$digits';
    final sep = loc.currentLanguage == 'en' ? ',' : '.';
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final rem = digits.length - i;
      if (i > 0 && rem % 3 == 0) {
        buf.write(sep);
      }
      buf.write(digits[i]);
    }
    return '$sign${buf.toString()}';
  }

  static Future<bool?> show(
    BuildContext context, {
    required GameController controller,
    required Duration offlineDuration,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => OfflineOffertoryDialog(
        controller: controller,
        offlineDuration: offlineDuration,
      ),
    );
  }

  @override
  State<OfflineOffertoryDialog> createState() => _OfflineOffertoryDialogState();
}

class _OfflineOffertoryDialogState extends State<OfflineOffertoryDialog> {
  bool _isProcessingAd = false;

  GameController get controller => widget.controller;

  void _showCollectedSnackBar(int granted) {
    if (!mounted || granted <= 0) return;
    final loc = controller.localization;
    final msg = loc
        .t(
          'offertory_collected_msg',
          fallback: 'Collected +{amount} orbs per active element!',
        )
        .replaceAll(
          '{amount}',
          OfflineOffertoryDialog.formatGroupedInt(granted, loc),
        );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _handleDismiss() {
    controller.audio.playTapVibrate();
    controller.dismissOfflineOffertoryPrompt();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  void _handleCollect1x() {
    if (_isProcessingAd) return;
    final granted = controller.collectOffertoryOrbs(multiplier: 1);
    if (granted > 0 && mounted) {
      _showCollectedSnackBar(granted);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleCollect2x() async {
    if (_isProcessingAd) return;
    if (controller.isRemoveAdsActive) {
      final granted = controller.claimRemoveAdsDoubleCollectOffertory();
      if (granted > 0 && mounted) {
        _showCollectedSnackBar(granted);
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() {
      _isProcessingAd = true;
    });
    int earned = 0;
    try {
      earned = await controller.watchAdToDoubleCollectOffertory();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAd = false;
        });
      }
    }
    if (earned > 0 && mounted) {
      _showCollectedSnackBar(earned);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;

    final storedOrbs = controller.offertoryStoredOrbs();
    final doubledOrbs = storedOrbs * 2;
    final activeMoves = controller.offertoryActiveElements;
    final isRemoveAds = controller.isRemoveAdsActive;
    final isFreeDoubleReady = controller.isOffertoryFreeDoubleReady();
    final canCollect1x = storedOrbs >= 1 && !_isProcessingAd;
    final canWatchAd2x =
        controller.canWatchAdDoubleCollectOffertory() && !_isProcessingAd;
    final canRemoveAds2x =
        controller.canClaimRemoveAdsDoubleCollectOffertory() && !_isProcessingAd;
    final showDoubleButton = !isRemoveAds || isFreeDoubleReady;

    final reachedCap =
        widget.offlineDuration >= GameController.offertoryMaxCapDuration ||
        controller.isOffertoryFull;
    final displayDuration =
        widget.offlineDuration >= GameController.offertoryMaxCapDuration
            ? GameController.offertoryMaxCapDuration
            : widget.offlineDuration;
    final formattedDuration = OfflineOffertoryDialog.formatOfflineDuration(
      displayDuration,
    );
    final durationLabel = reachedCap
        ? loc
              .t(
                'offertory_offline_storage_full',
                fallback: 'Offline for {time} • Storage Full (100%)',
              )
              .replaceAll('{time}', formattedDuration)
        : loc
              .t(
                'offertory_offline_duration',
                fallback: 'Offline for {time}',
              )
              .replaceAll('{time}', formattedDuration);

    final dialogBg = isDark
        ? palette.dialogSurface
        : OfflineOffertoryDialog._lightParchmentSurface;
    final innerCardBg = isDark
        ? const Color(0xFF1C202B)
        : const Color(0xFFFAF6EE);

    return Dialog(
      key: const ValueKey('offline_offertory_dialog'),
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: palette.amberBorder.withValues(alpha: isDark ? 0.60 : 0.78),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Sacred Offertory Icon + Welcome Back title + Close (X)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: palette.amberBorder.withValues(
                        alpha: isDark ? 0.16 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.50),
                      ),
                    ),
                    child: const OffertoryVaultIcon(size: 32),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t(
                            'offertory_welcome_back_title',
                            fallback: 'Welcome Back!',
                          ),
                          key: const ValueKey('offline_offertory_title'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: palette.primaryText,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          loc.t(
                            'offertory_harvest_subtitle',
                            fallback: 'Offertory Harvest',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.amberText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('offline_offertory_close_button'),
                    onPressed: _handleDismiss,
                    tooltip: loc.t(
                      'offertory_offline_later_btn',
                      fallback: 'Later',
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      color: palette.secondaryText,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Offline Duration Pill (with warm golden Storage Full badge at 8h cap)
              Container(
                key: const ValueKey('offline_offertory_duration_pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: reachedCap
                      ? OfflineOffertoryDialog._goldFill
                      : palette.rewardedAdCardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: reachedCap
                        ? const Color(0xFFB8860B)
                        : palette.amberBorder.withValues(alpha: 0.55),
                    width: reachedCap ? 1.4 : 1.0,
                  ),
                  boxShadow: reachedCap
                      ? [
                          BoxShadow(
                            color: OfflineOffertoryDialog._goldFill.withValues(
                              alpha: 0.30,
                            ),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      reachedCap
                          ? Icons.workspace_premium_rounded
                          : Icons.hourglass_bottom_rounded,
                      size: 16,
                      color: reachedCap
                          ? OfflineOffertoryDialog._goldDarkInk
                          : palette.amberIcon,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        durationLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: reachedCap
                              ? OfflineOffertoryDialog._goldDarkInk
                              : palette.amberText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Accumulated Orbs Breakdown Card (3D Elemental Orbs + 2x Preview)
              Container(
                key: const ValueKey('offline_offertory_orbs_card'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: innerCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: palette.amberBorder.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loc.t(
                        'offertory_offline_accumulated_label',
                        fallback: 'Accumulated Elemental Orbs',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final move in activeMoves)
                          _buildOrbItem(
                            move: move,
                            amount: storedOrbs,
                            palette: palette,
                            loc: loc,
                          ),
                      ],
                    ),
                    if (showDoubleButton && storedOrbs >= 1) ...[
                      const SizedBox(height: 10),
                      Container(
                        key: const ValueKey('offline_offertory_2x_preview'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: palette.amberBorder.withValues(
                            alpha: isDark ? 0.14 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: palette.amberBorder.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: palette.amberIcon,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                loc
                                    .t(
                                      'offertory_offline_2x_preview',
                                      fallback:
                                          '2x Harvest: +{amount} per element',
                                    )
                                    .replaceAll(
                                      '{amount}',
                                      OfflineOffertoryDialog.formatGroupedInt(
                                        doubledOrbs,
                                        loc,
                                      ),
                                    ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: palette.amberText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Primary Action 1: Collect (1x)
              ElevatedButton.icon(
                key: const ValueKey('offline_offertory_collect_1x_button'),
                onPressed: canCollect1x ? _handleCollect1x : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OfflineOffertoryDialog._goldFill,
                  foregroundColor: OfflineOffertoryDialog._goldDarkInk,
                  disabledBackgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : palette.sandCardSurface,
                  disabledForegroundColor: palette.mutedText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.download_done_rounded, size: 18),
                label: Text(
                  loc.t('offertory_collect_btn', fallback: 'Collect'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // Primary Action 2: Watch Ad (2x Collect) OR Sanctuary Grace (2x)
              if (showDoubleButton) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  key: const ValueKey('offline_offertory_collect_2x_button'),
                  onPressed: isRemoveAds
                      ? (canRemoveAds2x ? _handleCollect2x : null)
                      : (canWatchAd2x ? _handleCollect2x : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF2B3447)
                        : const Color(0xFFE6D5B2),
                    foregroundColor: palette.amberText,
                    disabledBackgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : palette.sandCardSurface,
                    disabledForegroundColor: palette.mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: (isRemoveAds ? canRemoveAds2x : canWatchAd2x)
                            ? palette.amberBorder.withValues(alpha: 0.80)
                            : palette.sandCardBorder,
                        width: 1.2,
                      ),
                    ),
                  ),
                  icon: Icon(
                    isRemoveAds
                        ? Icons.auto_awesome_rounded
                        : Icons.play_circle_fill_rounded,
                    size: 18,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isRemoveAds
                          ? loc.t(
                              'offertory_sanctuary_grace_2x_btn',
                              fallback: '2x Collect (Sanctuary Grace)',
                            )
                          : loc.t(
                              'offertory_watch_ad_2x_btn',
                              fallback: 'Watch Ad (2x Collect)',
                            ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!isRemoveAds) ...[
                  const SizedBox(height: 6),
                  Row(
                    key: const ValueKey('offline_offertory_ad_disclosure'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.ondemand_video_rounded,
                          size: 13,
                          color: palette.amberIcon,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          loc.t(
                            'offertory_ad_disclosure',
                            fallback:
                                'Rewarded Video Ad: watch an ad to double (2x) your accumulated Offertory orbs upon collection.',
                          ),
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.25,
                            color: palette.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 4),

              // Secondary dismiss action: Later
              TextButton(
                key: const ValueKey('offline_offertory_later_button'),
                onPressed: _handleDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: palette.secondaryText,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  loc.t('offertory_offline_later_btn', fallback: 'Later'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrbItem({
    required HandMove move,
    required int amount,
    required AppPalette palette,
    required LocalizationService loc,
  }) {
    return Container(
      key: ValueKey('offline_offertory_orb_${move.orbKey}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.elementalCardBackground(move),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: palette.elementalCardBorder(move),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElementalEnergySphere(
            key: ValueKey('offline_offertory_sphere_${move.orbKey}'),
            size: 24,
            primaryColor: move.elementalPrimaryColor,
            secondaryColor: move.elementalSecondaryColor,
            isDark: palette.isDark,
          ),
          const SizedBox(width: 6),
          Text(
            '+${OfflineOffertoryDialog.formatGroupedInt(amount, loc)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: palette.elementalText(move),
            ),
          ),
        ],
      ),
    );
  }
}
