import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/sacred_blessing.dart';
import '../../services/ad_service.dart';
import '../../services/billing_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/elemental_energy_sphere.dart';
import '../widgets/temple_wing_icons.dart';
import 'story_dialog.dart';

/// Identifies the 5 wings inside the Sacred Temple ([ShopDialog] / [SacredTempleDialog]) hub.
enum TempleWing {
  consagration,
  offerings,
  transmute,
  adoration,
  prayer,
}

enum _TransmuteBatchOption {
  x1(1, 'alchemy_multiplier_1x'),
  x10(10, 'alchemy_multiplier_10x'),
  x100(100, 'alchemy_multiplier_100x'),
  max(null, 'alchemy_multiplier_max');

  final int? fixedMultiplier;
  final String keyName;

  const _TransmuteBatchOption(this.fixedMultiplier, this.keyName);

  String label(LocalizationService loc) {
    if (fixedMultiplier != null) {
      return '${fixedMultiplier}x';
    }
    return loc.t('castle_alchemy_max', fallback: 'MAX');
  }
}

/// Alias so callers can refer to the 5-tab Sacred Temple Hub as [SacredTempleDialog]
/// or [ShopDialog].
typedef SacredTempleDialog = ShopDialog;

class ShopDialog extends StatefulWidget {
  final GameController controller;
  final bool fromTemple;
  final TempleWing? initialWing;

  const ShopDialog({
    super.key,
    required this.controller,
    this.fromTemple = false,
    this.initialWing,
  });

