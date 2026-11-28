import 'dart:async';
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

class _OfflineOffertoryDialogState extends State<OfflineOffertoryDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  Timer? _liveTickTimer;
  int _elapsedOpenSeconds = 0;
  bool _isProcessingAd = false;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _syncLiveTickTimer();
    _syncShimmerAnimation();
  }

  @override
  void didUpdateWidget(covariant OfflineOffertoryDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLiveTickTimer();
    _syncShimmerAnimation();
  }

  @override
  void dispose() {
    _liveTickTimer?.cancel();
    _liveTickTimer = null;
    _shimmerController.dispose();
    super.dispose();
  }

  bool get _isAtStorageCap =>
      controller.isOffertoryFull ||
      widget.offlineDuration + Duration(seconds: _elapsedOpenSeconds) >=
          controller.offertoryMaxCapDuration;

  void _syncLiveTickTimer() {
    if (_isAtStorageCap) {
      _liveTickTimer?.cancel();
      _liveTickTimer = null;
      return;
    }
    _liveTickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedOpenSeconds++;
      });
      if (_isAtStorageCap) {
        _liveTickTimer?.cancel();
        _liveTickTimer = null;
      }
    });
  }

  void _syncShimmerAnimation() {
    final isRemoveAds = controller.isRemoveAdsActive;
    final isFreeDoubleReady = controller.isOffertoryFreeDoubleReady();
    final showDoubleButton = !isRemoveAds || isFreeDoubleReady;
    final doubleEnabled = isRemoveAds
        ? controller.canClaimRemoveAdsDoubleCollectOffertory()
        : controller.canWatchAdDoubleCollectOffertory();

    final shouldAnimate =
        controller.animationsEnabled &&
        showDoubleButton &&
        doubleEnabled &&
        !_isProcessingAd;

    if (shouldAnimate) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    } else {
      if (_shimmerController.isAnimating || _shimmerController.value != 0.0) {
        _shimmerController.stop();
        _shimmerController.value = 0.0;
      }
    }
  }

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
    _syncShimmerAnimation();
    int earned = 0;
    try {
      earned = await controller.watchAdToDoubleCollectOffertory();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAd = false;
        });
        _syncShimmerAnimation();
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
      builder: (context, _) {
        _syncLiveTickTimer();
        _syncShimmerAnimation();
        return _buildDialog(context);
      },
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
    final doubleEnabled = isRemoveAds ? canRemoveAds2x : canWatchAd2x;

    final capDuration = controller.offertoryMaxCapDuration;
    final liveOfflineDuration =
        widget.offlineDuration + Duration(seconds: _elapsedOpenSeconds);
    final reachedCap =
        liveOfflineDuration >= capDuration || controller.isOffertoryFull;
    final displayDuration =
        reachedCap && liveOfflineDuration >= capDuration
        ? capDuration
        : liveOfflineDuration;
    final formattedDuration = OfflineOffertoryDialog.formatOfflineDuration(
      displayDuration,
    );

    final fillProgress = reachedCap
        ? 1.0
        : controller.offertoryFillProgress().clamp(0.0, 1.0);
    final fillPercent = reachedCap
        ? 100
        : (fillProgress * 100).round().clamp(0, 99);

    final progressLabel = reachedCap
        ? loc
              .t(
                'offertory_offline_storage_full',
                fallback: 'Offline for {time} • 100% FULL (Paused)',
              )
              .replaceAll('{time}', formattedDuration)
        : loc
              .t(
                'offertory_offline_duration_progress',
                fallback: 'Offline for {time} • {percent}% Full',
              )
              .replaceAll('{time}', formattedDuration)
              .replaceAll('{percent}', '$fillPercent');

    final dialogBg = isDark
        ? palette.dialogSurface
        : OfflineOffertoryDialog._lightParchmentSurface;
    final innerCardBg = isDark
        ? const Color(0xFF1C202B)
        : const Color(0xFFFAF6EE);

    final formattedStored = OfflineOffertoryDialog.formatGroupedInt(
      storedOrbs,
      loc,
    );
    final formattedDoubled = OfflineOffertoryDialog.formatGroupedInt(
      doubledOrbs,
      loc,
    );

    final heroTitle = isRemoveAds
        ? loc.t(
            'offertory_sanctuary_grace_2x_hero_title',
            fallback: 'Sanctuary Grace • 2x Collect',
          )
        : loc.t(
            'offertory_watch_ad_2x_hero_title',
            fallback: 'Watch Ad • 2x Collect',
          );
    final heroSubline = loc
        .t(
          'offertory_offline_2x_subline',
          fallback: '+{total} per element (+{bonus} bonus)',
        )
        .replaceAll('{total}', formattedDoubled)
        .replaceAll('{bonus}', formattedStored);
    final collectEachLabel = loc
        .t(
          'offertory_collect_each_btn',
          fallback: 'Collect (+{amount} each)',
        )
        .replaceAll('{amount}', formattedStored);

    return Dialog(
      key: const ValueKey('offline_offertory_dialog'),
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: palette.amberBorder.withValues(alpha: isDark ? 0.65 : 0.80),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Sacred Offertory Icon + Welcome Back title + Close (X)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: palette.amberBorder.withValues(
                        alpha: isDark ? 0.16 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.50),
                      ),
                    ),
                    child: const OffertoryVaultIcon(size: 28),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: palette.primaryText,
                          ),
                        ),
                        Text(
                          loc.t(
                            'offertory_harvest_subtitle',
                            fallback: 'Offertory Harvest',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 8-Hour Capacity Progress Bar & Urgency Pill
              Container(
                key: const ValueKey('offline_offertory_duration_pill'),
                height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF281F0C)
                      : const Color(0xFFDCC99E),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: reachedCap
                        ? OfflineOffertoryDialog._goldFill
                        : palette.amberBorder.withValues(alpha: 0.72),
                    width: reachedCap ? 1.5 : 1.2,
                  ),
                  boxShadow: reachedCap
                      ? [
                          BoxShadow(
                            color: OfflineOffertoryDialog._goldFill.withValues(
                              alpha: isDark ? 0.36 : 0.28,
                            ),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FractionallySizedBox(
                        key: const ValueKey('offline_offertory_fill_progress'),
                        alignment: Alignment.centerLeft,
                        widthFactor: fillProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: reachedCap
                                  ? const [
                                      Color(0xFFFFA000),
                                      Color(0xFFFFE082),
                                    ]
                                  : const [
                                      Color(0xFFD97B12),
                                      OfflineOffertoryDialog._goldFill,
                                    ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                reachedCap
                                    ? Icons.workspace_premium_rounded
                                    : Icons.hourglass_bottom_rounded,
                                size: 15,
                                color: reachedCap
                                    ? OfflineOffertoryDialog._goldDarkInk
                                    : (isDark
                                          ? Colors.white
                                          : OfflineOffertoryDialog._goldDarkInk),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    progressLabel,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: reachedCap
                                          ? OfflineOffertoryDialog._goldDarkInk
                                          : (isDark
                                                ? Colors.white
                                                : OfflineOffertoryDialog
                                                      ._goldDarkInk),
                                      shadows: !reachedCap && isDark
                                          ? const [
                                              Shadow(
                                                color: Colors.black87,
                                                blurRadius: 4,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Single-Row 3D Collectible Elemental Orbs Card
              Container(
                key: const ValueKey('offline_offertory_orbs_card'),
                padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
                decoration: BoxDecoration(
                  color: innerCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: palette.amberBorder.withValues(alpha: 0.38),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loc.t(
                        'offertory_offline_accumulated_label',
                        fallback: 'Accumulated Elemental Orbs',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      key: const ValueKey('offline_offertory_orbs_row'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final move in activeMoves)
                          Expanded(
                            child: _buildSingleRowOrbColumn(
                              move: move,
                              formattedAmount: formattedStored,
                              palette: palette,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Primary Hero CTA: Glowing Gold Gradient 2x Collect Button with Shimmer
              if (showDoubleButton) ...[
                _buildHeroDoubleButton(
                  palette: palette,
                  isDark: isDark,
                  isRemoveAds: isRemoveAds,
                  enabled: doubleEnabled,
                  title: heroTitle,
                  subline: heroSubline,
                ),
                const SizedBox(height: 8),
              ],

              // Secondary Action Button: Collect (+X each)
              ElevatedButton.icon(
                key: const ValueKey('offline_offertory_collect_1x_button'),
                onPressed: canCollect1x ? _handleCollect1x : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF1E2430)
                      : const Color(0xFFFAF6EE),
                  foregroundColor: isDark
                      ? const Color(0xFFFFE082)
                      : palette.amberText,
                  disabledBackgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : palette.sandCardSurface,
                  disabledForegroundColor: palette.mutedText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: canCollect1x
                          ? palette.amberBorder
                          : palette.sandCardBorder,
                      width: 1.5,
                    ),
                  ),
                ),
                icon: const Icon(Icons.download_done_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    collectEachLabel,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // Compact AdMob Rewarded Video Disclosure Footer
              if (showDoubleButton && !isRemoveAds) ...[
                const SizedBox(height: 7),
                Row(
                  key: const ValueKey('offline_offertory_ad_disclosure'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.ondemand_video_rounded,
                        size: 12.5,
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
                          fontSize: 10,
                          height: 1.2,
                          color: palette.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDoubleButton({
    required AppPalette palette,
    required bool isDark,
    required bool isRemoveAds,
    required bool enabled,
    required String title,
    required String subline,
  }) {
    final titleColor = enabled
        ? OfflineOffertoryDialog._goldDarkInk
        : palette.mutedText;
    final subColor = enabled
        ? OfflineOffertoryDialog._goldDarkInk
        : palette.mutedText;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: OfflineOffertoryDialog._goldFill.withValues(
                    alpha: isDark ? 0.34 : 0.28,
                  ),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        key: const ValueKey('offline_offertory_collect_2x_button'),
        onPressed: enabled ? _handleCollect2x : null,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: enabled
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFE57F),
                            OfflineOffertoryDialog._goldFill,
                            Color(0xFFFFB300),
                          ],
                        )
                      : null,
                  color: enabled
                      ? null
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : palette.sandCardSurface),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: enabled
                        ? const Color(0xFFFFF3C4)
                        : palette.sandCardBorder,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isRemoveAds
                              ? Icons.auto_awesome_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 18,
                          color: titleColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3.5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: enabled
                            ? OfflineOffertoryDialog._goldDarkInk.withValues(
                                alpha: 0.12,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          subline,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: subColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled && controller.animationsEnabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        // Sweep a diagonal sheen across 42% of the cycle, resting cleanly in between.
                        final t = _shimmerController.value;
                        if (t > 0.42) return const SizedBox.shrink();
                        final sweep = (t / 0.42) * 2.6 - 1.3;
                        return FractionalTranslation(
                          translation: Offset(sweep, 0),
                          child: Transform.rotate(
                            angle: -0.35,
                            child: Container(
                              width: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.34),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleRowOrbColumn({
    required HandMove move,
    required String formattedAmount,
    required AppPalette palette,
  }) {
    return Column(
      key: ValueKey('offline_offertory_orb_${move.orbKey}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ElementalEnergySphere(
          key: ValueKey('offline_offertory_sphere_${move.orbKey}'),
          size: 34,
          primaryColor: move.elementalPrimaryColor,
          secondaryColor: move.elementalSecondaryColor,
          isDark: palette.isDark,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '+$formattedAmount',
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: palette.elementalText(move),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