  @override
  State<ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<ShopDialog> {
  static const Color _goldFill = Color(0xFFF5C22B);
  static const Color _goldDarkInk = Color(0xFF1E1B16);

  GameController get controller => widget.controller;

  late TempleWing _selectedWing;
  late HandMove _transmuteSource;
  late HandMove _transmuteTarget;
  _TransmuteBatchOption _selectedBatchOption = _TransmuteBatchOption.x1;
  String? _transmuteConfirmationText;
  Timer? _transmuteConfirmationTimer;
  Timer? _holdStartTimer;
  Timer? _holdRepeatTimer;

  HandMove _selectedBulkElement = HandMove.rock;

  bool _restoredDuringCurrentRequest = false;
  bool _errorDuringCurrentRequest = false;

  @override
  void initState() {
    super.initState();
    _selectedWing =
        widget.initialWing ??
        (widget.fromTemple ? TempleWing.consagration : TempleWing.offerings);
    _transmuteSource = HandMove.values.firstWhere(
      (m) => controller.orbsFor(m) >= 3,
      orElse: () => HandMove.rock,
    );
    _transmuteTarget = _transmuteSource == HandMove.paper
        ? HandMove.rock
        : HandMove.paper;
    controller.billingService.addEventListener(_onBillingEvent);
  }

  @override
  void dispose() {
    _stopHoldTransmute();
    _transmuteConfirmationTimer?.cancel();
    controller.billingService.removeEventListener(_onBillingEvent);
    super.dispose();
  }

  String _titleForProductId(String productId) {
    final loc = controller.localization;
    switch (productId) {
      case BillingService.productResetButton:
        return loc.t('string37', fallback: 'Reset Button');
      case BillingService.productPredictabilityScore:
        return loc.t('string38', fallback: 'Predictability Score');
      case BillingService.productRandomButton:
        return loc.t('string39', fallback: 'Random Move Button');
      case BillingService.productShowAlgorithm:
        return loc.t('string40', fallback: 'Show Markov Algorithm');
      case BillingService.productNewHands:
        return loc.t('string56', fallback: 'Unlock Earth & Metal');
      case BillingService.productYourPrediction:
        return loc.t('string41', fallback: 'Your Prediction Hint');
      case BillingService.productPcNextMove:
        return loc.t('string42', fallback: 'PC Next Move Reveal');
      case BillingService.productSuggestion:
        return loc.t('string43', fallback: 'Optimal Suggestion');
      case BillingService.productRemoveAds:
        return loc.t('string44', fallback: 'Remove Ads');
      case BillingService.productCrystalBall:
        return loc.t('string80', fallback: 'Crystal Ball');
      case BillingService.productConsumableSmall:
        return loc.t('temple_pack_small_title', fallback: 'Blessing Pouch');
      case BillingService.productConsumableMedium:
        return loc.t('temple_pack_medium_title', fallback: 'Sacred Reliquary');
      case BillingService.productConsumableLarge:
        return loc.t('temple_pack_large_title', fallback: 'Divine Abundance');
      case BillingService.productConsumableFire1500:
        return '+1,500 ${HandMove.rock.elementalOrbName(loc)}';
      case BillingService.productConsumableWater1500:
        return '+1,500 ${HandMove.paper.elementalOrbName(loc)}';
      case BillingService.productConsumableWood1500:
        return '+1,500 ${HandMove.scissors.elementalOrbName(loc)}';
      case BillingService.productConsumableEarth1500:
        return '+1,500 ${HandMove.lizard.elementalOrbName(loc)}';
      case BillingService.productConsumableMetal1500:
        return '+1,500 ${HandMove.spock.elementalOrbName(loc)}';
      default:
        return 'Item';
    }
  }

  void _onBillingEvent(BillingPurchaseEvent event) {
    if (!mounted) return;
    final title = _titleForProductId(event.productId);
    final isConsumable = BillingService.isConsumableProduct(event.productId);

    switch (event.type) {
      case BillingEventType.pending:
        break;
      case BillingEventType.purchased:
        _restoredDuringCurrentRequest = true;
        controller.audio.playWinVibrate();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                isConsumable
                    ? '$title: ${controller.localization.t('temple_pack_granted', fallback: 'Granted!')}'
                    : '$title: Unlocked!',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        if (!isConsumable) {
          final pendingStory = controller.consumePendingStory();
          if (pendingStory != null) {
            StoryDialog.show(
              context,
              chapter: pendingStory,
              controller: controller,
            );
          }
        }
        break;
      case BillingEventType.restored:
        _restoredDuringCurrentRequest = true;
        controller.audio.playWinVibrate();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('$title: Restored!'),
              duration: const Duration(seconds: 2),
            ),
          );
        break;
      case BillingEventType.canceled:
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(event.message ?? 'Purchase canceled.'),
              duration: const Duration(seconds: 2),
            ),
          );
        break;
      case BillingEventType.error:
        _errorDuringCurrentRequest = true;
        controller.audio.playVibrate();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(event.message ?? 'Purchase failed.'),
              duration: const Duration(seconds: 2),
            ),
          );
        break;
    }
  }

  Future<void> _handleRestorePurchases() async {
    _restoredDuringCurrentRequest = false;
    _errorDuringCurrentRequest = false;
    final ok = await controller.restorePurchases();
    if (!mounted) return;
    if (ok && !_restoredDuringCurrentRequest && !_errorDuringCurrentRequest) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Purchases restored.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => _buildDialog(context),
    );
  }

  void _handleUnlock(BuildContext context, String title, bool success) {
    final loc = controller.localization;
    if (success) {
      controller.audio.playWinVibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: Unlocked!'),
          duration: const Duration(seconds: 2),
        ),
      );
      final pendingStory = controller.consumePendingStory();
      if (pendingStory != null) {
        StoryDialog.show(
          context,
          chapter: pendingStory,
          controller: controller,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.t('string79', fallback: 'Not enough Elemental Orbs'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleToggle(BuildContext context, String title, bool enabled) {
    controller.audio.playTapVibrate();
    final loc = controller.localization;
    final statusText = enabled
        ? loc.t('string49', fallback: 'Enabled')
        : loc.t('string48', fallback: 'Disabled');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $statusText'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<bool> _confirmResetForNewHands(BuildContext context) async {
    final loc = controller.localization;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.t('string53', fallback: 'RESET')),
        content: const Text(
          'This will clear your scores and prediction history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.t('string53', fallback: 'RESET')),
          ),
        ],
      ),
    );
    return shouldReset == true;
  }

  void _handleNewHandsUnlock(BuildContext context) {
    final title = controller.localization.t(
      'string56',
      fallback: 'Unlock Earth & Metal',
    );
    final ok = controller.unlockNewHands();
    _handleUnlock(context, title, ok);
  }

  Future<void> _handleNewHandsToggle(BuildContext context, bool val) async {
    final title = controller.localization.t(
      'string56',
      fallback: 'Unlock Earth & Metal',
    );
    if (controller.hasGameStarted) {
      final confirmed = await _confirmResetForNewHands(context);
      if (!confirmed || !context.mounted) return;
    }
    controller.toggleShowNewHands(val);
    _handleToggle(context, title, val);
  }

  String _shortElementTitle(HandMove move, LocalizationService loc) {
    final raw = move.displayLabel(elemental: true, localization: loc).trim();
    if (raw.isEmpty) return move.elementalLabel;
    if (raw.length == 1) return raw.toUpperCase();
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  bool _isBatchOptionEnabled(_TransmuteBatchOption option, int sourceBalance) {
    final mult = option.fixedMultiplier;
    if (mult == null) {
      return sourceBalance >= 3;
    }
    if (mult == 1) {
      return true;
    }
    return sourceBalance >= 3 * mult;
  }

  void _stepDownFixedMultiplierIfNeeded() {
    final fixed = _selectedBatchOption.fixedMultiplier;
    if (fixed == null) return;
    final sourceBalance = controller.orbsFor(_transmuteSource);
    if (sourceBalance >= 3 * fixed) return;

    const descendingFixed = [
      _TransmuteBatchOption.x100,
      _TransmuteBatchOption.x10,
      _TransmuteBatchOption.x1,
    ];
    for (final candidate in descendingFixed) {
      final candidateMult = candidate.fixedMultiplier!;
      if (candidateMult == 1 || sourceBalance >= 3 * candidateMult) {
        _selectedBatchOption = candidate;
        return;
      }
    }
    _selectedBatchOption = _TransmuteBatchOption.x1;
  }

  void _showTransmuteConfirmation(String text) {
    _transmuteConfirmationTimer?.cancel();
    setState(() => _transmuteConfirmationText = text);
    _transmuteConfirmationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _transmuteConfirmationText = null);
    });
  }

  void _cycleTransmuteSource() {
    controller.audio.playTapVibrate();
    const moves = HandMove.values;
    final startIdx = moves.indexOf(_transmuteSource);
    for (int offset = 1; offset < moves.length; offset++) {
      final candidate = moves[(startIdx + offset) % moves.length];
      if (candidate != _transmuteTarget) {
        setState(() {
          _transmuteSource = candidate;
          _stepDownFixedMultiplierIfNeeded();
        });
        return;
      }
    }
  }

  void _cycleTransmuteTarget() {
    controller.audio.playTapVibrate();
    const moves = HandMove.values;
    final startIdx = moves.indexOf(_transmuteTarget);
    for (int offset = 1; offset < moves.length; offset++) {
      final candidate = moves[(startIdx + offset) % moves.length];
      if (candidate != _transmuteSource) {
        setState(() => _transmuteTarget = candidate);
        return;
      }
    }
  }

  int _currentExecuteBatches() {
    final sourceAvailable = controller.orbsFor(_transmuteSource);
    final maxBatches = sourceAvailable ~/ 3;
    return _selectedBatchOption.fixedMultiplier ?? maxBatches;
  }

  bool _canTransmuteNow() {
    final sourceAvailable = controller.orbsFor(_transmuteSource);
    final batches = _currentExecuteBatches();
    return _transmuteSource != _transmuteTarget &&
        batches >= 1 &&
        sourceAvailable >= 3 * batches;
  }

  bool _executeTransmute() {
    if (!mounted || !_canTransmuteNow()) {
      _stopHoldTransmute();
      return false;
    }
    final loc = controller.localization;
    final batches = _currentExecuteBatches();
    final srcTitle = _shortElementTitle(_transmuteSource, loc);
    final dstTitle = _shortElementTitle(_transmuteTarget, loc);
    final ok = controller.transmuteOrbs(
      _transmuteSource,
      _transmuteTarget,
      batches: batches,
    );
    if (ok && mounted) {
      setState(() {
        _stepDownFixedMultiplierIfNeeded();
      });
      _showTransmuteConfirmation(
        '-${3 * batches} $srcTitle ➔ +$batches $dstTitle',
      );
      if (!_canTransmuteNow()) {
        _stopHoldTransmute();
      }
    } else {
      _stopHoldTransmute();
    }
    return ok;
  }

  void _startHoldTransmute() {
    _stopHoldTransmute();
    if (!_canTransmuteNow()) return;
    _holdStartTimer = Timer(const Duration(milliseconds: 380), () {
      if (!mounted || !_canTransmuteNow()) return;
      _executeTransmute();
      _holdRepeatTimer = Timer.periodic(
        const Duration(milliseconds: 110),
        (_) {
          if (!mounted || !_canTransmuteNow()) {
            _stopHoldTransmute();
            return;
          }
          _executeTransmute();
        },
      );
    });
  }

  void _stopHoldTransmute() {
    _holdStartTimer?.cancel();
    _holdStartTimer = null;
    _holdRepeatTimer?.cancel();
    _holdRepeatTimer = null;
  }

  Widget _buildOrbSummaryBar(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      key: const ValueKey('shop_orb_summary_bar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.summaryBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.amberBorder.withValues(
            alpha: palette.isDark ? 0.32 : 0.45,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final move in HandMove.values)
            Row(
              key: ValueKey('shop_header_orb_${move.orbKey}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                ElementalEnergySphere(
                  key: ValueKey('shop_header_orb_sphere_${move.orbKey}'),
                  size: 17,
                  primaryColor: move.elementalPrimaryColor,
                  secondaryColor: move.elementalSecondaryColor,
                  isDark: palette.isDark,
                ),
                const SizedBox(width: 4),
                Text(
                  '${controller.orbsFor(move)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: palette.isDark
                        ? palette.elementalText(move)
                        : palette.primaryText,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final week = controller.currentWeek;
    final weekLabel = loc.t('map_week_label', fallback: 'Week');

    return Dialog(
      key: const ValueKey('sacred_temple_dialog'),
      backgroundColor: palette.dialogSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: palette.amberBorder.withValues(
            alpha: palette.isDark ? 0.45 : 0.65,
          ),
          width: 1.4,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sacred Temple Header (matching RoyalCastleDialog)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: palette.amberBorder.withValues(
                        alpha: palette.isDark ? 0.18 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.55),
                      ),
                    ),
                    child: const SacredTempleEmblemIcon(size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t(
                            'map_landmark_sacred_temple',
                            fallback: 'Sacred Temple',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: palette.primaryText,
                          ),
                        ),
                        Text(
                          loc.t(
                            'temple_hub_subtitle',
                            fallback: 'Sanctuary of Offerings & Blessings',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.2,
                            color: palette.amberSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.rewardedAdCardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.rewardedAdCardBorder),
                    ),
                    child: Text(
                      '$weekLabel $week / ${GameController.maxCampaignWeeks}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: palette.amberText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 5 Compact Vertical Navigation Tab Pills in a Single Row
              _buildTempleTabBar(context, palette, loc),
              const SizedBox(height: 8),

              // Persistent 5 Elemental Orbs Balance Bar across all 5 Wings
              _buildOrbSummaryBar(context),

              Divider(
                height: 14,
                color: palette.isDark ? null : palette.divider,
              ),

              // Active Temple Wing Content
              Expanded(
                child: _buildSelectedWing(context, palette, loc),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton.icon(
                      key: const ValueKey('shop_restore_purchases_button'),
                      style: palette.isDark
                          ? null
                          : TextButton.styleFrom(
                              foregroundColor: palette.amberText,
                            ),
                      onPressed: controller.billingService.isRestoring
                          ? null
                          : _handleRestorePurchases,
                      icon: controller.billingService.isRestoring
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_rounded, size: 16),
                      label: Text(
                        loc.t(
                          'temple_restore_purchases',
                          fallback: 'Restore Purchases',
                        ),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('shop_close_button'),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.amberText,
                      backgroundColor: palette.isDark
                          ? palette.amberBorder.withValues(alpha: 0.16)
                          : palette.rewardedAdCardSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: palette.amberBorder.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
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
    );
  }

  Widget _buildTempleTabBar(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final List<({
      TempleWing wing,
      ValueKey<String> key,
      Widget Function(bool isSelected) iconBuilder,
      String label,
    })> tabs = [
      (
        wing: TempleWing.consagration,
        key: const ValueKey('temple_tab_consagration'),
        iconBuilder: (isSelected) => ConsagrationChaliceIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('temple_tab_consagration', fallback: 'Consagration'),
      ),
      (
        wing: TempleWing.offerings,
        key: const ValueKey('temple_tab_offerings'),
        iconBuilder: (isSelected) => OfferingsAltarIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('temple_tab_offerings', fallback: 'Offerings'),
      ),
      (
        wing: TempleWing.transmute,
        key: const ValueKey('temple_tab_transmute'),
        iconBuilder: (isSelected) => HolyTransmuteIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('temple_tab_transmute', fallback: 'Transmute'),
      ),
      (
        wing: TempleWing.adoration,
        key: const ValueKey('temple_tab_adoration'),
        iconBuilder: (isSelected) => AdorationHarpIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('temple_tab_adoration', fallback: 'Adoration'),
      ),
      (
        wing: TempleWing.prayer,
        key: const ValueKey('temple_tab_prayer'),
        iconBuilder: (isSelected) => PrayerHandsIcon(
          size: 20,
          isOnGoldBackground: isSelected,
        ),
        label: loc.t('temple_tab_prayer', fallback: 'Prayer'),
      ),
    ];

    return Row(
      key: const ValueKey('sacred_temple_tab_bar'),
      children: [
        for (int i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _TempleCompactVerticalTabPill(
              key: tabs[i].key,
              iconBuilder: tabs[i].iconBuilder,
              label: tabs[i].label,
              selected: _selectedWing == tabs[i].wing,
              palette: palette,
              onTap: () {
                if (_selectedWing != TempleWing.transmute) {
                  _stopHoldTransmute();
                }
                controller.audio.playTapVibrate();
                setState(() => _selectedWing = tabs[i].wing);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    switch (_selectedWing) {
      case TempleWing.consagration:
        return _buildConsagrationWing(context, palette, loc);
      case TempleWing.offerings:
        return _buildOfferingsWing(context, palette, loc);
      case TempleWing.transmute:
        return _buildTransmuteWing(context, palette, loc);
      case TempleWing.adoration:
        return _buildAdorationWing(context, palette, loc);
      case TempleWing.prayer:
        return _buildPrayerWing(context, palette, loc);
    }
  }

  // ---------------------------------------------------------------------------
  // WING 1: CONSAGRATION ROOM (+1 Max HP & +1 Max Mana Pool via Orbs or Ad)
  // ---------------------------------------------------------------------------
  Widget _buildConsagrationWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final isRemoveAds = controller.isRemoveAdsActive;
    final remainingAds = controller.remainingWeeklyAdConsagrations;
    final canWatchAd = controller.canWatchAdConsagration;
    final adButtonLabel = remainingAds <= 0
        ? loc.t(
            'temple_consagration_weekly_limit_reached',
            fallback: 'Weekly Cap (3/3)',
          )
        : loc.t('temple_consagration_watch_ad_btn', fallback: 'Watch Ad: +1 Lv');

    return ListView(
      key: const ValueKey('temple_wing_consagration'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                loc.t(
                  'temple_wing_consagration_title',
                  fallback: 'Consagration Room',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: palette.primaryText,
                ),
              ),
            ),
            if (!isRemoveAds)
              Container(
                key: const ValueKey('consagration_weekly_ad_counter'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.rewardedAdCardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.amberBorder.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '$remainingAds / ${GameController.maxWeeklyAdConsagrations} ${loc.t('temple_consagration_weekly_left', fallback: 'Ad Lv/Wk')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: palette.amberText,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _InfiniteStatUpgradeTile(
          cardKey: const ValueKey('shop_upgrade_max_hp_card'),
          buttonKey: const ValueKey('shop_upgrade_max_hp_button'),
          adButtonKey: const ValueKey('consagration_hp_watch_ad_button'),
          iconWidget: const VitalityHeartIcon(size: 22),
          title: loc.t('upgrade_max_hp_title', fallback: '+1 Max HP'),
          subtitle: loc.t(
            'upgrade_max_hp_desc',
            fallback:
                "Permanently raises your Cleric's maximum HP by +1 for this campaign.",
          ),
          statusText:
              'Lv. ${controller.hpUpgradeLevel} • ${controller.playerMaxHp} → ${controller.playerMaxHp + 1} HP',
          actionLabel: loc.t('stat_upgrade_action_label', fallback: 'Upgrade'),
          cost: controller.nextMaxHpUpgradeCost,
          showAdButton: !isRemoveAds,
          adButtonLabel: adButtonLabel,
          canWatchAd: canWatchAd,
          onPurchase: () {
            final ok = controller.upgradeMaxHp();
            if (ok) {
              controller.audio.playWinVibrate();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      '${loc.t('upgrade_max_hp_title', fallback: '+1 Max HP')}: ${controller.playerMaxHp} HP (Lv. ${controller.hpUpgradeLevel})',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
            } else {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      loc.t('string79', fallback: 'Not enough Elemental Orbs'),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
            }
          },
          onWatchAd: () {
            controller.watchAdToUpgradeMaxHp(
              onUpgraded: () {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        '${loc.t('upgrade_max_hp_title', fallback: '+1 Max HP')}: ${controller.playerMaxHp} HP (Lv. ${controller.hpUpgradeLevel})',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              },
            );
          },
        ),
        _InfiniteStatUpgradeTile(
          cardKey: const ValueKey('shop_upgrade_max_mana_card'),
          buttonKey: const ValueKey('shop_upgrade_max_mana_button'),
          adButtonKey: const ValueKey('consagration_mana_watch_ad_button'),
          iconWidget: const ManaDropIcon(size: 22),
          title: loc.t('upgrade_max_mana_title', fallback: '+1 Max Mana Pool'),
          subtitle: loc.t(
            'upgrade_max_mana_desc',
            fallback:
                "Permanently expands your Cleric's maximum Mana Pool by +1 turn per battle.",
          ),
          statusText:
              'Lv. ${controller.manaUpgradeLevel} • ${controller.playerMaxMana} → ${controller.playerMaxMana + 1} ${loc.t('mana_label', fallback: 'Mana')}',
          actionLabel: loc.t('stat_upgrade_action_label', fallback: 'Upgrade'),
          cost: controller.nextMaxManaUpgradeCost,
          showAdButton: !isRemoveAds,
          adButtonLabel: adButtonLabel,
          canWatchAd: canWatchAd,
          onPurchase: () {
            final ok = controller.upgradeMaxMana();
            if (ok) {
              controller.audio.playWinVibrate();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      '${loc.t('upgrade_max_mana_title', fallback: '+1 Max Mana Pool')}: ${controller.playerMaxMana} ${loc.t('mana_label', fallback: 'Mana')} (Lv. ${controller.manaUpgradeLevel})',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
            } else {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      loc.t('string79', fallback: 'Not enough Elemental Orbs'),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
            }
          },
          onWatchAd: () {
            controller.watchAdToUpgradeMaxMana(
              onUpgraded: () {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        '${loc.t('upgrade_max_mana_title', fallback: '+1 Max Mana Pool')}: ${controller.playerMaxMana} ${loc.t('mana_label', fallback: 'Mana')} (Lv. ${controller.manaUpgradeLevel})',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              },
            );
          },
        ),
        if (!isRemoveAds) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('consagration_ad_disclosure_box'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: palette.rewardedAdCardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.rewardedAdCardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.ondemand_video_rounded,
                  size: 16,
                  color: palette.amberIcon,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t(
                      'temple_consagration_ad_disclosure',
                      fallback:
                          'Rewarded Video Ad: watch an ad to gain +1 permanent Max HP or Max Mana level (up to 3 per campaign week).',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: palette.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 2: ALTAR OF OFFERINGS (PERMANENT ARTIFACTS & POWER-UPS ONLY)
  // ---------------------------------------------------------------------------
  Widget _buildOfferingsWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final enabledStr = loc.t('string49', fallback: 'Enabled');
    final disabledStr = loc.t('string48', fallback: 'Disabled');

    return ListView(
      key: const ValueKey('temple_wing_offerings'),
      cacheExtent: 1000,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const SacredRelicIcon(size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.t('sacred_temple_altar_title', fallback: 'Altar of Offerings'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: palette.primaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string38', fallback: 'Predictability Score'),
          subtitle: loc.t(
            'predictability_score_desc',
            fallback:
                'Unlocks Match Scoreboard (Your Score, PC Score, Total) & Predictability Gauge %',
          ),
          cost: GameController.costPredictability,
          productId: BillingService.productPredictabilityScore,
          isUnlocked: controller.unlockedPredictability,
          isActive: controller.showPredictability,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockPredictability();
            _handleUnlock(
              context,
              loc.t('string38', fallback: 'Predictability Score'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowPredictability(val);
            _handleToggle(
              context,
              loc.t('string38', fallback: 'Predictability Score'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string37', fallback: 'Reset Button'),
          subtitle: loc.t(
            'reset_button_desc',
            fallback:
                'Adds a Reset button to clear the current match and Markov matrix anytime',
          ),
          cost: GameController.costReset,
          productId: BillingService.productResetButton,
          isUnlocked: controller.unlockedReset,
          isActive: controller.showReset,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockReset();
            _handleUnlock(
              context,
              loc.t('string37', fallback: 'Reset Button'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowReset(val);
            _handleToggle(
              context,
              loc.t('string37', fallback: 'Reset Button'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string56', fallback: 'Unlock Earth & Metal'),
          subtitle: loc.t(
            'new_hands_desc',
            fallback:
                'Unlocks Earth & Metal in your move deck and deals bonus damage to the Phase 2 boss. Earn Earth & Metal orbs by defeating them in Phase 2.',
          ),
          cost: GameController.costNewHands,
          productId: BillingService.productNewHands,
          isUnlocked: controller.unlockedNewHands,
          isActive: controller.showNewHands,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () => _handleNewHandsUnlock(context),
          onToggle: (val) => _handleNewHandsToggle(context, val),
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string39', fallback: 'Random Move Button'),
          subtitle: loc.t(
            'random_button_desc',
            fallback:
                'Adds a Random button to play unpredictable moves and outsmart the AI',
          ),
          cost: GameController.costRandom,
          productId: BillingService.productRandomButton,
          isUnlocked: controller.unlockedRandom,
          isActive: controller.showRandom,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockRandom();
            _handleUnlock(
              context,
              loc.t('string39', fallback: 'Random Move Button'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowRandom(val);
            _handleToggle(
              context,
              loc.t('string39', fallback: 'Random Move Button'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string40', fallback: 'Show Markov Algorithm'),
          subtitle: loc.t(
            'show_algorithm_desc',
            fallback:
                'Reveals the live Markov Transition Matrix tracking your move patterns',
          ),
          cost: GameController.costAlgorithm,
          productId: BillingService.productShowAlgorithm,
          isUnlocked: controller.unlockedAlgorithm,
          isActive: controller.showAlgorithm,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockAlgorithm();
            _handleUnlock(
              context,
              loc.t('string40', fallback: 'Show Markov Algorithm'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowAlgorithm(val);
            _handleToggle(
              context,
              loc.t('string40', fallback: 'Show Markov Algorithm'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string41', fallback: 'Your Prediction Hint'),
          subtitle: loc.t(
            'your_prediction_desc',
            fallback: 'Displays the move(s) the AI predicts you will play next',
          ),
          cost: GameController.costYourPrediction,
          productId: BillingService.productYourPrediction,
          isUnlocked: controller.unlockedYourPrediction,
          isActive: controller.showYourPrediction,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockYourPrediction();
            _handleUnlock(
              context,
              loc.t('string41', fallback: 'Your Prediction Hint'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowYourPrediction(val);
            _handleToggle(
              context,
              loc.t('string41', fallback: 'Your Prediction Hint'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string42', fallback: 'PC Next Move Reveal'),
          subtitle: loc.t(
            'pc_next_move_desc',
            fallback:
                'Reveals the move(s) the AI is preparing to play against you',
          ),
          cost: GameController.costNextMove,
          productId: BillingService.productPcNextMove,
          isUnlocked: controller.unlockedNextMove,
          isActive: controller.showNextMove,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockNextMove();
            _handleUnlock(
              context,
              loc.t('string42', fallback: 'PC Next Move Reveal'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowNextMove(val);
            _handleToggle(
              context,
              loc.t('string42', fallback: 'PC Next Move Reveal'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('gift_box', fallback: 'Gift Box'),
          subtitle: controller.giftBoxDescription,
          cost: GameController.costGiftBox,
          productId: null,
          isUnlocked: controller.giftBoxUnlocked,
          isActive: controller.giftBoxEnabled,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockGiftBox();
            _handleUnlock(
              context,
              loc.t('gift_box', fallback: 'Gift Box'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleGiftBox(val);
            _handleToggle(
              context,
              loc.t('gift_box', fallback: 'Gift Box'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string43', fallback: 'Optimal Suggestion'),
          subtitle: loc.t(
            'suggestion_desc',
            fallback:
                "Recommends the optimal counter-move(s) to beat the AI's next play",
          ),
          cost: GameController.costSuggestion,
          productId: BillingService.productSuggestion,
          isUnlocked: controller.unlockedSuggestion,
          isActive: controller.showSuggestion,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockSuggestion();
            _handleUnlock(
              context,
              loc.t('string43', fallback: 'Optimal Suggestion'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowSuggestion(val);
            _handleToggle(
              context,
              loc.t('string43', fallback: 'Optimal Suggestion'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string44', fallback: 'Remove Ads'),
          subtitle: loc.t(
            'remove_ads_desc',
            fallback:
                'Removes all banner and video ad prompts across the entire app',
          ),
          cost: GameController.costRemoveAds,
          productId: BillingService.productRemoveAds,
          isUnlocked: controller.unlockedAds,
          isActive: controller.isRemoveAdsActive,
          enabledLabel: 'Ads Removed',
          disabledLabel: 'Not Active',
          onUnlock: () {
            final ok = controller.unlockAds();
            _handleUnlock(
              context,
              loc.t('string44', fallback: 'Remove Ads'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleRemoveAds(val);
            _handleToggle(
              context,
              loc.t('string44', fallback: 'Remove Ads'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('new_skin', fallback: 'New Skin'),
          subtitle: loc.t(
            'new_skin_desc',
            fallback: 'Hands Theme (Rock, Paper, Scissors)',
          ),
          cost: GameController.costNewSkin,
          productId: null,
          isUnlocked: controller.unlockedNewSkin,
          isActive: controller.showNewSkin,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockNewSkin();
            _handleUnlock(
              context,
              loc.t('new_skin', fallback: 'New Skin'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowNewSkin(val);
            _handleToggle(
              context,
              loc.t('new_skin', fallback: 'New Skin'),
              val,
            );
          },
        ),
        _buildShopItem(
          context: context,
          title: loc.t('string80', fallback: 'Crystal Ball'),
          subtitle: loc.t(
            'crystal_ball_desc',
            fallback:
                'Reveals the exact next move the AI will play before you choose',
          ),
          cost: GameController.costCrystalBall,
          productId: BillingService.productCrystalBall,
          isUnlocked: controller.unlockedCrystalBall,
          isActive: controller.showCrystalBall,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            final ok = controller.unlockCrystalBall();
            _handleUnlock(
              context,
              loc.t('string80', fallback: 'Crystal Ball'),
              ok,
            );
          },
          onToggle: (val) {
            controller.toggleShowCrystalBall(val);
            _handleToggle(
              context,
              loc.t('string80', fallback: 'Crystal Ball'),
              val,
            );
          },
        ),
        if (controller.unlockedCrystalBall)
          _buildShopItem(
            context: context,
            title: loc.t('string82', fallback: 'Crystal Ball+'),
            subtitle: loc.t(
              'crystal_ball_plus_desc',
              fallback:
                  'Upgrades Crystal Ball to guarantee 100% foresight on every single round',
            ),
            cost: GameController.costCrystalBallPlus,
            productId: null,
            isUnlocked: controller.unlockedCrystalBallPlus,
            isActive: controller.showCrystalBallPlus,
            isToggleEnabled: controller.showCrystalBall,
            enabledLabel: enabledStr,
            disabledLabel: disabledStr,
            onUnlock: () {
              final ok = controller.unlockCrystalBallPlus();
              _handleUnlock(
                context,
                loc.t('string82', fallback: 'Crystal Ball+'),
                ok,
              );
            },
            onToggle: (val) {
              if (val && !controller.showCrystalBall) {
                controller.audio.playVibrate();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${loc.t('string80', fallback: 'Crystal Ball')}: $disabledStr',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
                return;
              }
              controller.toggleShowCrystalBallPlus(val);
              _handleToggle(
                context,
                loc.t('string82', fallback: 'Crystal Ball+'),
                controller.showCrystalBallPlus,
              );
            },
          ),
        if (controller.isMarkovRecalibratorVisibleInShop)
          _buildShopItem(
            context: context,
            title: loc.t(
              'markov_recalibrator_title',
              fallback: 'Markov Recalibrator',
            ),
            subtitle: loc.t(
              'markov_recalibrator_desc',
              fallback:
                  'Reconfigures the Algorithm matrix and hints to expose the Robot Archmage\'s true 1-step short-term memory',
            ),
            cost: GameController.costMarkovRecalibrator,
            productId: null,
            isUnlocked: controller.unlockedMarkovRecalibrator,
            isActive: controller.showMarkovRecalibrator,
            enabledLabel: enabledStr,
            disabledLabel: disabledStr,
            onUnlock: () {
              final ok = controller.unlockMarkovRecalibrator();
              _handleUnlock(
                context,
                loc.t(
                  'markov_recalibrator_title',
                  fallback: 'Markov Recalibrator',
                ),
                ok,
              );
            },
            onToggle: (val) {
              controller.toggleMarkovRecalibrator(val);
              _handleToggle(
                context,
                loc.t(
                  'markov_recalibrator_title',
                  fallback: 'Markov Recalibrator',
                ),
                controller.showMarkovRecalibrator,
              );
            },
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 3: HOLY TRANSMUTATION (3 -> 1 ORB EXCHANGE + HOLD RAPID EXCHANGE)
  // ---------------------------------------------------------------------------
  Widget _buildTransmuteWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final sourceAvailable = controller.orbsFor(_transmuteSource);
    final targetAvailable = controller.orbsFor(_transmuteTarget);
    final maxBatches = sourceAvailable ~/ 3;
    final int previewBatches = _selectedBatchOption.fixedMultiplier != null
        ? _selectedBatchOption.fixedMultiplier!
        : (maxBatches > 0 ? maxBatches : 1);
    final canTransmute = _canTransmuteNow();

    final cardBg = palette.isDark
        ? const Color(0xFF1E222B)
        : palette.dialogCardSurface;
    final cardBorder = palette.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : palette.sandCardBorder;

    return SingleChildScrollView(
      key: const ValueKey('temple_wing_transmute'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.t('temple_transmute_title', fallback: 'Holy Transmutation'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: palette.primaryText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            loc.t(
              'castle_alchemy_desc',
              fallback:
                  'Transmute 3 surplus Elemental Orbs of one element into 1 Elemental Orb of another.',
            ),
            style: TextStyle(
              fontSize: 11.5,
              color: palette.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('holy_transmutation_card'),
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TransmuteCircleIcon(size: 22),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              loc.t(
                                'temple_transmute_rate_label',
                                fallback: '3 → 1 Exchange',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: palette.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _transmuteConfirmationText != null
                          ? Container(
                              key: const ValueKey('alchemy_confirmation_badge'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.successText.withValues(
                                  alpha: palette.isDark ? 0.16 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: palette.successText.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _transmuteConfirmationText!,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.successText,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              loc.t(
                                'castle_alchemy_tap_hint',
                                fallback: 'Tap orbs to switch',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: palette.mutedText,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTransmuteBatchSelector(palette, loc, sourceAvailable),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Left Side: Interactive 3 -> 1 Orb Diagram
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 3 Clustered Glowing Source Orbs (tappable to cycle)
                            InkWell(
                              key: const ValueKey('alchemy_source_selector'),
                              onTap: _cycleTransmuteSource,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      height: 48,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            top: 0,
                                            left: 15,
                                            child: ElementalEnergySphere(
                                              size: 26,
                                              primaryColor: _transmuteSource
                                                  .elementalPrimaryColor,
                                              secondaryColor: _transmuteSource
                                                  .elementalSecondaryColor,
                                              isDark: palette.isDark,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            child: ElementalEnergySphere(
                                              size: 26,
                                              primaryColor: _transmuteSource
                                                  .elementalPrimaryColor,
                                              secondaryColor: _transmuteSource
                                                  .elementalSecondaryColor,
                                              isDark: palette.isDark,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: ElementalEnergySphere(
                                              size: 26,
                                              primaryColor: _transmuteSource
                                                  .elementalPrimaryColor,
                                              secondaryColor: _transmuteSource
                                                  .elementalSecondaryColor,
                                              isDark: palette.isDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${3 * previewBatches}x ${_shortElementTitle(_transmuteSource, loc)} ($sourceAvailable)',
                                      key: const ValueKey(
                                        'alchemy_source_label',
                                      ),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: sourceAvailable >=
                                                3 * previewBatches
                                            ? palette.elementalText(
                                                _transmuteSource,
                                              )
                                            : palette.dangerText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 24,
                              color: palette.isDark
                                  ? _goldFill
                                  : palette.amberIcon,
                            ),
                            const SizedBox(width: 6),

                            // 1 Target Orb (tappable to cycle)
                            InkWell(
                              key: const ValueKey('alchemy_target_selector'),
                              onTap: _cycleTransmuteTarget,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 48,
                                      child: Center(
                                        child: ElementalEnergySphere(
                                          size: 38,
                                          primaryColor: _transmuteTarget
                                              .elementalPrimaryColor,
                                          secondaryColor: _transmuteTarget
                                              .elementalSecondaryColor,
                                          isDark: palette.isDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${previewBatches}x ${_shortElementTitle(_transmuteTarget, loc)} ($targetAvailable)',
                                      key: const ValueKey(
                                        'alchemy_target_label',
                                      ),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: palette.elementalText(
                                          _transmuteTarget,
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
                    const SizedBox(width: 8),

                    // Right Side: Bright-Gold Exchange Button with Press-and-Hold Support
                    Listener(
                      key: const ValueKey('alchemy_transmute_hold_listener'),
                      onPointerDown: canTransmute
                          ? (_) => _startHoldTransmute()
                          : null,
                      onPointerUp: (_) => _stopHoldTransmute(),
                      onPointerCancel: (_) => _stopHoldTransmute(),
                      child: ElevatedButton.icon(
                        key: const ValueKey('alchemy_transmute_button'),
                        onPressed: canTransmute ? _executeTransmute : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _goldFill,
                          foregroundColor: _goldDarkInk,
                          disabledBackgroundColor:
                              _goldFill.withValues(alpha: 0.28),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(
                          loc.t(
                            'castle_alchemy_exchange_btn',
                            fallback: 'Exchange',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loc.t(
                    'temple_transmute_hold_hint',
                    fallback: 'Tip: Press & hold Exchange for rapid transmutation.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: palette.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransmuteBatchSelector(
    AppPalette palette,
    LocalizationService loc,
    int sourceAvailable,
  ) {
    final trackBg = palette.isDark
        ? const Color(0xFF14171F)
        : const Color(0xFFE9E0CD);
    final trackBorder = palette.amberBorder.withValues(
      alpha: palette.isDark ? 0.25 : 0.45,
    );

    return Container(
      key: const ValueKey('alchemy_multiplier_row'),
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: trackBorder, width: 1.0),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _TransmuteBatchOption.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _buildTransmuteBatchPill(
                option: _TransmuteBatchOption.values[i],
                palette: palette,
                loc: loc,
                sourceAvailable: sourceAvailable,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransmuteBatchPill({
    required _TransmuteBatchOption option,
    required AppPalette palette,
    required LocalizationService loc,
    required int sourceAvailable,
  }) {
    final isSelected = _selectedBatchOption == option;
    final isEnabled = _isBatchOptionEnabled(option, sourceAvailable);

    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isSelected) {
      bgColor = isEnabled ? _goldFill : _goldFill.withValues(alpha: 0.45);
      borderColor = bgColor;
      textColor = isEnabled
          ? _goldDarkInk
          : _goldDarkInk.withValues(alpha: 0.72);
    } else if (isEnabled) {
      bgColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFFAF6EE);
      borderColor = palette.amberBorder.withValues(
        alpha: palette.isDark ? 0.28 : 0.42,
      );
      textColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.90)
          : palette.primaryText;
    } else {
      bgColor = Colors.transparent;
      borderColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : palette.sandCardBorder.withValues(alpha: 0.55);
      textColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.28)
          : palette.mutedText.withValues(alpha: 0.42);
    }

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      label: option.label(loc),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(option.keyName),
          onTap: isEnabled
              ? () {
                  controller.audio.playTapVibrate();
                  setState(() => _selectedBatchOption = option);
                }
              : null,
          borderRadius: BorderRadius.circular(7.5),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(7.5),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                option.label(loc),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WING 4: ADORATION ROOM (REAL-MONEY CONSUMABLE ORB BUNDLES & BULK PACKS)
  // ---------------------------------------------------------------------------
  Widget _buildAdorationWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final billing = controller.billingService;
    final hasAnyConsumablePrice = BillingService.allConsumableProductIds.any(
      (id) {
        final price = billing.getLocalizedPrice(id);
        return price != null && price.trim().isNotEmpty;
      },
    );
    final showOfflineBanner =
        !billing.isAvailable ||
        (!billing.isLoadingProducts && !hasAnyConsumablePrice);
    final selectedProductId =
        BillingService.consumableProductIdForMove(_selectedBulkElement);

    return ListView(
      key: const ValueKey('temple_wing_adoration'),
      children: [
        Text(
          loc.t('temple_adoration_title', fallback: 'Adoration Room'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: palette.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          loc.t(
            'temple_adoration_subtitle',
            fallback:
                'Support the Sanctuary and replenish Elemental Orbs immediately.',
          ),
          style: TextStyle(fontSize: 11.5, color: palette.amberSubtitle),
        ),
        if (showOfflineBanner) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('adoration_store_unavailable_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: palette.rewardedAdCardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.rewardedAdCardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: palette.amberIcon,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t(
                      'temple_store_offline_notice',
                      fallback:
                          'Google Play Billing is offline or packs are unconfigured. Connect to Google Play to view live prices.',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),

        Row(
          children: [
            const ReliquaryBundleIcon(size: 22),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                loc.t(
                  'temple_adoration_bundles_header',
                  fallback: 'All-Element Orb Bundles',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final bundle in ConsumableOrbBundle.values)
          _ConsumableBundleTile(
            cardKey: ValueKey('adoration_bundle_${bundle.productId}'),
            buttonKey: ValueKey('real_money_unlock_${bundle.productId}'),
            icon: bundle.icon,
            title: loc.t(bundle.titleKey, fallback: bundle.fallbackTitle),
            subtitle: loc.t(bundle.descKey, fallback: bundle.fallbackDesc),
            amountPerElement: bundle.amountPerElement,
            localizedPrice: billing.getLocalizedPrice(bundle.productId),
            unavailableLabel: loc.t(
              'temple_price_unavailable',
              fallback: 'Unavailable',
            ),
            isPurchasePending: billing.isPurchasePending(bundle.productId),
            isLoadingStore: billing.isLoadingProducts,
            onBuy: () => controller.buyWithRealMoney(bundle.productId),
            showAllElements: true,
          ),

        const SizedBox(height: 12),
        Row(
          children: [
            const ElementalCrystalIcon(size: 22),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                loc.t(
                  'temple_adoration_single_header',
                  fallback: 'Single-Element Bulk Pack (+1,500)',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Element selector row for +1,500 single-element pack
        Row(
          key: const ValueKey('adoration_single_element_selector_row'),
          children: [
            for (int i = 0; i < HandMove.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: _AdorationElementChip(
                  key: ValueKey(
                    'adoration_element_selector_${HandMove.values[i].orbKey}',
                  ),
                  move: HandMove.values[i],
                  label: _shortElementTitle(HandMove.values[i], loc),
                  selected: _selectedBulkElement == HandMove.values[i],
                  palette: palette,
                  onTap: () {
                    controller.audio.playTapVibrate();
                    setState(() => _selectedBulkElement = HandMove.values[i]);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        _ConsumableBundleTile(
          cardKey: const ValueKey('adoration_single_element_card'),
          buttonKey: ValueKey('real_money_unlock_$selectedProductId'),
          icon: _selectedBulkElement.elementalIcon,
          title:
              '+1,500 ${_selectedBulkElement.elementalOrbName(loc)}',
          subtitle: loc
              .t(
                'temple_single_pack_desc',
                fallback: 'Adds +1,500 {element} Orbs to your backpack',
              )
              .replaceAll(
                '{element}',
                _shortElementTitle(_selectedBulkElement, loc),
              ),
          amountPerElement: GameController.singleElementBulkPackBonus,
          localizedPrice: billing.getLocalizedPrice(selectedProductId),
          unavailableLabel: loc.t(
            'temple_price_unavailable',
            fallback: 'Unavailable',
          ),
          isPurchasePending: billing.isPurchasePending(selectedProductId),
          isLoadingStore: billing.isLoadingProducts,
          onBuy: () => controller.buyWithRealMoney(selectedProductId),
          showAllElements: false,
          singleMove: _selectedBulkElement,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WING 5: PRAYER ROOM (MEDITATION FOR FREE ORBS + PRE-BATTLE SACRED BLESSINGS)
  // ---------------------------------------------------------------------------
  Widget _buildPrayerWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final pendingBlessing = controller.pendingBattleBlessing;
    final canFreePray = controller.canActivateSacredBlessingFree();
    final canAdPray = controller.canActivateSacredBlessingWithAd();
    final isRemoveAds = controller.isRemoveAdsActive;

    final String statusMessage;
    if (pendingBlessing != null) {
      statusMessage =
          '${loc.t('temple_blessing_active_next', fallback: 'Active for Next Battle')}: ${loc.t(pendingBlessing.titleKey, fallback: pendingBlessing.fallbackTitle)}';
    } else if (isRemoveAds) {
      statusMessage = loc.t(
        'temple_blessing_perk_ready',
        fallback: 'Remove Ads Perk: Activate 1 blessing before battle.',
      );
    } else if (controller.hasFreeDailyPrayerAvailable()) {
      statusMessage = loc.t(
        'temple_blessing_daily_free_ready',
        fallback: '1 Free Daily Prayer available today!',
      );
    } else {
      statusMessage = loc.t(
        'temple_blessing_ad_only_ready',
        fallback: 'Daily free prayer used — watch an ad to receive a blessing.',
      );
    }

    return ListView(
      key: const ValueKey('temple_wing_prayer'),
      children: [
        Text(
          loc.t('temple_prayer_title', fallback: 'Prayer Room'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: palette.primaryText,
          ),
        ),
        const SizedBox(height: 6),

        // Meditation for Free Orbs (Watch Ad +50 Orbs), hidden when Remove Ads is active
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: !isRemoveAds
                ? Padding(
                    key: const ValueKey('shop_rewarded_ad_pinned'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRewardedAdCard(context),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('shop_rewarded_ad_hidden'),
                  ),
          ),
        ),

        // Pre-Battle Sacred Blessings Section
        Row(
          children: [
            const SacredBlessingIcon(size: 24),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                loc.t('temple_blessings_section_title', fallback: 'Sacred Blessings'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: palette.amberText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          key: const ValueKey('prayer_blessing_status_banner'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: pendingBlessing != null
                ? palette.successText.withValues(alpha: 0.12)
                : palette.rewardedAdCardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: pendingBlessing != null
                  ? palette.successText.withValues(alpha: 0.45)
                  : palette.rewardedAdCardBorder,
            ),
          ),
          child: Text(
            statusMessage,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: pendingBlessing != null
                  ? palette.successText
                  : palette.amberText,
            ),
          ),
        ),
        const SizedBox(height: 8),

        for (final blessing in SacredBlessing.values)
          _SacredBlessingCard(
            key: ValueKey('temple_blessing_card_${blessing.id}'),
            buttonKey: ValueKey('temple_blessing_pray_button_${blessing.id}'),
            blessing: blessing,
            title: loc.t(blessing.titleKey, fallback: blessing.fallbackTitle),
            description: loc.t(blessing.descKey, fallback: blessing.fallbackDesc),
            isThisActive: pendingBlessing == blessing,
            hasAnotherActive:
                pendingBlessing != null && pendingBlessing != blessing,
            canFreePray: canFreePray,
            canAdPray: canAdPray,
            isRemoveAds: isRemoveAds,
            activeLabel: loc.t(
              'temple_blessing_active_badge',
              fallback: 'Active',
            ),
            freePrayLabel: isRemoveAds
                ? loc.t('temple_blessing_pray_perk', fallback: 'Bless (Perk)')
                : loc.t('temple_blessing_pray_free', fallback: 'Pray (Free)'),
            adPrayLabel: loc.t(
              'temple_blessing_pray_ad',
              fallback: 'Watch Ad: Pray',
            ),
            palette: palette,
            onTap: () {
              if (canFreePray) {
                final ok = controller.activateSacredBlessingFree(blessing);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          '${loc.t(blessing.titleKey, fallback: blessing.fallbackTitle)}: ${loc.t('temple_blessing_ready_msg', fallback: 'Ready for next battle!')}',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                }
              } else if (canAdPray) {
                controller.watchAdToActivateSacredBlessing(
                  blessing,
                  onActivated: () {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            '${loc.t(blessing.titleKey, fallback: blessing.fallbackTitle)}: ${loc.t('temple_blessing_ready_msg', fallback: 'Ready for next battle!')}',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  },
                );
              }
            },
          ),
        if (!isRemoveAds && !canFreePray && pendingBlessing == null) ...[
          const SizedBox(height: 6),
          Text(
            loc.t(
              'temple_blessing_ad_disclosure',
              fallback:
                  'Rewarded Video Ad: watch an ad to activate 1 temporary blessing for your next battle.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: palette.mutedText),
          ),
        ],
      ],
    );
  }

  Widget _buildShopItem({
    required BuildContext context,
    required String title,
    String? subtitle,
    required ElementalCost cost,
    required String? productId,
    required bool isUnlocked,
    required bool isActive,
    bool isToggleEnabled = true,
    required String enabledLabel,
    required String disabledLabel,
    required VoidCallback onUnlock,
    required ValueChanged<bool> onToggle,
  }) {
    final billing = controller.billingService;
    final localizedPrice =
        productId != null ? billing.getLocalizedPrice(productId) : null;
    final isPending =
        productId != null && billing.isPurchasePending(productId);
    final isLoadingStore = productId != null && billing.isLoadingProducts;

    return _ShopItemTile(
      title: title,
      subtitle: subtitle,
      cost: cost,
      productId: productId,
      localizedPrice: localizedPrice,
      isPurchasePending: isPending,
      isLoadingStore: isLoadingStore,
      isUnlocked: isUnlocked,
      isActive: isActive,
      isToggleEnabled: isToggleEnabled,
      enabledLabel: enabledLabel,
      disabledLabel: disabledLabel,
      onUnlock: onUnlock,
      onRealMoneyUnlock: productId != null
          ? () {
              controller.buyWithRealMoney(productId);
            }
          : null,
      onToggle: onToggle,
    );
  }

  Widget _buildRewardedAdCard(BuildContext context) {
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    return Card(
      key: const ValueKey('shop_rewarded_ad_card'),
      margin: EdgeInsets.zero,
      elevation: palette.isDark ? null : 0,
      color: palette.rewardedAdCardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: palette.rewardedAdCardBorder,
          width: palette.isDark ? 1.0 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MeditationHaloIcon(size: 24),
                    const SizedBox(width: 7),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          loc.t(
                            'string45',
                            fallback: 'Free Elemental Orbs',
                          ),
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: palette.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  controller.isRewardedAdOnCooldown
                      ? 'Cooldown active (2m)'
                      : controller.rewardedAdDescription,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        palette.isDark ? FontWeight.normal : FontWeight.w500,
                    color: controller.isRewardedAdOnCooldown
                        ? (palette.isDark ? Colors.grey : palette.mutedText)
                        : (palette.isDark ? Colors.amber : palette.amberText),
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  key: const ValueKey('shop_rewarded_ad_element_icons'),
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final move in controller.bonusOrbMoves)
                      Tooltip(
                        message: move.displayLabel(
                          elemental: true,
                          localization: loc,
                        ),
                        child: ElementalEnergySphere(
                          key: ValueKey('shop_ad_orb_icon_${move.name}'),
                          size: 19,
                          primaryColor: move.elementalPrimaryColor,
                          secondaryColor: move.elementalSecondaryColor,
                          isDark: palette.isDark,
                        ),
                      ),
                  ],
                ),
              ],
            );

            final actionButton = ElevatedButton.icon(
              key: const ValueKey(
                'shop_watch_rewarded_ad_button',
              ),
              onPressed: controller.isRewardedAdReady
                  ? () {
                      controller.watchRewardedAd(
                        onRewardEarned: () {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  controller.activeRewardedAdSnackBarMessage,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        },
                      );
                    }
                  : null,
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                size: 16,
              ),
              label: Text(
                controller.isRewardedAdOnCooldown
                    ? 'Wait 2m'
                    : AdService.rewardedAdButtonLabel,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF231F1A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            );

            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  textColumn,
                  const SizedBox(height: 10),
                  actionButton,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: textColumn),
                const SizedBox(width: 12),
                actionButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TempleCompactVerticalTabPill extends StatelessWidget {
  final Widget Function(bool isSelected) iconBuilder;
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _TempleCompactVerticalTabPill({
    super.key,
    required this.iconBuilder,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const goldFill = _ShopDialogState._goldFill;
    const goldDarkInk = _ShopDialogState._goldDarkInk;

    final bgColor = selected
        ? goldFill
        : (palette.isDark
              ? const Color(0xFF1F1C16)
              : palette.dialogCardSurface);
    final borderColor = selected
        ? goldFill
        : palette.amberBorder.withValues(alpha: palette.isDark ? 0.45 : 0.6);
    final textColor = selected
        ? goldDarkInk
        : (palette.isDark
              ? Colors.white.withValues(alpha: 0.88)
              : palette.primaryText);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconBuilder(selected),
              const SizedBox(height: 3),
              SizedBox(
                height: 13,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: textColor,
                    ),
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

class _ShopItemTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ElementalCost cost;
  final String? productId;
  final String? localizedPrice;
  final bool isPurchasePending;
  final bool isLoadingStore;
  final bool isUnlocked;
  final bool isActive;
  final bool isToggleEnabled;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback onUnlock;
  final VoidCallback? onRealMoneyUnlock;
  final ValueChanged<bool> onToggle;

  const _ShopItemTile({
    required this.title,
    this.subtitle,
    required this.cost,
    this.productId,
    this.localizedPrice,
    this.isPurchasePending = false,
    this.isLoadingStore = false,
    required this.isUnlocked,
    required this.isActive,
    this.isToggleEnabled = true,
    required this.enabledLabel,
    required this.disabledLabel,
    required this.onUnlock,
    this.onRealMoneyUnlock,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final hasRealMoneyPrice =
        localizedPrice != null && localizedPrice!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: palette.isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : palette.shopTileSurface,
        borderRadius: BorderRadius.circular(12),
        border: isUnlocked && isActive
            ? Border.all(
                color: palette.successIcon.withValues(
                  alpha: palette.isDark ? 0.4 : 0.55,
                ),
                width: 1.2,
              )
            : (palette.isDark
                  ? null
                  : Border.all(
                      color: palette.sandCardBorder,
                      width: 1.0,
                    )),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isUnlocked
              ? (isToggleEnabled
                  ? () => onToggle(!isActive)
                  : () => onToggle(true))
              : onUnlock,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: isUnlocked
                ? _buildUnlockedContent(palette)
                : _buildLockedContent(palette, hasRealMoneyPrice),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedContent(AppPalette palette) {
    final activeColor = palette.successIcon;
    final inactiveColor = palette.isDark ? Colors.grey : palette.mutedText;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: palette.primaryText,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.amberSubtitle,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.cancel_outlined,
                    size: 13,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isActive ? enabledLabel : disabledLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? activeColor : inactiveColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: isActive,
          onChanged: isToggleEnabled ? onToggle : null,
          activeTrackColor: activeColor,
        ),
      ],
    );
  }

  Widget _buildLockedContent(AppPalette palette, bool hasRealMoneyPrice) {
    final entries = cost.nonZeroEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: palette.primaryText,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            softWrap: true,
            style: TextStyle(
              fontSize: 11,
              color: palette.amberSubtitle,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Unlock',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    palette.isDark ? FontWeight.normal : FontWeight.w600,
                color: palette.isDark ? Colors.grey : palette.secondaryText,
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton(
                  key: ValueKey(
                    'diamond_unlock_${productId ?? title}',
                  ),
                  onPressed: isPurchasePending ? null : onUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        palette.isDark ? null : palette.dialogSurface,
                    elevation: palette.isDark ? null : 1,
                    side: palette.isDark
                        ? null
                        : BorderSide(color: palette.sandCardBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    minimumSize: const Size(52, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _ElementalCostPillRow(
                    entries: entries,
                    palette: palette,
                  ),
                ),
                if (productId != null)
                  OutlinedButton(
                    key: ValueKey('real_money_unlock_$productId'),
                    onPressed: (!isPurchasePending &&
                            !isLoadingStore &&
                            hasRealMoneyPrice)
                        ? onRealMoneyUnlock
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          palette.isDark ? null : palette.primaryText,
                      disabledForegroundColor:
                          palette.isDark ? null : palette.mutedText,
                      backgroundColor:
                          palette.isDark ? null : palette.dialogSurface,
                      side: palette.isDark
                          ? null
                          : BorderSide(
                              color: palette.amberBorder.withValues(alpha: 0.65),
                            ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      minimumSize: const Size(52, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: (isPurchasePending || isLoadingStore)
                        ? const SizedBox(
                            key: ValueKey('purchase_loading_indicator'),
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            hasRealMoneyPrice ? localizedPrice! : 'Unavailable',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _InfiniteStatUpgradeTile extends StatelessWidget {
  final Key cardKey;
  final Key buttonKey;
  final Key adButtonKey;
  final Widget iconWidget;
  final String title;
  final String subtitle;
  final String statusText;
  final String actionLabel;
  final ElementalCost cost;
  final bool showAdButton;
  final String adButtonLabel;
  final bool canWatchAd;
  final VoidCallback onPurchase;
  final VoidCallback onWatchAd;

  const _InfiniteStatUpgradeTile({
    required this.cardKey,
    required this.buttonKey,
    required this.adButtonKey,
    required this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.actionLabel,
    required this.cost,
    required this.showAdButton,
    required this.adButtonLabel,
    required this.canWatchAd,
    required this.onPurchase,
    required this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final entries = cost.nonZeroEntries;

    return Container(
      key: cardKey,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: palette.isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : palette.shopTileSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.isDark
              ? palette.amberBorder.withValues(alpha: 0.32)
              : palette.sandCardBorder,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPurchase,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        iconWidget,
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: palette.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.rewardedAdCardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.amberBorder.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: palette.amberText,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.amberSubtitle,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: palette.isDark
                            ? FontWeight.normal
                            : FontWeight.w600,
                        color: palette.isDark
                            ? Colors.grey
                            : palette.secondaryText,
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton(
                          key: buttonKey,
                          onPressed: onPurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                palette.isDark ? null : palette.dialogSurface,
                            elevation: palette.isDark ? null : 1,
                            side: palette.isDark
                                ? null
                                : BorderSide(color: palette.sandCardBorder),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            minimumSize: const Size(52, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: _ElementalCostPillRow(
                            entries: entries,
                            palette: palette,
                          ),
                        ),
                        if (showAdButton)
                          ElevatedButton.icon(
                            key: adButtonKey,
                            onPressed: canWatchAd ? onWatchAd : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: const Color(0xFF231F1A),
                              disabledBackgroundColor:
                                  Colors.amber.withValues(alpha: 0.28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              minimumSize: const Size(52, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 14,
                            ),
                            label: Text(
                              adButtonLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsumableBundleTile extends StatelessWidget {
  final Key cardKey;
  final Key buttonKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final int amountPerElement;
  final String? localizedPrice;
  final String unavailableLabel;
  final bool isPurchasePending;
  final bool isLoadingStore;
  final VoidCallback onBuy;
  final bool showAllElements;
  final HandMove? singleMove;

  const _ConsumableBundleTile({
    required this.cardKey,
    required this.buttonKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amountPerElement,
    required this.localizedPrice,
    required this.unavailableLabel,
    required this.isPurchasePending,
    required this.isLoadingStore,
    required this.onBuy,
    required this.showAllElements,
    this.singleMove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final hasPrice =
        localizedPrice != null && localizedPrice!.trim().isNotEmpty;

    return Container(
      key: cardKey,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.isDark
            ? const Color(0xFF1E222B)
            : palette.shopTileSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: palette.amberBorder.withValues(
            alpha: palette.isDark ? 0.32 : 0.48,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: singleMove != null
                          ? palette.elementalText(singleMove!)
                          : palette.amberIcon,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: palette.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.amberSubtitle,
                  ),
                ),
                const SizedBox(height: 5),
                if (showAllElements)
                  Wrap(
                    spacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final move in HandMove.values)
                        ElementalEnergySphere(
                          size: 16,
                          primaryColor: move.elementalPrimaryColor,
                          secondaryColor: move.elementalSecondaryColor,
                          isDark: palette.isDark,
                        ),
                    ],
                  )
                else if (singleMove != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElementalEnergySphere(
                        size: 20,
                        primaryColor: singleMove!.elementalPrimaryColor,
                        secondaryColor: singleMove!.elementalSecondaryColor,
                        isDark: palette.isDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '+$amountPerElement',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: palette.elementalText(singleMove!),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            key: buttonKey,
            onPressed: (!isPurchasePending && !isLoadingStore && hasPrice)
                ? onBuy
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ShopDialogState._goldFill,
              foregroundColor: _ShopDialogState._goldDarkInk,
              disabledBackgroundColor: palette.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : palette.sandCardSurface,
              disabledForegroundColor: palette.mutedText,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              minimumSize: const Size(74, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: (isPurchasePending || isLoadingStore)
                ? const SizedBox(
                    key: ValueKey('purchase_loading_indicator'),
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    hasPrice ? localizedPrice! : unavailableLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdorationElementChip extends StatelessWidget {
  final HandMove move;
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _AdorationElementChip({
    super.key,
    required this.move,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? _ShopDialogState._goldFill
        : palette.amberBorder.withValues(alpha: 0.35);
    final bgColor = selected
        ? (palette.isDark
              ? _ShopDialogState._goldFill.withValues(alpha: 0.16)
              : _ShopDialogState._goldFill.withValues(alpha: 0.25))
        : (palette.isDark
              ? const Color(0xFF1A1D26)
              : palette.dialogCardSurface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElementalEnergySphere(
                size: 20,
                primaryColor: move.elementalPrimaryColor,
                secondaryColor: move.elementalSecondaryColor,
                isDark: palette.isDark,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: palette.elementalText(move),
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

class _SacredBlessingCard extends StatelessWidget {
  final Key buttonKey;
  final SacredBlessing blessing;
  final String title;
  final String description;
  final bool isThisActive;
  final bool hasAnotherActive;
  final bool canFreePray;
  final bool canAdPray;
  final bool isRemoveAds;
  final String activeLabel;
  final String freePrayLabel;
  final String adPrayLabel;
  final AppPalette palette;
  final VoidCallback onTap;

  const _SacredBlessingCard({
    super.key,
    required this.buttonKey,
    required this.blessing,
    required this.title,
    required this.description,
    required this.isThisActive,
    required this.hasAnotherActive,
    required this.canFreePray,
    required this.canAdPray,
    required this.isRemoveAds,
    required this.activeLabel,
    required this.freePrayLabel,
    required this.adPrayLabel,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = !isThisActive && !hasAnotherActive && (canFreePray || canAdPray);
    final accent = blessing.accentColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.isDark
            ? const Color(0xFF1E222B)
            : palette.shopTileSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isThisActive
              ? palette.successText.withValues(alpha: 0.7)
              : accent.withValues(alpha: palette.isDark ? 0.42 : 0.55),
          width: isThisActive ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(blessing.icon, size: 19, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.amberSubtitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            key: buttonKey,
            onPressed: canTap ? onTap : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isThisActive
                  ? palette.successText.withValues(alpha: 0.2)
                  : _ShopDialogState._goldFill,
              foregroundColor: isThisActive
                  ? palette.successText
                  : _ShopDialogState._goldDarkInk,
              disabledBackgroundColor: isThisActive
                  ? palette.successText.withValues(alpha: 0.18)
                  : _ShopDialogState._goldFill.withValues(alpha: 0.25),
              disabledForegroundColor: isThisActive
                  ? palette.successText
                  : palette.mutedText,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              minimumSize: const Size(74, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(
              isThisActive
                  ? Icons.check_circle_rounded
                  : (canFreePray
                        ? Icons.auto_awesome_rounded
                        : Icons.play_circle_fill_rounded),
              size: 14,
            ),
            label: Text(
              isThisActive
                  ? activeLabel
                  : (canFreePray ? freePrayLabel : adPrayLabel),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElementalCostPillRow extends StatelessWidget {
  final List<MapEntry<HandMove, int>> entries;
  final AppPalette palette;

  const _ElementalCostPillRow({
    required this.entries,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElementalEnergySphere(
                  key: ValueKey('shop_cost_orb_${entries[i].key.orbKey}'),
                  size: 14,
                  primaryColor: entries[i].key.elementalPrimaryColor,
                  secondaryColor: entries[i].key.elementalSecondaryColor,
                  isDark: palette.isDark,
                ),
                const SizedBox(width: 2.5),
                Text(
                  '${entries[i].value}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: palette.elementalText(entries[i].key),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
