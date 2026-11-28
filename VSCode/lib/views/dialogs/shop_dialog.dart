import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../models/royal_castle.dart';
import '../../models/sacred_blessing.dart';
import '../../services/ad_service.dart';
import '../../services/audio_service.dart';
import '../../services/billing_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/elemental_energy_sphere.dart';
import '../widgets/shop_item_icons.dart';
import '../widgets/temple_wing_icons.dart';
import 'altar_sacrifice_dialog.dart';
import 'royal_castle_dialog.dart';

/// Identifies the 6 wings inside the Sacred Temple ([ShopDialog] / [SacredTempleDialog]) hub.
enum TempleWing {
  consagration,
  offerings,
  transmute,
  adoration,
  prayer,
  offertory,
}

enum _OffertoryBatchOption {
  x1(1, 'offertory_batch_1x'),
  x10(10, 'offertory_batch_10x'),
  max(null, 'offertory_batch_max');

  final int? fixedMultiplier;
  final String keyName;

  const _OffertoryBatchOption(this.fixedMultiplier, this.keyName);

  String label(LocalizationService loc) {
    if (fixedMultiplier != null) {
      return '${fixedMultiplier}x';
    }
    return loc.t('castle_alchemy_max', fallback: 'MAX');
  }
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

enum _ConsagrationBatchOption {
  x1(1, 'consagration_batch_1x'),
  x10(10, 'consagration_batch_10x'),
  x100(100, 'consagration_batch_100x'),
  max(null, 'consagration_batch_max');

  final int? fixedMultiplier;
  final String keyName;

  const _ConsagrationBatchOption(this.fixedMultiplier, this.keyName);

  String label(LocalizationService loc) {
    if (fixedMultiplier != null) {
      return '${fixedMultiplier}x';
    }
    return loc.t('castle_alchemy_max', fallback: 'MAX');
  }
}

/// Alias so callers can refer to the 6-tab Sacred Temple Hub as [SacredTempleDialog]
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

class _ShopDialogState extends State<ShopDialog> with TickerProviderStateMixin {
  static const Color _goldFill = Color(0xFFF5C22B);
  static const Color _goldDarkInk = Color(0xFF1E1B16);
  static const Color _alertRed = Color(0xFFE53935);

  GameController get controller => widget.controller;

  late TempleWing _selectedWing;
  final ScrollController _wingScrollController = ScrollController();
  late HandMove _transmuteSource;
  late HandMove _transmuteTarget;
  _TransmuteBatchOption _selectedBatchOption = _TransmuteBatchOption.x1;
  String? _transmuteConfirmationText;
  Timer? _transmuteConfirmationTimer;
  Timer? _holdStartTimer;
  Timer? _holdRepeatTimer;

  // Consagration Room batch upgrade state, hold timers, and visual feedback
  _ConsagrationBatchOption _selectedConsagrationBatch =
      _ConsagrationBatchOption.x1;
  bool _showInsufficientOrbsInlinePrompt = false;
  Timer? _consagrationHoldStartTimer;
  Timer? _consagrationHoldRepeatTimer;
  bool _consagrationHoldIsHp = true;
  bool _didTriggerConsagrationHold = false;
  int _consagrationHoldTickCount = 0;
  late final AnimationController _hpFeedbackController;
  late final AnimationController _manaFeedbackController;
  String? _hpFloatingGainText;
  String? _manaFloatingGainText;

  // Offertory Wing state, 1-second live counter ticker, and parabolic flying 3D orbs VFX
  _OffertoryBatchOption _selectedOffertoryBatch = _OffertoryBatchOption.x1;
  _OffertoryBatchOption _selectedOffertoryCapBatch = _OffertoryBatchOption.x1;
  Timer? _offertoryLiveTimer;
  final GlobalKey _dialogStackKey = GlobalKey();
  final GlobalKey _offertoryVaultAnchorKey = GlobalKey();
  final Map<HandMove, GlobalKey> _headerOrbKeys = {
    for (final m in HandMove.values) m: GlobalKey(),
  };
  late final AnimationController _offertoryFlyController;
  List<HandMove> _offertoryFlyingMoves = const [];
  int _offertoryFloatingCollectAmount = 0;

  HandMove _selectedBulkElement = HandMove.rock;

  bool _restoredDuringCurrentRequest = false;
  bool _errorDuringCurrentRequest = false;
  late BgmTrack _returnBgmTrack;
  bool _suppressBgmRestoreOnDispose = false;

  @override
  void initState() {
    super.initState();
    _returnBgmTrack = controller.audio.currentTrack == BgmTrack.battle
        ? BgmTrack.battle
        : BgmTrack.worldMap;
    unawaited(controller.audio.playTrack(BgmTrack.sacredTemple));
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
    _hpFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _hpFloatingGainText = null);
        }
      });
    _manaFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _manaFloatingGainText = null);
        }
      });
    _offertoryFlyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _offertoryFlyingMoves = const [];
            _offertoryFloatingCollectAmount = 0;
          });
        }
      });
    _syncOffertoryLiveTimer();
    if (_selectedWing == TempleWing.offertory) {
      controller.onOffertoryWingInteracted();
    }
    controller.billingService.addEventListener(_onBillingEvent);
  }

  void _syncOffertoryLiveTimer() {
    if (_selectedWing == TempleWing.offertory) {
      _offertoryLiveTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (mounted && _selectedWing == TempleWing.offertory) {
            setState(() {});
          }
        },
      );
    } else {
      _offertoryLiveTimer?.cancel();
      _offertoryLiveTimer = null;
    }
  }

  @override
  void dispose() {
    if (!_suppressBgmRestoreOnDispose &&
        controller.audio.currentTrack == BgmTrack.sacredTemple) {
      unawaited(controller.audio.playTrack(_returnBgmTrack));
    }
    _stopHoldTransmute();
    _stopHoldConsagration();
    _offertoryLiveTimer?.cancel();
    _offertoryLiveTimer = null;
    _hpFeedbackController.dispose();
    _manaFeedbackController.dispose();
    _offertoryFlyController.dispose();
    _transmuteConfirmationTimer?.cancel();
    _wingScrollController.dispose();
    controller.billingService.removeEventListener(_onBillingEvent);
    super.dispose();
  }

  void _selectWing(TempleWing wing) {
    _stopHoldTransmute();
    _stopHoldConsagration();
    controller.audio.playTapVibrate();
    if (_wingScrollController.hasClients) {
      _wingScrollController.jumpTo(0.0);
    }
    if (_selectedWing != wing) {
      setState(() {
        _selectedWing = wing;
        if (wing != TempleWing.consagration) {
          _showInsufficientOrbsInlinePrompt = false;
        }
      });
      _syncOffertoryLiveTimer();
      if (wing == TempleWing.offertory) {
        controller.onOffertoryWingInteracted();
      }
    }
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
        return loc.t('string56', fallback: 'Learn Earth & Metal');
      case BillingService.productYourPrediction:
        return loc.t('string41', fallback: 'Your Prediction Hint');
      case BillingService.productPcNextMove:
        return loc.t('string42', fallback: 'PC Next Move Reveal');
      case BillingService.productSuggestion:
        return loc.t('string43', fallback: 'Optimal Suggestion');
      case BillingService.productRemoveAds:
        return loc.t(
          'vow_of_silence_title',
          fallback: 'Vow of Silence — Remove Ads',
        );
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

  void _handleOfferingPurchase({
    required BuildContext context,
    required ShopUpgradeArtifact artifact,
    required String title,
    required String description,
    required ElementalCost sacrificedCost,
    required bool Function() onConfirmUnlock,
    bool canPurchase = true,
    String? badgeLabel,
  }) {
    final loc = controller.localization;
    if (!canPurchase || !controller.canAfford(sacrificedCost)) {
      controller.audio.playVibrate();
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
      return;
    }

    controller.audio.playTapVibrate();
    AltarSacrificeDialog.show(
      context,
      controller: controller,
      artifact: artifact,
      itemTitle: title,
      itemDescription: description,
      sacrificedCost: sacrificedCost,
      badgeLabel: badgeLabel,
      onConfirmSacrifice: () {
        final ok = onConfirmUnlock();
        if (ok) {
          controller.audio.playWinVibrate();
        } else {
          controller.audio.playVibrate();
        }
        return ok;
      },
    );
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
    final loc = controller.localization;
    final title = loc.t('string56', fallback: 'Learn Earth & Metal');
    final desc = loc.t(
      'new_hands_desc',
      fallback:
          'Unlocks Earth & Metal elements for an expanded 5-element battle matrix',
    );
    _handleOfferingPurchase(
      context: context,
      artifact: ShopUpgradeArtifact.newHands,
      title: title,
      description: desc,
      sacrificedCost: GameController.costNewHands,
      onConfirmUnlock: controller.unlockNewHands,
    );
  }

  Future<void> _handleNewHandsToggle(BuildContext context, bool val) async {
    final title = controller.localization.t(
      'string56',
      fallback: 'Learn Earth & Metal',
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
    final showSecondaryElements = controller.includesEarthAndMetalInBonuses ||
        controller.showNewHands ||
        controller.earthOrbs > 0 ||
        controller.metalOrbs > 0;

    const primaryMoves = [
      HandMove.rock,
      HandMove.paper,
      HandMove.scissors,
    ];
    const secondaryMoves = [
      HandMove.lizard,
      HandMove.spock,
    ];
    const double orbRowSpacing = 22.0;

    Widget buildOrbChip(HandMove move) {
      return Row(
        key: ValueKey('shop_header_orb_${move.orbKey}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          KeyedSubtree(
            key: _headerOrbKeys[move],
            child: ElementalEnergySphere(
              key: ValueKey('shop_header_orb_sphere_${move.orbKey}'),
              size: 17,
              primaryColor: move.elementalPrimaryColor,
              secondaryColor: move.elementalSecondaryColor,
              isDark: palette.isDark,
            ),
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
      );
    }

    Widget buildOrbRow(Key rowKey, List<HandMove> moves) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          key: rowKey,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < moves.length; i++) ...[
              if (i > 0) const SizedBox(width: orbRowSpacing),
              buildOrbChip(moves[i]),
            ],
          ],
        ),
      );
    }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          buildOrbRow(
            const ValueKey('shop_orb_summary_primary_row'),
            primaryMoves,
          ),
          if (showSecondaryElements) ...[
            const SizedBox(height: 5),
            buildOrbRow(
              const ValueKey('shop_orb_summary_secondary_row'),
              secondaryMoves,
            ),
          ],
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
    final fixedHeight = HubModalSizing.fixedHeightFor(context);

    return Dialog(
      key: const ValueKey('sacred_temple_dialog'),
      backgroundColor: palette.dialogSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
      insetPadding: HubModalSizing.insetPadding,
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
        key: const ValueKey('sacred_temple_dialog_frame'),
        constraints: BoxConstraints(
          maxWidth: HubModalSizing.maxWidth,
          minHeight: fixedHeight,
          maxHeight: fixedHeight,
        ),
        child: Stack(
          key: _dialogStackKey,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Fixed Top Header, Navigation Tabs & Orb Balance Bar (Never Scrolls)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: palette.amberBorder.withValues(
                            alpha: palette.isDark ? 0.18 : 0.14,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.amberBorder.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const SacredTempleEmblemIcon(size: 32),
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
                  const SizedBox(height: 8),

                  // 6 Compact Vertical Navigation Tab Pills in a Single Row
                  _buildTempleTabBar(context, palette, loc),
                  const SizedBox(height: 8),

                  // Persistent 5 Elemental Orbs Balance Bar across all 6 Wings
                  _buildOrbSummaryBar(context),

                  Divider(
                    height: 12,
                    thickness: 1,
                    color: palette.divider,
                  ),

                  // 2. Scrollable Wing Content Area Only (Expanded)
                  Expanded(
                    child: ClipRect(
                      child: Scrollbar(
                        key: ValueKey(
                          'temple_wing_scrollbar_${_selectedWing.name}',
                        ),
                        controller: _wingScrollController,
                        thumbVisibility: true,
                        thickness: 4,
                        radius: const Radius.circular(8),
                        child: _buildSelectedWing(context, palette, loc),
                      ),
                    ),
                  ),

                  // 3. Pinned Bottom Footer (Restore Purchases & Ok Button — Never Scrolls)
                  Divider(
                    height: 12,
                    thickness: 1,
                    color: palette.divider,
                  ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
            if (_offertoryFlyingMoves.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: _buildOffertoryFlyingOrbsOverlay(palette),
                ),
              ),
          ],
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
      bool hasDot,
    })> tabs = [
      (
        wing: TempleWing.consagration,
        key: const ValueKey('temple_tab_consagration'),
        iconBuilder: (_) => const ConsagrationChaliceIcon(
          size: 28,
          isOnGoldBackground: false,
        ),
        label: loc.t('temple_tab_consagration', fallback: 'Consagration'),
        hasDot: false,
      ),
      (
        wing: TempleWing.offerings,
        key: const ValueKey('temple_tab_offerings'),
        iconBuilder: (_) => const OfferingsAltarIcon(
          size: 28,
          isOnGoldBackground: false,
        ),
        label: loc.t('temple_tab_offerings', fallback: 'Offerings'),
        hasDot: false,
      ),
      (
        wing: TempleWing.transmute,
        key: const ValueKey('temple_tab_transmute'),
        iconBuilder: (_) => const HolyTransformationIcon(
          size: 28,
          isOnGoldBackground: false,
        ),
        label: loc.t('temple_tab_transmute', fallback: 'Transform'),
        hasDot: false,
      ),
      (
        wing: TempleWing.adoration,
        key: const ValueKey('temple_tab_adoration'),
        iconBuilder: (_) => const AdorationHarpIcon(
          size: 28,
          isOnGoldBackground: false,
        ),
        label: loc.t('temple_tab_adoration', fallback: 'Adoration'),
        hasDot: false,
      ),
      (
        wing: TempleWing.prayer,
        key: const ValueKey('temple_tab_prayer'),
        iconBuilder: (_) => const PrayerHandsIcon(
          size: 28,
          isOnGoldBackground: false,
        ),
        label: loc.t('temple_tab_prayer', fallback: 'Prayer'),
        hasDot: false,
      ),
      (
        wing: TempleWing.offertory,
        key: const ValueKey('temple_tab_offertory'),
        iconBuilder: (_) => const TitheVaultIcon(
          size: 28,
          isOnGoldBackground: false,
        ),
        label: loc.t('temple_tab_offertory', fallback: 'Offertory'),
        hasDot: controller.isOffertoryFull,
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
              showDot: tabs[i].hasDot,
              palette: palette,
              onTap: () => _selectWing(tabs[i].wing),
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
      case TempleWing.offertory:
        return _buildOffertoryWing(context, palette, loc);
    }
  }

  // ---------------------------------------------------------------------------
  // WING 1: CONSAGRATION ROOM (1x/10x/100x/MAX Batch, Hero Peak Guard, Hold & Ad)
  // ---------------------------------------------------------------------------
  String _formatGroupedInt(int value, LocalizationService loc) {
    final sep = loc.currentLanguage == 'en' ? ',' : '.';
    final str = value.toString();
    if (str.length <= 3) return str;
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}$sep',
    );
  }

  void _stopHoldConsagration() {
    _consagrationHoldStartTimer?.cancel();
    _consagrationHoldStartTimer = null;
    _consagrationHoldRepeatTimer?.cancel();
    _consagrationHoldRepeatTimer = null;
    _consagrationHoldTickCount = 0;
  }

  bool _canHoldConsagration(bool isHp) {
    final mult = _selectedConsagrationBatch.fixedMultiplier;
    if (mult != 1 && mult != 10) return false;
    final isBelowPeak = isHp
        ? controller.isHpBelowUnclaimedHeroPeak
        : controller.isManaBelowUnclaimedHeroPeak;
    if (isBelowPeak) return false;
    return isHp
        ? controller.canAffordMaxHpLevels(mult!)
        : controller.canAffordMaxManaLevels(mult!);
  }

  void _startHoldConsagration(bool isHp) {
    _stopHoldConsagration();
    _didTriggerConsagrationHold = false;
    _consagrationHoldIsHp = isHp;
    _consagrationHoldTickCount = 0;
    if (!_canHoldConsagration(isHp)) return;
    _consagrationHoldStartTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        if (!mounted || !_canHoldConsagration(_consagrationHoldIsHp)) return;
        _didTriggerConsagrationHold = true;
        _runHoldConsagrationStep();
      },
    );
  }

  void _runHoldConsagrationStep() {
    if (!mounted || !_canHoldConsagration(_consagrationHoldIsHp)) {
      _stopHoldConsagration();
      return;
    }
    final batchSize = _selectedConsagrationBatch.fixedMultiplier;
    if (batchSize != 1 && batchSize != 10) {
      _stopHoldConsagration();
      return;
    }
    _consagrationHoldTickCount += 1;
    final ok = _executeConsagrationPurchase(
      isHp: _consagrationHoldIsHp,
      levels: batchSize!,
      isHoldTick: true,
    );
    if (!ok || !_canHoldConsagration(_consagrationHoldIsHp)) {
      _stopHoldConsagration();
      return;
    }
    final nextDelayMs = _consagrationHoldTickCount <= 3
        ? 180
        : (_consagrationHoldTickCount <= 8 ? 130 : 90);
    _consagrationHoldRepeatTimer = Timer(
      Duration(milliseconds: nextDelayMs),
      _runHoldConsagrationStep,
    );
  }

  void _stepDownConsagrationBatchIfNeeded() {
    final fixed = _selectedConsagrationBatch.fixedMultiplier;
    if (fixed == null || fixed == 1) return;
    final can100 =
        controller.canAffordMaxHpLevels(100) ||
        controller.canAffordMaxManaLevels(100);
    final can10 =
        controller.canAffordMaxHpLevels(10) ||
        controller.canAffordMaxManaLevels(10);
    if (fixed == 100 && !can100) {
      _selectedConsagrationBatch =
          can10 ? _ConsagrationBatchOption.x10 : _ConsagrationBatchOption.x1;
    } else if (fixed == 10 && !can10) {
      _selectedConsagrationBatch = _ConsagrationBatchOption.x1;
    }
  }

  void _triggerConsagrationVisualFeedback({
    required bool isHp,
    required int levelsGained,
  }) {
    if (!mounted) return;
    final loc = controller.localization;
    final formattedCount = _formatGroupedInt(levelsGained, loc);
    final floatingText = loc
        .t(
          isHp
              ? 'consagration_floating_hp_gain'
              : 'consagration_floating_mana_gain',
          fallback: isHp ? '+{count} HP!' : '+{count} Mana!',
        )
        .replaceAll('{count}', formattedCount);

    setState(() {
      if (isHp) {
        _hpFloatingGainText = floatingText;
      } else {
        _manaFloatingGainText = floatingText;
      }
    });
    if (isHp) {
      _hpFeedbackController.forward(from: 0.0);
    } else {
      _manaFeedbackController.forward(from: 0.0);
    }
  }

  void _switchToTransmuteFromConsagration() {
    _stopHoldConsagration();
    // Smartly pre-select surplus Earth/Metal orb -> lowest basic orb if helpful
    HandMove? surplus;
    int bestBalance = 2;
    for (final candidate in const [
      HandMove.earth,
      HandMove.metal,
      HandMove.fire,
      HandMove.water,
      HandMove.wood,
    ]) {
      final bal = controller.orbsFor(candidate);
      if (bal > bestBalance) {
        bestBalance = bal;
        surplus = candidate;
      }
    }
    if (surplus != null) {
      HandMove lowestMain = HandMove.fire;
      int lowestVal = controller.orbsFor(HandMove.fire);
      for (final target in const [
        HandMove.fire,
        HandMove.water,
        HandMove.wood,
      ]) {
        if (target == surplus) continue;
        final val = controller.orbsFor(target);
        if (val < lowestVal || lowestMain == surplus) {
          lowestVal = val;
          lowestMain = target;
        }
      }
      _transmuteSource = surplus;
      _transmuteTarget = lowestMain == surplus
          ? (surplus == HandMove.fire ? HandMove.water : HandMove.fire)
          : lowestMain;
      _stepDownFixedMultiplierIfNeeded();
    }
    _selectWing(TempleWing.transmute);
  }

  void _navigateToHallOfHeroes() {
    _stopHoldConsagration();
    controller.audio.playTapVibrate();
    _suppressBgmRestoreOnDispose = true;
    unawaited(controller.audio.playTrack(BgmTrack.royalCastle));
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
    showDialog<void>(
      context: nav.context,
      builder: (_) => RoyalCastleDialog(
        controller: controller,
        initialWing: CastleWing.hallOfHeroes,
        returnTrack: _returnBgmTrack,
      ),
    );
  }

  void _showInsufficientOrbsPrompt(LocalizationService loc) {
    controller.audio.playVibrate();
    if (!_showInsufficientOrbsInlinePrompt && mounted) {
      setState(() => _showInsufficientOrbsInlinePrompt = true);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            loc.t('string79', fallback: 'Not enough Elemental Orbs'),
          ),
          action: SnackBarAction(
            label: loc.t(
              'consagration_transform_orbs_btn',
              fallback: 'Transform Orbs',
            ),
            onPressed: () {
              if (!mounted) return;
              _switchToTransmuteFromConsagration();
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<String?> _showHeroPeakGuardDialog({required bool isHp}) {
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    final peakLevel = isHp
        ? controller.peakHpUpgradeLevel
        : controller.peakManaUpgradeLevel;
    final statName = isHp
        ? loc.t('consagration_max_hp_stat_name', fallback: 'Max HP')
        : loc.t('consagration_max_mana_stat_name', fallback: 'Max Mana Pool');
    final bodyText = loc
        .t(
          'consagration_heroes_guard_body',
          fallback:
              'Your Hall of Heroes blessing restores {stat} up to Lv. {peak} for free. Levels bought below Lv. {peak} will not stack once the blessing is restored.',
        )
        .replaceAll('{stat}', statName)
        .replaceAll('{peak}', _formatGroupedInt(peakLevel, loc));

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('consagration_heroes_guard_dialog'),
        backgroundColor: palette.dialogSurface,
        surfaceTintColor: palette.isDark ? null : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: palette.amberBorder.withValues(alpha: 0.6),
            width: 1.3,
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: palette.amberIcon,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.t(
                  'consagration_heroes_guard_title',
                  fallback: 'Unclaimed Peak Blessing!',
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.primaryText,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          bodyText,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: palette.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('consagration_heroes_guard_buy_anyway_button'),
            onPressed: () => Navigator.of(dialogContext).pop('buy_anyway'),
            child: Text(
              loc.t(
                'consagration_heroes_guard_buy_anyway',
                fallback: 'Buy Anyway',
              ),
              style: TextStyle(
                color: palette.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('consagration_heroes_guard_go_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldFill,
              foregroundColor: _goldDarkInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop('go_heroes'),
            child: Text(
              loc.t(
                'consagration_heroes_guard_go_cta',
                fallback: 'Go to Hall of Heroes',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showBatchUpgradeConfirmDialog({
    required bool isHp,
    required int levels,
    required ElementalCost totalCost,
  }) async {
    final loc = controller.localization;
    final palette = AppPalette.of(context);

    final statName = isHp
        ? loc.t('consagration_max_hp_stat_name', fallback: 'Max HP')
        : loc.t('consagration_max_mana_stat_name', fallback: 'Max Mana Pool');
    final beforeLv =
        isHp ? controller.hpUpgradeLevel : controller.manaUpgradeLevel;
    final afterLv = beforeLv + levels;
    final beforeStat =
        isHp ? controller.playerMaxHp : controller.playerMaxMana;
    final afterStat = beforeStat + levels;
    final unitWord = isHp ? 'HP' : loc.t('mana_label', fallback: 'MANA');
    final levelsGainedText = loc
        .t('consagration_confirm_levels_gained', fallback: '+{count} Levels')
        .replaceAll('{count}', _formatGroupedInt(levels, loc));
    final summaryText =
        '$levelsGainedText • Lv. ${_formatGroupedInt(beforeLv, loc)} → Lv. ${_formatGroupedInt(afterLv, loc)} • ${_formatGroupedInt(beforeStat, loc)} → ${_formatGroupedInt(afterStat, loc)} $unitWord';

    final remainingFire = math.max(0, controller.fireOrbs - totalCost.fire);
    final remainingWater = math.max(0, controller.waterOrbs - totalCost.water);
    final remainingWood = math.max(0, controller.woodOrbs - totalCost.wood);

    Widget buildOrbBreakdownRow(
      Key rowKey,
      List<(HandMove move, int amount)> items,
    ) {
      return Container(
        key: rowKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.summaryBarSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: palette.amberBorder.withValues(alpha: 0.35),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElementalEnergySphere(
                      size: 16,
                      primaryColor: items[i].$1.elementalPrimaryColor,
                      secondaryColor: items[i].$1.elementalSecondaryColor,
                      isDark: palette.isDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatGroupedInt(items[i].$2, loc),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: palette.elementalText(items[i].$1),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('consagration_confirm_dialog'),
        backgroundColor: palette.dialogSurface,
        surfaceTintColor: palette.isDark ? null : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: palette.amberBorder.withValues(alpha: 0.65),
            width: 1.4,
          ),
        ),
        title: Row(
          children: [
            const ConsagrationChaliceIcon(size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.t(
                  'consagration_confirm_title',
                  fallback: 'Confirm Batch Upgrade',
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.primaryText,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: palette.rewardedAdCardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: palette.primaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summaryText,
                    key: const ValueKey('consagration_confirm_summary'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.amberText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              loc.t(
                'consagration_confirm_total_cost',
                fallback: 'Total Orb Cost',
              ),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            buildOrbBreakdownRow(
              const ValueKey('consagration_confirm_cost'),
              [
                (HandMove.fire, totalCost.fire),
                (HandMove.water, totalCost.water),
                (HandMove.wood, totalCost.wood),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              loc.t(
                'consagration_confirm_remaining_balance',
                fallback: 'Remaining After Purchase',
              ),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            buildOrbBreakdownRow(
              const ValueKey('consagration_confirm_remaining'),
              [
                (HandMove.fire, remainingFire),
                (HandMove.water, remainingWater),
                (HandMove.wood, remainingWood),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('consagration_confirm_cancel_button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              loc.t('consagration_confirm_cancel', fallback: 'Cancel'),
              style: TextStyle(color: palette.secondaryText),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('consagration_confirm_submit_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldFill,
              foregroundColor: _goldDarkInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              loc.t('consagration_confirm_action', fallback: 'Confirm Upgrade'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  ({int levels, ElementalCost totalCost, bool isAffordable})
      _resolveConsagrationPreview({required bool isHp}) {
    final fixed = _selectedConsagrationBatch.fixedMultiplier;
    if (fixed == null) {
      final maxRes = isHp
          ? controller.maxAffordableHpUpgrade()
          : controller.maxAffordableManaUpgrade();
      if (maxRes.levels > 0) {
        return (
          levels: maxRes.levels,
          totalCost: maxRes.totalCost,
          isAffordable: true,
        );
      }
      return (
        levels: 0,
        totalCost: isHp
            ? controller.nextMaxHpUpgradeCost
            : controller.nextMaxManaUpgradeCost,
        isAffordable: false,
      );
    }
    final totalCost = isHp
        ? controller.costForMaxHpLevels(fixed)
        : controller.costForMaxManaLevels(fixed);
    return (
      levels: fixed,
      totalCost: totalCost,
      isAffordable: controller.canAfford(totalCost),
    );
  }

  Future<void> _handleConsagrationPurchaseTap({required bool isHp}) async {
    if (_didTriggerConsagrationHold) {
      _didTriggerConsagrationHold = false;
      return;
    }
    _stopHoldConsagration();
    final loc = controller.localization;
    final preview = _resolveConsagrationPreview(isHp: isHp);
    if (preview.levels <= 0 || !preview.isAffordable) {
      _showInsufficientOrbsPrompt(loc);
      return;
    }

    final isBelowPeak = isHp
        ? controller.isHpBelowUnclaimedHeroPeak
        : controller.isManaBelowUnclaimedHeroPeak;
    if (isBelowPeak) {
      final decision = await _showHeroPeakGuardDialog(isHp: isHp);
      if (!mounted) return;
      if (decision == 'go_heroes') {
        _navigateToHallOfHeroes();
        return;
      }
      if (decision != 'buy_anyway') {
        return;
      }
    }

    final needsConfirm =
        _selectedConsagrationBatch == _ConsagrationBatchOption.x100 ||
        _selectedConsagrationBatch == _ConsagrationBatchOption.max;
    if (needsConfirm) {
      final refreshed = _resolveConsagrationPreview(isHp: isHp);
      if (refreshed.levels <= 0 || !refreshed.isAffordable) {
        _showInsufficientOrbsPrompt(loc);
        return;
      }
      final confirmed = await _showBatchUpgradeConfirmDialog(
        isHp: isHp,
        levels: refreshed.levels,
        totalCost: refreshed.totalCost,
      );
      if (!mounted || !confirmed) return;
      _executeConsagrationPurchase(
        isHp: isHp,
        levels: refreshed.levels,
        isHoldTick: false,
      );
      return;
    }

    _executeConsagrationPurchase(
      isHp: isHp,
      levels: preview.levels,
      isHoldTick: false,
    );
  }

  bool _executeConsagrationPurchase({
    required bool isHp,
    required int levels,
    bool isHoldTick = false,
  }) {
    final loc = controller.localization;
    final ok = isHp
        ? controller.upgradeMaxHpBatch(levels)
        : controller.upgradeMaxManaBatch(levels);
    if (!ok) {
      if (!isHoldTick) {
        _showInsufficientOrbsPrompt(loc);
      }
      return false;
    }

    if (mounted) {
      setState(() {
        _showInsufficientOrbsInlinePrompt = false;
        _stepDownConsagrationBatchIfNeeded();
      });
    }
    unawaited(controller.audio.playConsagrationTick(throttle: isHoldTick));
    _triggerConsagrationVisualFeedback(isHp: isHp, levelsGained: levels);

    if (!isHoldTick && mounted) {
      final titleText = _consagrationCardTitle(
        isHp: isHp,
        levels: levels,
        loc: loc,
      );
      final statStr = isHp
          ? '${controller.playerMaxHp} HP (Lv. ${controller.hpUpgradeLevel})'
          : '${controller.playerMaxMana} ${loc.t('mana_label', fallback: 'Mana')} (Lv. ${controller.manaUpgradeLevel})';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$titleText: $statStr'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
    return true;
  }

  String _consagrationCardTitle({
    required bool isHp,
    required int levels,
    required LocalizationService loc,
  }) {
    if (levels == 1) {
      return isHp
          ? loc.t('upgrade_max_hp_title', fallback: '+1 Max HP')
          : loc.t('upgrade_max_mana_title', fallback: '+1 Max Mana Pool');
    }
    return loc
        .t(
          isHp ? 'upgrade_max_hp_batch_title' : 'upgrade_max_mana_batch_title',
          fallback: isHp ? '+{count} Max HP' : '+{count} Max Mana Pool',
        )
        .replaceAll('{count}', _formatGroupedInt(levels, loc));
  }

  String _consagrationCardSubtitle({
    required bool isHp,
    required int levels,
    required LocalizationService loc,
  }) {
    if (levels == 1) {
      return isHp
          ? loc.t(
              'upgrade_max_hp_desc',
              fallback:
                  "Permanently raises your Cleric's maximum HP by +1 for this campaign.",
            )
          : loc.t(
              'upgrade_max_mana_desc',
              fallback:
                  "Permanently expands your Cleric's maximum Mana Pool by +1 turn per battle.",
            );
    }
    return loc
        .t(
          isHp ? 'upgrade_max_hp_batch_desc' : 'upgrade_max_mana_batch_desc',
          fallback: isHp
              ? "Permanently raises your Cleric's maximum HP by +{count} for this campaign."
              : "Permanently expands your Cleric's maximum Mana Pool by +{count} turns per battle.",
        )
        .replaceAll('{count}', _formatGroupedInt(levels, loc));
  }

  String _consagrationStatusText({
    required bool isHp,
    required int levels,
    required LocalizationService loc,
  }) {
    final currentLv =
        isHp ? controller.hpUpgradeLevel : controller.manaUpgradeLevel;
    final currentStat =
        isHp ? controller.playerMaxHp : controller.playerMaxMana;
    final unit = isHp ? 'HP' : loc.t('mana_label', fallback: 'MANA');
    if (levels <= 0) {
      return 'Lv. $currentLv • $currentStat $unit';
    }
    if (levels == 1) {
      return 'Lv. $currentLv • $currentStat → ${currentStat + 1} $unit';
    }
    return 'Lv. $currentLv → ${currentLv + levels} • $currentStat → ${currentStat + levels} $unit';
  }

  Widget _buildConsagrationBatchSelector({
    required AppPalette palette,
    required LocalizationService loc,
    required bool canAfford10xAny,
    required bool canAfford100xAny,
  }) {
    final trackBg = palette.isDark
        ? const Color(0xFF14171F)
        : const Color(0xFFE9E0CD);
    final trackBorder = palette.amberBorder.withValues(
      alpha: palette.isDark ? 0.25 : 0.45,
    );

    bool isOptionEnabled(_ConsagrationBatchOption option) {
      switch (option) {
        case _ConsagrationBatchOption.x1:
          return true;
        case _ConsagrationBatchOption.x10:
          return canAfford10xAny;
        case _ConsagrationBatchOption.x100:
          return canAfford100xAny;
        case _ConsagrationBatchOption.max:
          return true;
      }
    }

    return Container(
      key: const ValueKey('consagration_batch_selector'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: trackBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _ConsagrationBatchOption.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 2.5),
            _buildConsagrationBatchPill(
              option: _ConsagrationBatchOption.values[i],
              palette: palette,
              loc: loc,
              isEnabled: isOptionEnabled(_ConsagrationBatchOption.values[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsagrationBatchPill({
    required _ConsagrationBatchOption option,
    required AppPalette palette,
    required LocalizationService loc,
    required bool isEnabled,
  }) {
    final isSelected = _selectedConsagrationBatch == option;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isSelected) {
      bgColor = isEnabled ? _goldFill : _goldFill.withValues(alpha: 0.45);
      borderColor = bgColor;
      textColor =
          isEnabled ? _goldDarkInk : _goldDarkInk.withValues(alpha: 0.72);
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
                  _stopHoldConsagration();
                  controller.audio.playTapVibrate();
                  setState(() {
                    _selectedConsagrationBatch = option;
                    _showInsufficientOrbsInlinePrompt = false;
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(6.5),
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6.5),
              border: Border.all(color: borderColor, width: 0.9),
            ),
            alignment: Alignment.center,
            child: Text(
              option.label(loc),
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroesPeakWarningBanner(
    AppPalette palette,
    LocalizationService loc,
  ) {
    final hpBelow = controller.isHpBelowUnclaimedHeroPeak;
    final manaBelow = controller.isManaBelowUnclaimedHeroPeak;
    final String bodyText;
    if (hpBelow && manaBelow) {
      bodyText = loc
          .t(
            'consagration_heroes_banner_both',
            fallback:
                'Restore HP up to Lv. {hp} and Mana up to Lv. {mana} in the Royal Castle without spending orbs.',
          )
          .replaceAll('{hp}', '${controller.peakHpUpgradeLevel}')
          .replaceAll('{mana}', '${controller.peakManaUpgradeLevel}');
    } else if (hpBelow) {
      bodyText = loc
          .t(
            'consagration_heroes_banner_hp',
            fallback:
                'Restore HP up to Lv. {hp} in the Royal Castle without spending orbs.',
          )
          .replaceAll('{hp}', '${controller.peakHpUpgradeLevel}');
    } else {
      bodyText = loc
          .t(
            'consagration_heroes_banner_mana',
            fallback:
                'Restore Mana up to Lv. {mana} in the Royal Castle without spending orbs.',
          )
          .replaceAll('{mana}', '${controller.peakManaUpgradeLevel}');
    }

    return Container(
      key: const ValueKey('consagration_heroes_warning_banner'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.rewardedAdCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.amberBorder.withValues(alpha: 0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: palette.amberIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t(
                    'consagration_heroes_banner_title',
                    fallback: 'Unclaimed Hall of Heroes Blessing',
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: palette.amberText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bodyText,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: palette.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: const ValueKey('consagration_heroes_banner_button'),
            onPressed: _navigateToHallOfHeroes,
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldFill,
              foregroundColor: _goldDarkInk,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              loc.t('consagration_heroes_banner_cta', fallback: 'Hall of Heroes'),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

    final canAfford10xAny =
        controller.canAffordMaxHpLevels(10) ||
        controller.canAffordMaxManaLevels(10);
    final canAfford100xAny =
        controller.canAffordMaxHpLevels(100) ||
        controller.canAffordMaxManaLevels(100);

    final hpPreview = _resolveConsagrationPreview(isHp: true);
    final manaPreview = _resolveConsagrationPreview(isHp: false);

    final showTransformPrompt =
        _showInsufficientOrbsInlinePrompt ||
        (_selectedConsagrationBatch == _ConsagrationBatchOption.max &&
            (hpPreview.levels == 0 || manaPreview.levels == 0));

    final isHoldBatch =
        _selectedConsagrationBatch == _ConsagrationBatchOption.x1 ||
        _selectedConsagrationBatch == _ConsagrationBatchOption.x10;

    return SingleChildScrollView(
      key: const ValueKey('temple_wing_consagration'),
      controller: _wingScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loc.t(
                      'temple_wing_consagration_title',
                      fallback: 'Consagration Room',
                    ),
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: palette.primaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _buildConsagrationBatchSelector(
                    palette: palette,
                    loc: loc,
                    canAfford10xAny: canAfford10xAny,
                    canAfford100xAny: canAfford100xAny,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (controller.hasUnclaimedHeroPeakWarning)
            _buildHeroesPeakWarningBanner(palette, loc),
          if (showTransformPrompt)
            Container(
              key: const ValueKey('consagration_transform_prompt'),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.summaryBarSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: palette.amberIcon,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      loc.t(
                        'consagration_transform_orbs_hint',
                        fallback:
                            'Need Fire, Water, or Wood orbs? Convert surplus Earth & Metal orbs.',
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    key: const ValueKey('consagration_transform_orbs_button'),
                    style: TextButton.styleFrom(
                      backgroundColor: _goldFill,
                      foregroundColor: _goldDarkInk,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      minimumSize: const Size(0, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _switchToTransmuteFromConsagration,
                    child: Text(
                      loc.t(
                        'consagration_transform_orbs_btn',
                        fallback: 'Transform Orbs',
                      ),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _InfiniteStatUpgradeTile(
            cardKey: const ValueKey('shop_upgrade_max_hp_card'),
            buttonKey: const ValueKey('shop_upgrade_max_hp_button'),
            adButtonKey: const ValueKey('consagration_hp_watch_ad_button'),
            floatingGainKey: const ValueKey('consagration_hp_floating_gain'),
            iconWidget: const VitalityHeartIcon(size: 46),
            title: _consagrationCardTitle(
              isHp: true,
              levels: hpPreview.levels,
              loc: loc,
            ),
            subtitle: _consagrationCardSubtitle(
              isHp: true,
              levels: hpPreview.levels,
              loc: loc,
            ),
            statusText: _consagrationStatusText(
              isHp: true,
              levels: hpPreview.levels,
              loc: loc,
            ),
            actionLabel: loc.t('stat_upgrade_action_label', fallback: 'Upgrade'),
            cost: hpPreview.totalCost,
            formatThousands: true,
            numberLocale: loc.currentLanguage,
            isAffordable: hpPreview.isAffordable,
            showAdButton: !isRemoveAds,
            adButtonLabel: adButtonLabel,
            canWatchAd: canWatchAd,
            feedbackAnimation: _hpFeedbackController,
            floatingGainText: _hpFloatingGainText,
            onHoldStart: isHoldBatch && !controller.isHpBelowUnclaimedHeroPeak
                ? () => _startHoldConsagration(true)
                : null,
            onHoldEnd: _stopHoldConsagration,
            onPurchase: () => _handleConsagrationPurchaseTap(isHp: true),
            onWatchAd: () {
              _stopHoldConsagration();
              controller.watchAdToUpgradeMaxHp(
                onUpgraded: () {
                  _triggerConsagrationVisualFeedback(
                    isHp: true,
                    levelsGained: 1,
                  );
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
            floatingGainKey: const ValueKey('consagration_mana_floating_gain'),
            iconWidget: const ManaDropIcon(size: 46),
            title: _consagrationCardTitle(
              isHp: false,
              levels: manaPreview.levels,
              loc: loc,
            ),
            subtitle: _consagrationCardSubtitle(
              isHp: false,
              levels: manaPreview.levels,
              loc: loc,
            ),
            statusText: _consagrationStatusText(
              isHp: false,
              levels: manaPreview.levels,
              loc: loc,
            ),
            actionLabel: loc.t('stat_upgrade_action_label', fallback: 'Upgrade'),
            cost: manaPreview.totalCost,
            formatThousands: true,
            numberLocale: loc.currentLanguage,
            isAffordable: manaPreview.isAffordable,
            showAdButton: !isRemoveAds,
            adButtonLabel: adButtonLabel,
            canWatchAd: canWatchAd,
            feedbackAnimation: _manaFeedbackController,
            floatingGainText: _manaFloatingGainText,
            onHoldStart: isHoldBatch && !controller.isManaBelowUnclaimedHeroPeak
                ? () => _startHoldConsagration(false)
                : null,
            onHoldEnd: _stopHoldConsagration,
            onPurchase: () => _handleConsagrationPurchaseTap(isHp: false),
            onWatchAd: () {
              _stopHoldConsagration();
              controller.watchAdToUpgradeMaxMana(
                onUpgraded: () {
                  _triggerConsagrationVisualFeedback(
                    isHp: false,
                    levelsGained: 1,
                  );
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
            const SizedBox(height: 6),
            Container(
              key: const ValueKey('consagration_ad_disclosure_box'),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: palette.rewardedAdCardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.rewardedAdCardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.ondemand_video_rounded,
                    size: 16,
                    color: palette.amberIcon,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      loc.t(
                        'temple_consagration_ad_disclosure',
                        fallback:
                            'Rewarded Video Ad: watch an ad to gain +1 permanent Max HP or Max Mana level (up to 3 per campaign week).',
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        color: palette.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    key: const ValueKey('consagration_weekly_ad_counter'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.dialogSurface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      '$remainingAds / ${GameController.maxWeeklyAdConsagrations} ${loc.t('temple_consagration_weekly_left', fallback: 'Ad Lv/Wk')}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
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
      controller: _wingScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 4),
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
          iconWidget: const PredictabilityScoreIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.predictability,
              title: loc.t('string38', fallback: 'Predictability Score'),
              description: loc.t(
                'predictability_score_desc',
                fallback:
                    'Unlocks Match Scoreboard (Your Score, PC Score, Total) & Predictability Gauge %',
              ),
              sacrificedCost: GameController.costPredictability,
              onConfirmUnlock: controller.unlockPredictability,
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
          iconWidget: const ResetButtonIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.reset,
              title: loc.t('string37', fallback: 'Reset Button'),
              description: loc.t(
                'reset_button_desc',
                fallback:
                    'Adds a Reset button to clear the current match and Markov matrix anytime',
              ),
              sacrificedCost: GameController.costReset,
              onConfirmUnlock: controller.unlockReset,
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
          iconWidget: const NewHandsIcon(size: 32),
          title: loc.t('string56', fallback: 'Learn Earth & Metal'),
          subtitle: loc.t(
            'new_hands_desc',
            fallback:
                'Unlocks Earth & Metal elements for an expanded 5-element battle matrix',
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
          iconWidget: const RandomButtonIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.random,
              title: loc.t('string39', fallback: 'Random Move Button'),
              description: loc.t(
                'random_button_desc',
                fallback:
                    'Adds a Random button to play unpredictable moves and outsmart the AI',
              ),
              sacrificedCost: GameController.costRandom,
              onConfirmUnlock: controller.unlockRandom,
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
        _OverchargedStaffShopTile(
          key: const ValueKey('shop_overcharged_staff_card'),
          iconWidget: const OverchargedStaffIcon(size: 32),
          title: loc.t('overcharged_staff_title', fallback: 'Overcharged Staff'),
          subtitle: loc.t(
            'overcharged_staff_desc',
            fallback:
                'Hold any element or Random to unleash rapid-fire attacks (1x–30x), with auto-stop safety at 5 HP or less.',
          ),
          level: controller.overchargedStaffLevel,
          isActive: controller.overchargedStaffEnabled,
          selectedSpeed: controller.overchargedStaffSelectedSpeed,
          nextCost: controller.nextOverchargedStaffUpgradeCost,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          unlockLabel: loc.t(
            'overcharged_staff_unlock_action',
            fallback: 'Unlock',
          ),
          levelPrefix: loc.t('overcharged_staff_level_prefix', fallback: 'Lv.'),
          maxBadgeLabel: loc.t('overcharged_staff_max_badge', fallback: 'MAX'),
          speedSectionLabel: loc.t(
            'overcharged_staff_speed_label',
            fallback: 'Fire Speed',
          ),
          onUnlockOrUpgrade: () {
            final nextCost = controller.nextOverchargedStaffUpgradeCost;
            if (nextCost == null) {
              controller.audio.playVibrate();
              return;
            }
            final targetLv = controller.overchargedStaffLevel + 1;
            final staffTitle = loc.t(
              'overcharged_staff_title',
              fallback: 'Overcharged Staff',
            );
            final staffDesc = loc.t(
              'overcharged_staff_desc',
              fallback:
                  'Hold any element or Random to unleash rapid-fire attacks (1x–30x), with auto-stop safety at 5 HP or less.',
            );
            final lvPrefix = loc.t(
              'overcharged_staff_level_prefix',
              fallback: 'Lv.',
            );
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.overchargedStaff,
              title: staffTitle,
              description: staffDesc,
              sacrificedCost: nextCost,
              badgeLabel: '$lvPrefix $targetLv',
              onConfirmUnlock: controller.unlockOrUpgradeOverchargedStaff,
            );
          },
          onToggle: (val) {
            controller.toggleOverchargedStaff(val);
            _handleToggle(
              context,
              loc.t('overcharged_staff_title', fallback: 'Overcharged Staff'),
              val,
            );
          },
          onSelectSpeed: (speed) {
            final ok = controller.selectOverchargedStaffSpeed(speed);
            if (ok) {
              controller.audio.playTapVibrate();
            }
          },
        ),
        _buildShopItem(
          context: context,
          iconWidget: const MarkovMatrixIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.algorithm,
              title: loc.t('string40', fallback: 'Show Markov Algorithm'),
              description: loc.t(
                'show_algorithm_desc',
                fallback:
                    'Reveals the live Markov Transition Matrix tracking your move patterns',
              ),
              sacrificedCost: GameController.costAlgorithm,
              onConfirmUnlock: controller.unlockAlgorithm,
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
          iconWidget: const YourPredictionIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.yourPrediction,
              title: loc.t('string41', fallback: 'Your Prediction Hint'),
              description: loc.t(
                'your_prediction_desc',
                fallback:
                    'Displays the move(s) the AI predicts you will play next',
              ),
              sacrificedCost: GameController.costYourPrediction,
              onConfirmUnlock: controller.unlockYourPrediction,
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
          iconWidget: const EnemyNextMoveIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.nextMove,
              title: loc.t('string42', fallback: 'PC Next Move Reveal'),
              description: loc.t(
                'pc_next_move_desc',
                fallback:
                    'Reveals the move(s) the AI is preparing to play against you',
              ),
              sacrificedCost: GameController.costNextMove,
              onConfirmUnlock: controller.unlockNextMove,
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
          iconWidget: const GiftBoxIcon(size: 32),
          title: loc.t('gift_box', fallback: 'Gift Box'),
          subtitle: controller.giftBoxDescription,
          cost: GameController.costGiftBox,
          productId: null,
          isUnlocked: controller.giftBoxUnlocked,
          isActive: controller.giftBoxEnabled,
          enabledLabel: enabledStr,
          disabledLabel: disabledStr,
          onUnlock: () {
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.giftBox,
              title: loc.t('gift_box', fallback: 'Gift Box'),
              description: controller.giftBoxDescription,
              sacrificedCost: GameController.costGiftBox,
              onConfirmUnlock: controller.unlockGiftBox,
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
          iconWidget: const StrategySuggestionIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.suggestion,
              title: loc.t('string43', fallback: 'Optimal Suggestion'),
              description: loc.t(
                'suggestion_desc',
                fallback:
                    "Recommends the optimal counter-move(s) to beat the AI's next play",
              ),
              sacrificedCost: GameController.costSuggestion,
              onConfirmUnlock: controller.unlockSuggestion,
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
          iconWidget: const NewSkinIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.newSkin,
              title: loc.t('new_skin', fallback: 'New Skin'),
              description: loc.t(
                'new_skin_desc',
                fallback: 'Hands Theme (Rock, Paper, Scissors)',
              ),
              sacrificedCost: GameController.costNewSkin,
              onConfirmUnlock: controller.unlockNewSkin,
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
          iconWidget: const CrystalBallIcon(size: 32),
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
            _handleOfferingPurchase(
              context: context,
              artifact: ShopUpgradeArtifact.crystalBall,
              title: loc.t('string80', fallback: 'Crystal Ball'),
              description: loc.t(
                'crystal_ball_desc',
                fallback:
                    'Reveals the exact next move the AI will play before you choose',
              ),
              sacrificedCost: GameController.costCrystalBall,
              onConfirmUnlock: controller.unlockCrystalBall,
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
            iconWidget: const CrystalBallPlusIcon(size: 32),
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
              _handleOfferingPurchase(
                context: context,
                artifact: ShopUpgradeArtifact.crystalBallPlus,
                title: loc.t('string82', fallback: 'Crystal Ball+'),
                description: loc.t(
                  'crystal_ball_plus_desc',
                  fallback:
                      'Upgrades Crystal Ball to guarantee 100% foresight on every single round',
                ),
                sacrificedCost: GameController.costCrystalBallPlus,
                canPurchase: controller.unlockedCrystalBall,
                onConfirmUnlock: controller.unlockCrystalBallPlus,
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
            iconWidget: const MarkovRecalibratorIcon(size: 32),
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
              _handleOfferingPurchase(
                context: context,
                artifact: ShopUpgradeArtifact.markovRecalibrator,
                title: loc.t(
                  'markov_recalibrator_title',
                  fallback: 'Markov Recalibrator',
                ),
                description: loc.t(
                  'markov_recalibrator_desc',
                  fallback:
                      'Reconfigures the Algorithm matrix and hints to expose the Robot Archmage\'s true 1-step short-term memory',
                ),
                sacrificedCost: GameController.costMarkovRecalibrator,
                canPurchase: controller.isMarkovRecalibratorVisibleInShop,
                onConfirmUnlock: controller.unlockMarkovRecalibrator,
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
        if (!(controller.isRemoveAdsOwned && controller.isRemoveAdsEnabled))
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: InkWell(
              key: const ValueKey('offerings_remove_ads_prayer_hint'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => _selectWing(TempleWing.prayer),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: palette.rewardedAdCardSurface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.amberBorder.withValues(
                      alpha: palette.isDark ? 0.30 : 0.45,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RemoveAdsIcon(
                      size: 20,
                      isActive: controller.isRemoveAdsActive,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        loc.t(
                          'temple_offerings_vow_hint',
                          fallback:
                              'Looking for Remove Ads? Visit the Prayer Room →',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.amberText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      controller: _wingScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.t('temple_transmute_title', fallback: 'Holy Transformation'),
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
                  'Transform 3 surplus Elemental Orbs of one element into 1 Elemental Orb of another.',
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
                      flex: 3,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TransformationMiracleIcon(size: 22),
                          const SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                loc.t(
                                  'temple_transmute_rate_label',
                                  fallback: '3 → 1 Exchange',
                                ),
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: palette.primaryText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      flex: 2,
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
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                loc.t(
                                  'castle_alchemy_tap_hint',
                                  fallback: 'Tap orbs to switch',
                                ),
                                maxLines: 1,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: palette.mutedText,
                                ),
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
                    fallback: 'Tip: Press & hold Exchange for rapid transformation.',
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

    return SingleChildScrollView(
      key: const ValueKey('temple_wing_adoration'),
      controller: _wingScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              iconWidget: ConsumableOrbBundleIcon(bundle: bundle, size: 28),
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
      ),
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
    final pendingBlessings = <SacredBlessing>[
      for (final b in SacredBlessing.values)
        if (controller.isBlessingPending(b)) b,
    ];
    final hasAnyPending = pendingBlessings.isNotEmpty;
    final allPending = controller.areAllBattleBlessingsPending;
    final isRemoveAds = controller.isRemoveAdsActive;
    final hasDailyFree = controller.hasFreeDailyPrayerAvailable();

    final perkBannerText = loc.t(
      'temple_blessing_perk_ready',
      fallback:
          'Remove Ads Perk: Activate any or all blessings freely before battle.',
    );
    final activeNames = pendingBlessings
        .map((b) => loc.t(b.titleKey, fallback: b.fallbackTitle))
        .join(', ');
    final activeSummaryText = hasAnyPending
        ? '${loc.t('temple_blessing_active_next', fallback: 'Active for Next Battle')} (${pendingBlessings.length}/${SacredBlessing.values.length}): $activeNames'
        : null;

    final String? primaryAmberLine;
    final String? secondaryLine;
    final bool useGreenBannerStyle;

    if (allPending) {
      primaryAmberLine = null;
      secondaryLine = activeSummaryText;
      useGreenBannerStyle = true;
    } else if (isRemoveAds) {
      primaryAmberLine = perkBannerText;
      secondaryLine = activeSummaryText;
      useGreenBannerStyle = false;
    } else if (hasAnyPending) {
      primaryAmberLine = hasDailyFree
          ? loc.t(
              'temple_blessing_daily_free_ready',
              fallback: '1 Free Daily Prayer available today!',
            )
          : loc.t(
              'temple_blessing_stack_more_ad',
              fallback: 'Watch an ad to stack additional blessings.',
            );
      secondaryLine = activeSummaryText;
      useGreenBannerStyle = true;
    } else {
      primaryAmberLine = hasDailyFree
          ? loc.t(
              'temple_blessing_daily_free_ready',
              fallback: '1 Free Daily Prayer available today!',
            )
          : loc.t(
              'temple_blessing_ad_only_ready',
              fallback:
                  'Daily free prayer used — watch an ad to receive a blessing.',
            );
      secondaryLine = null;
      useGreenBannerStyle = false;
    }

    return SingleChildScrollView(
      key: const ValueKey('temple_wing_prayer'),
      controller: _wingScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

          // Pinned at the very top of Prayer Room so toggling never shifts its vertical position
          _buildVowOfSilenceCard(context, palette, loc),
          const SizedBox(height: 8),

          // Meditation for Free Orbs (Watch Ad +50 Orbs), smoothly collapses when Vow of Silence is ON
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
              color: useGreenBannerStyle
                  ? palette.successText.withValues(alpha: 0.12)
                  : palette.rewardedAdCardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: useGreenBannerStyle
                    ? palette.successText.withValues(alpha: 0.45)
                    : palette.rewardedAdCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (primaryAmberLine != null && !useGreenBannerStyle)
                  Text(
                    primaryAmberLine,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.amberText,
                    ),
                  ),
                if (secondaryLine != null) ...[
                  if (primaryAmberLine != null && !useGreenBannerStyle)
                    const SizedBox(height: 3),
                  Text(
                    secondaryLine,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.successText,
                    ),
                  ),
                ],
                if (primaryAmberLine != null && useGreenBannerStyle) ...[
                  const SizedBox(height: 3),
                  Text(
                    primaryAmberLine,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: palette.amberText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          for (final blessing in SacredBlessing.values)
            Builder(
              builder: (context) {
                final isThisActive = controller.isBlessingPending(blessing);
                final canFreeForThis =
                    controller.canActivateSpecificBlessingFree(blessing);
                final canAdForThis =
                    controller.canActivateSpecificBlessingWithAd(blessing);
                return _SacredBlessingCard(
                  key: ValueKey('temple_blessing_card_${blessing.id}'),
                  buttonKey: ValueKey('temple_blessing_pray_button_${blessing.id}'),
                  blessing: blessing,
                  title: loc.t(blessing.titleKey, fallback: blessing.fallbackTitle),
                  description:
                      loc.t(blessing.descKey, fallback: blessing.fallbackDesc),
                  isThisActive: isThisActive,
                  canFreePray: canFreeForThis,
                  canAdPray: canAdForThis,
                  activeLabel: loc.t(
                    'temple_blessing_active_badge',
                    fallback: 'Active',
                  ),
                  freePrayLabel: isRemoveAds
                      ? loc.t(
                          'temple_blessing_pray_perk',
                          fallback: 'Bless (Perk)',
                        )
                      : loc.t(
                          'temple_blessing_pray_free',
                          fallback: 'Pray (Free)',
                        ),
                  adPrayLabel: loc.t(
                    'temple_blessing_pray_ad',
                    fallback: 'Watch Ad: Pray',
                  ),
                  palette: palette,
                  onTap: () {
                    if (canFreeForThis) {
                      final ok =
                          controller.activateSacredBlessingFree(blessing);
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
                    } else if (canAdForThis) {
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
                );
              },
            ),
          if (!isRemoveAds && !hasDailyFree && !allPending) ...[
            const SizedBox(height: 6),
            Text(
              loc.t(
                'temple_blessing_ad_disclosure',
                fallback:
                    'Rewarded Video Ad: watch an ad to activate each temporary blessing for your next battle. Blessings can be stacked.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: palette.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVowOfSilenceCard(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final isOwned = controller.isRemoveAdsOwned;
    final isSilenceOn = controller.isRemoveAdsActive;
    final billing = controller.billingService;
    const productId = BillingService.productRemoveAds;
    final localizedPrice = billing.getLocalizedPrice(productId);
    final hasRealMoneyPrice =
        localizedPrice != null && localizedPrice.trim().isNotEmpty;
    final isPending = billing.isPurchasePending(productId);
    final isLoadingStore = billing.isLoadingProducts;
    final title = loc.t(
      'vow_of_silence_title',
      fallback: 'Vow of Silence — Remove Ads',
    );
    final activeColor = palette.successIcon;
    final inactiveColor = palette.isDark ? Colors.grey : palette.mutedText;

    void handleOrbUnlock() {
      final ok = controller.unlockAds();
      _handleUnlock(context, title, ok);
    }

    void handleToggle(bool val) {
      controller.toggleRemoveAds(val);
      _handleToggle(context, title, val);
    }

    return Container(
      key: const ValueKey('vow_of_silence_card'),
      decoration: BoxDecoration(
        color: palette.isDark
            ? const Color(0xFF1E222B)
            : palette.shopTileSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOwned && isSilenceOn
              ? activeColor.withValues(alpha: palette.isDark ? 0.55 : 0.65)
              : palette.amberBorder.withValues(
                  alpha: palette.isDark ? 0.35 : 0.55,
                ),
          width: isOwned && isSilenceOn ? 1.3 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isOwned ? () => handleToggle(!isSilenceOn) : handleOrbUnlock,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: isOwned
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSilenceOn
                              ? activeColor.withValues(
                                  alpha: palette.isDark ? 0.16 : 0.12,
                                )
                              : palette.amberBorder.withValues(
                                  alpha: palette.isDark ? 0.12 : 0.14,
                                ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSilenceOn
                                ? activeColor.withValues(alpha: 0.45)
                                : palette.amberBorder.withValues(alpha: 0.35),
                          ),
                        ),
                        child: RemoveAdsIcon(
                          size: 28,
                          isActive: isSilenceOn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: palette.primaryText,
                                  ),
                                ),
                                Container(
                                  key: const ValueKey(
                                    'vow_of_silence_permanent_badge',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _goldFill.withValues(
                                      alpha: palette.isDark ? 0.22 : 0.32,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _goldFill.withValues(alpha: 0.75),
                                    ),
                                  ),
                                  child: Text(
                                    loc.t(
                                      'vow_of_silence_permanent_badge',
                                      fallback: 'Permanent',
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: palette.isDark
                                          ? _goldFill
                                          : const Color(0xFF6B4700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1.5),
                                  child: Icon(
                                    isSilenceOn
                                        ? Icons.check_circle
                                        : Icons.pause_circle_outline_rounded,
                                    size: 13,
                                    color: isSilenceOn
                                        ? activeColor
                                        : inactiveColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isSilenceOn
                                        ? loc.t(
                                            'vow_of_silence_status_on',
                                            fallback:
                                                'Sanctuary in Silence — All ad prompts muted',
                                          )
                                        : loc.t(
                                            'vow_of_silence_status_off',
                                            fallback:
                                                'Silence Paused — Ad prompts active',
                                          ),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isSilenceOn
                                          ? activeColor
                                          : inactiveColor,
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
                        key: const ValueKey('vow_of_silence_switch'),
                        value: isSilenceOn,
                        onChanged: handleToggle,
                        activeTrackColor: activeColor,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: palette.amberBorder.withValues(
                                alpha: palette.isDark ? 0.14 : 0.16,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: palette.amberBorder.withValues(
                                  alpha: 0.40,
                                ),
                              ),
                            ),
                            child: const RemoveAdsIcon(
                              size: 28,
                              isActive: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: palette.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  loc.t(
                                    'vow_of_silence_locked_desc',
                                    fallback:
                                        'Permanently silences all banner and video ad prompts across the entire app. Never resets across journeys.',
                                  ),
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.amberSubtitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            loc.t(
                              'overcharged_staff_unlock_action',
                              fallback: 'Unlock',
                            ),
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
                                key: const ValueKey(
                                  'diamond_unlock_${BillingService.productRemoveAds}',
                                ),
                                onPressed:
                                    isPending ? null : handleOrbUnlock,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette.isDark
                                      ? null
                                      : palette.dialogSurface,
                                  elevation: palette.isDark ? null : 1,
                                  side: palette.isDark
                                      ? null
                                      : BorderSide(
                                          color: palette.sandCardBorder,
                                        ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  minimumSize: const Size(52, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: _ElementalCostPillRow(
                                  entries: GameController
                                      .costRemoveAds.nonZeroEntries,
                                  palette: palette,
                                ),
                              ),
                              OutlinedButton(
                                key: const ValueKey(
                                  'real_money_unlock_${BillingService.productRemoveAds}',
                                ),
                                onPressed: (!isPending &&
                                        !isLoadingStore &&
                                        hasRealMoneyPrice)
                                    ? () => controller.buyWithRealMoney(
                                          productId,
                                        )
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.isDark
                                      ? null
                                      : palette.primaryText,
                                  disabledForegroundColor: palette.isDark
                                      ? null
                                      : palette.mutedText,
                                  backgroundColor: palette.isDark
                                      ? null
                                      : palette.dialogSurface,
                                  side: palette.isDark
                                      ? null
                                      : BorderSide(
                                          color: palette.amberBorder
                                              .withValues(alpha: 0.65),
                                        ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  minimumSize: const Size(52, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: (isPending || isLoadingStore)
                                    ? const SizedBox(
                                        key: ValueKey(
                                          'purchase_loading_indicator',
                                        ),
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        hasRealMoneyPrice
                                            ? localizedPrice
                                            : loc.t(
                                                'temple_price_unavailable',
                                                fallback: 'Unavailable',
                                              ),
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

  Widget _buildShopItem({
    required BuildContext context,
    Widget? iconWidget,
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
      iconWidget: iconWidget,
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

  // ---------------------------------------------------------------------------
  // WING 6: OFFERTORY (GAZOFILÁCIO — PERMANENT IDLE ORB GENERATOR)
  // ---------------------------------------------------------------------------

  String _formatOffertoryDuration(Duration d) {
    final totalSeconds = math.max(0, d.inSeconds);
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  String _formatRateValue(double value, LocalizationService loc) {
    if (value <= 0) return '0';
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.005) {
      return _formatGroupedInt(rounded.toInt(), loc);
    }
    final formatted = value.toStringAsFixed(1);
    return loc.currentLanguage == 'en'
        ? formatted
        : formatted.replaceAll('.', ',');
  }

  void _triggerOffertoryFlyingOrbs(int grantedPerElement) {
    if (!mounted || grantedPerElement <= 0) return;
    if (!controller.animationsEnabled) return;
    setState(() {
      _offertoryFlyingMoves = List<HandMove>.from(
        controller.offertoryActiveElements,
      );
      _offertoryFloatingCollectAmount = grantedPerElement;
    });
    _offertoryFlyController.forward(from: 0.0);
  }

  Offset _resolveRelativeCenter(GlobalKey key, Offset fallback) {
    final stackBox =
        _dialogStackKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null ||
        targetBox == null ||
        !stackBox.hasSize ||
        !targetBox.hasSize) {
      return fallback;
    }
    final globalCenter = targetBox.localToGlobal(
      targetBox.size.center(Offset.zero),
    );
    return stackBox.globalToLocal(globalCenter);
  }

  Widget _buildOffertoryFlyingOrbsOverlay(AppPalette palette) {
    return AnimatedBuilder(
      animation: _offertoryFlyController,
      builder: (context, _) {
        final raw = _offertoryFlyController.value;
        if (raw <= 0.0 || raw >= 1.0 || _offertoryFlyingMoves.isEmpty) {
          return const SizedBox.shrink();
        }
        final stackBox =
            _dialogStackKey.currentContext?.findRenderObject() as RenderBox?;
        final stackSize = stackBox?.size ?? const Size(340, 560);
        final origin = _resolveRelativeCenter(
          _offertoryVaultAnchorKey,
          Offset(stackSize.width * 0.5, stackSize.height * 0.48),
        );

        final moves = _offertoryFlyingMoves;
        final children = <Widget>[];

        for (int idx = 0; idx < moves.length; idx++) {
          final move = moves[idx];
          final stagger = idx * 0.06;
          final localT = ((raw - stagger) / (1.0 - stagger)).clamp(0.0, 1.0);
          if (localT <= 0.0 || localT >= 1.0) continue;
          final curved = Curves.easeInOutCubic.transform(localT);
          final target = _resolveRelativeCenter(
            _headerOrbKeys[move]!,
            Offset(
              stackSize.width * (0.18 + idx * 0.16),
              stackSize.height * 0.24,
            ),
          );
          final spreadX = (idx - (moves.length - 1) * 0.5) * 26.0;
          final control = Offset(
            (origin.dx + target.dx) * 0.5 + spreadX,
            math.min(origin.dy, target.dy) - 42.0,
          );
          Offset bezier(double t) {
            final mt = 1.0 - t;
            return Offset(
              mt * mt * origin.dx + 2 * mt * t * control.dx + t * t * target.dx,
              mt * mt * origin.dy + 2 * mt * t * control.dy + t * t * target.dy,
            );
          }

          final pos = bezier(curved);
          final scale = 1.15 - 0.25 * curved;

          // Subtle glowing trail particles along the parabolic arc
          for (int trail = 1; trail <= 3; trail++) {
            final tt = (curved - trail * 0.055).clamp(0.0, 1.0);
            if (tt <= 0.0) continue;
            final tp = bezier(tt);
            final r = 5.5 - trail * 1.1;
            children.add(
              Positioned(
                left: tp.dx - r,
                top: tp.dy - r,
                child: Container(
                  width: r * 2,
                  height: r * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: move.elementalPrimaryColor.withValues(
                      alpha: (0.45 - trail * 0.10).clamp(0.08, 0.5),
                    ),
                  ),
                ),
              ),
            );
          }

          children.add(
            Positioned(
              left: pos.dx - 11 * scale,
              top: pos.dy - 11 * scale,
              child: ElementalEnergySphere(
                key: ValueKey('offertory_flying_orb_${move.orbKey}'),
                size: 22 * scale,
                primaryColor: move.elementalPrimaryColor,
                secondaryColor: move.elementalSecondaryColor,
                isDark: palette.isDark,
              ),
            ),
          );
        }

        if (_offertoryFloatingCollectAmount > 0) {
          final floatOpacity = (1.0 - raw).clamp(0.0, 1.0);
          children.add(
            Positioned(
              left: (origin.dx - 44).clamp(8.0, stackSize.width - 96),
              top: origin.dy - 24 - 30 * raw,
              child: Opacity(
                opacity: floatOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _goldFill,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '+${_formatGroupedInt(_offertoryFloatingCollectAmount, controller.localization)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _goldDarkInk,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          key: const ValueKey('offertory_flying_orbs_overlay'),
          clipBehavior: Clip.none,
          children: children,
        );
      },
    );
  }

  ({int levels, ElementalCost totalCost, bool isAffordable})
      _resolveOffertoryUpgradePreview() {
    final fixed = _selectedOffertoryBatch.fixedMultiplier;
    if (fixed == null) {
      final maxRes = controller.maxAffordableOffertoryUpgrade();
      if (maxRes.levels > 0) {
        return (
          levels: maxRes.levels,
          totalCost: maxRes.totalCost,
          isAffordable: true,
        );
      }
      return (
        levels: 1,
        totalCost: controller.nextOffertoryUpgradeCost,
        isAffordable: false,
      );
    }
    final cost = controller.offertoryCostForLevels(fixed);
    return (
      levels: fixed,
      totalCost: cost,
      isAffordable: controller.canAfford(cost),
    );
  }

  ({int levels, ElementalCost totalCost, bool isAffordable})
      _resolveOffertoryCapUpgradePreview() {
    final fixed = _selectedOffertoryCapBatch.fixedMultiplier;
    if (fixed == null) {
      final maxRes = controller.maxAffordableOffertoryCapUpgrade();
      if (maxRes.levels > 0) {
        return (
          levels: maxRes.levels,
          totalCost: maxRes.totalCost,
          isAffordable: true,
        );
      }
      return (
        levels: 1,
        totalCost: controller.nextOffertoryCapUpgradeCost,
        isAffordable: false,
      );
    }
    final cost = controller.offertoryCapCostForLevels(fixed);
    return (
      levels: fixed,
      totalCost: cost,
      isAffordable: controller.canAfford(cost),
    );
  }

  void _stepDownOffertoryBatchIfNeeded() {
    if (_selectedOffertoryBatch == _OffertoryBatchOption.x10 &&
        !controller.canAffordOffertoryLevels(10)) {
      _selectedOffertoryBatch = _OffertoryBatchOption.x1;
    }
    if (_selectedOffertoryCapBatch == _OffertoryBatchOption.x10 &&
        !controller.canAffordOffertoryCapUpgrade(levels: 10)) {
      _selectedOffertoryCapBatch = _OffertoryBatchOption.x1;
    }
  }

  Future<bool> _showOffertoryMaxConfirmDialog({
    required int levels,
    required ElementalCost totalCost,
    bool isCapUpgrade = false,
  }) async {
    final loc = controller.localization;
    final palette = AppPalette.of(context);
    final beforeLv = isCapUpgrade
        ? controller.offertoryCapLevel
        : controller.offertoryRateLevel;
    final afterLv = beforeLv + levels;
    final activeMoves = controller.offertoryActiveElements;

    final levelsGainedText = loc
        .t('consagration_confirm_levels_gained', fallback: '+{count} Levels')
        .replaceAll('{count}', _formatGroupedInt(levels, loc));
    final String statDeltaText;
    if (isCapUpgrade) {
      final beforeCap = GameController.formatOffertoryCapMinutes(
        GameController.offertoryCapMinutesForLevel(beforeLv),
      );
      final afterCap = GameController.formatOffertoryCapMinutes(
        GameController.offertoryCapMinutesForLevel(afterLv),
      );
      statDeltaText = '$beforeCap → $afterCap';
    } else {
      final beforeRate = controller.offertoryHourlyRate(level: beforeLv);
      final afterRate = controller.offertoryHourlyRate(level: afterLv);
      statDeltaText =
          '+${_formatRateValue(beforeRate, loc)}/h → +${_formatRateValue(afterRate, loc)}/h';
    }
    final summaryText =
        '$levelsGainedText • Lv. ${_formatGroupedInt(beforeLv, loc)} → Lv. ${_formatGroupedInt(afterLv, loc)} • $statDeltaText';

    Widget buildOrbRow(Key rowKey, List<(HandMove move, int amount)> items) {
      return Container(
        key: rowKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.summaryBarSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: palette.amberBorder.withValues(alpha: 0.35),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final item in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElementalEnergySphere(
                    size: 16,
                    primaryColor: item.$1.elementalPrimaryColor,
                    secondaryColor: item.$1.elementalSecondaryColor,
                    isDark: palette.isDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatGroupedInt(item.$2, loc),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: palette.elementalText(item.$1),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    int costForMove(HandMove move) {
      switch (move) {
        case HandMove.rock:
          return totalCost.fire;
        case HandMove.paper:
          return totalCost.water;
        case HandMove.scissors:
          return totalCost.wood;
        case HandMove.lizard:
          return totalCost.earth;
        case HandMove.spock:
          return totalCost.metal;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: ValueKey(
          isCapUpgrade
              ? 'offertory_cap_max_confirm_dialog'
              : 'offertory_max_confirm_dialog',
        ),
        backgroundColor: palette.dialogSurface,
        surfaceTintColor: palette.isDark ? null : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: palette.amberBorder.withValues(alpha: 0.65),
            width: 1.4,
          ),
        ),
        title: Row(
          children: [
            const OffertoryVaultIcon(size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isCapUpgrade
                    ? loc.t(
                        'offertory_cap_confirm_title',
                        fallback: 'Confirm Offline Cap Upgrade',
                      )
                    : loc.t(
                        'offertory_confirm_title',
                        fallback: 'Confirm Offertory Upgrade',
                      ),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: palette.primaryText,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: palette.rewardedAdCardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                summaryText,
                key: const ValueKey('offertory_max_confirm_summary'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.amberText,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              loc.t(
                'consagration_confirm_total_cost',
                fallback: 'Total Orb Cost',
              ),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            buildOrbRow(
              const ValueKey('offertory_max_confirm_cost'),
              [for (final m in activeMoves) (m, costForMove(m))],
            ),
            const SizedBox(height: 10),
            Text(
              loc.t(
                'consagration_confirm_remaining_balance',
                fallback: 'Remaining After Purchase',
              ),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            buildOrbRow(
              const ValueKey('offertory_max_confirm_remaining'),
              [
                for (final m in activeMoves)
                  (m, math.max(0, controller.orbsFor(m) - costForMove(m))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('offertory_max_confirm_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              loc.t('consagration_confirm_cancel', fallback: 'Cancel'),
              style: TextStyle(color: palette.secondaryText),
            ),
          ),
          ElevatedButton(
            key: const ValueKey('offertory_max_confirm_submit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _goldFill,
              foregroundColor: _goldDarkInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              loc.t('consagration_confirm_action', fallback: 'Confirm Upgrade'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleOffertoryUpgradeTap() async {
    final loc = controller.localization;
    final preview = _resolveOffertoryUpgradePreview();
    if (!preview.isAffordable || preview.levels <= 0) {
      controller.audio.playVibrate();
      if (!mounted) return;
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
      return;
    }

    if (_selectedOffertoryBatch == _OffertoryBatchOption.max &&
        preview.levels >= 10) {
      final confirmed = await _showOffertoryMaxConfirmDialog(
        levels: preview.levels,
        totalCost: preview.totalCost,
      );
      if (!mounted || !confirmed) return;
    }

    final ok = controller.upgradeOffertoryBatch(preview.levels);
    if (ok && mounted) {
      setState(() {
        _stepDownOffertoryBatchIfNeeded();
      });
      final msg = loc
          .t(
            'offertory_upgraded_msg',
            fallback: 'Consecration Rate upgraded to Lv. {level}!',
          )
          .replaceAll(
            '{level}',
            _formatGroupedInt(controller.offertoryRateLevel, loc),
          );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _handleOffertoryCapUpgradeTap() async {
    final loc = controller.localization;
    final preview = _resolveOffertoryCapUpgradePreview();
    if (!preview.isAffordable || preview.levels <= 0) {
      controller.audio.playVibrate();
      if (!mounted) return;
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
      return;
    }

    if (_selectedOffertoryCapBatch == _OffertoryBatchOption.max &&
        preview.levels >= 10) {
      final confirmed = await _showOffertoryMaxConfirmDialog(
        levels: preview.levels,
        totalCost: preview.totalCost,
        isCapUpgrade: true,
      );
      if (!mounted || !confirmed) return;
    }

    final ok = controller.upgradeOffertoryCap(levels: preview.levels);
    if (ok && mounted) {
      setState(() {
        _stepDownOffertoryBatchIfNeeded();
      });
      final msg = loc
          .t(
            'offertory_cap_upgraded_msg',
            fallback: 'Offline Cap expanded to {cap}!',
          )
          .replaceAll('{cap}', controller.offertoryMaxCapFormatted);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  void _handleOffertoryCollect1x() {
    final loc = controller.localization;
    final granted = controller.collectOffertoryOrbs(multiplier: 1);
    if (granted > 0 && mounted) {
      _triggerOffertoryFlyingOrbs(granted);
      final msg = loc
          .t(
            'offertory_collected_msg',
            fallback: 'Collected +{amount} orbs per active element!',
          )
          .replaceAll('{amount}', _formatGroupedInt(granted, loc));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
    }
  }

  Future<void> _handleOffertoryCollect2x() async {
    final loc = controller.localization;
    if (controller.isRemoveAdsActive) {
      final granted = controller.claimRemoveAdsDoubleCollectOffertory();
      if (granted > 0 && mounted) {
        _triggerOffertoryFlyingOrbs(granted);
        final msg = loc
            .t(
              'offertory_collected_msg',
              fallback: 'Collected +{amount} orbs per active element!',
            )
            .replaceAll('{amount}', _formatGroupedInt(granted, loc));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
          );
      }
      return;
    }

    await controller.watchAdToDoubleCollectOffertory(
      onCollected: (granted) {
        if (!mounted || granted <= 0) return;
        _triggerOffertoryFlyingOrbs(granted);
        final msg = loc
            .t(
              'offertory_collected_msg',
              fallback: 'Collected +{amount} orbs per active element!',
            )
            .replaceAll('{amount}', _formatGroupedInt(granted, loc));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
          );
      },
    );
  }

  void _handleOffertoryTitheBoostTap() {
    final loc = controller.localization;
    final ok = controller.invokeOffertoryTitheBoost();
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              loc.t(
                'offertory_tithe_activated_msg',
                fallback: '2x Offertory Production Speed invoked!',
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Widget _buildOffertoryBatchSelector({
    required AppPalette palette,
    required LocalizationService loc,
    required bool canAfford10x,
    required _OffertoryBatchOption selectedOption,
    required ValueChanged<_OffertoryBatchOption> onSelected,
    String keyPrefix = 'offertory_batch',
  }) {
    final trackBg = palette.isDark
        ? const Color(0xFF14171F)
        : const Color(0xFFE9E0CD);
    final trackBorder = palette.amberBorder.withValues(
      alpha: palette.isDark ? 0.25 : 0.45,
    );

    bool isOptionEnabled(_OffertoryBatchOption option) {
      switch (option) {
        case _OffertoryBatchOption.x1:
          return true;
        case _OffertoryBatchOption.x10:
          return canAfford10x;
        case _OffertoryBatchOption.max:
          return true;
      }
    }

    String optionKeyName(_OffertoryBatchOption option) {
      switch (option) {
        case _OffertoryBatchOption.x1:
          return '${keyPrefix}_1x';
        case _OffertoryBatchOption.x10:
          return '${keyPrefix}_10x';
        case _OffertoryBatchOption.max:
          return '${keyPrefix}_max';
      }
    }

    return Container(
      key: ValueKey('${keyPrefix}_selector'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: trackBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _OffertoryBatchOption.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 2.5),
            Builder(
              builder: (_) {
                final option = _OffertoryBatchOption.values[i];
                final enabled = isOptionEnabled(option);
                final selected = selectedOption == option;
                final Color bgColor;
                final Color borderColor;
                final Color textColor;
                if (selected) {
                  bgColor = enabled
                      ? _goldFill
                      : _goldFill.withValues(alpha: 0.45);
                  borderColor = bgColor;
                  textColor = enabled
                      ? _goldDarkInk
                      : _goldDarkInk.withValues(alpha: 0.72);
                } else if (enabled) {
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
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey(optionKeyName(option)),
                    onTap: enabled
                        ? () {
                            controller.audio.playTapVibrate();
                            onSelected(option);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(6.5),
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6.5),
                        border: Border.all(color: borderColor, width: 0.9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        option.label(loc),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOffertoryWing(
    BuildContext context,
    AppPalette palette,
    LocalizationService loc,
  ) {
    final lv = controller.offertoryRateLevel;
    final capLv = controller.offertoryCapLevel;
    final currentCapMinutes = controller.offertoryMaxCapMinutes;
    final currentCapFormatted = GameController.formatOffertoryCapMinutes(
      currentCapMinutes,
    );
    final canAffordCap10x = controller.canAffordOffertoryCapUpgrade(levels: 10);
    final capPreview = _resolveOffertoryCapUpgradePreview();
    final capPreviewTargetLv = capLv + capPreview.levels;
    final capPreviewTargetMinutes = controller.offertoryCapMinutesAfterLevels(
      capPreview.levels,
    );
    final capPreviewTargetFormatted = GameController.formatOffertoryCapMinutes(
      capPreviewTargetMinutes,
    );
    final capDeltaFormatted = GameController.formatOffertoryCapDeltaMinutes(
      capPreview.levels * GameController.offertoryCapMinutesPerLevel,
    );
    final activeMoves = controller.offertoryActiveElements;
    final isPhase2Elements = controller.includesEarthAndMetalInBonuses;
    final isBoostActive = controller.isOffertoryBoostActive();
    final boostRemaining = controller.offertoryBoostRemaining();
    final hourlyRate = controller.offertoryHourlyRate();
    final perMinRate = controller.offertoryPerMinuteRate();
    final storedOrbs = controller.offertoryStoredOrbs();
    final fillProgress = controller.offertoryFillProgress();
    final isFull = controller.isOffertoryFull;
    final timeUntilFull = controller.offertoryTimeUntilFull();
    final milestonePercent = controller.offertoryMilestoneBonusPercent;
    final isRemoveAds = controller.isRemoveAdsActive;
    final canCollect = storedOrbs >= 1;
    final isFreeDoubleReady = controller.isOffertoryFreeDoubleReady();
    final freeDoubleRemaining = controller.offertoryFreeDoubleRemaining();
    final canDoubleCollect = isRemoveAds
        ? controller.canClaimRemoveAdsDoubleCollectOffertory()
        : controller.canWatchAdDoubleCollectOffertory();

    final canAfford10x = controller.canAffordOffertoryLevels(10);
    final upgradePreview = _resolveOffertoryUpgradePreview();
    final previewTargetLv = lv + upgradePreview.levels;
    final previewHourlyRate = controller.offertoryHourlyRate(
      level: previewTargetLv,
    );
    final crossesMilestone = (previewTargetLv ~/ 10) > (lv ~/ 10);
    final nextReachedMilestonePercent = (previewTargetLv ~/ 10) * 25;
    final nextReachedMilestoneLv = (previewTargetLv ~/ 10) * 10;

    final titheCosts = controller.offertoryTitheCosts();
    final canTithe = controller.canInvokeOffertoryTitheBoost();
    final isBoostAtMaxCap = controller.isOffertoryBoostAtMaxCap();

    final cardBg = palette.isDark
        ? const Color(0xFF1E222B)
        : palette.dialogCardSurface;

    final currentCapLabel = loc
        .t('offertory_cap_label', fallback: '{cap} Cap')
        .replaceAll('{cap}', currentCapFormatted);

    final vaultHeaderTitle = lv == 0
        ? loc.t('offertory_unbuilt_title', fallback: 'Unbuilt — Lv. 0')
        : loc
            .t('offertory_level_title', fallback: 'Offertory Lv. {level}')
            .replaceAll('{level}', _formatGroupedInt(lv, loc));

    final rateLine = loc
        .t(
          'offertory_rate_format',
          fallback: '+{hourly}/h • {perMin}/min per element',
        )
        .replaceAll('{hourly}', _formatRateValue(hourlyRate, loc))
        .replaceAll('{perMin}', _formatRateValue(perMinRate, loc));

    int costForMove(ElementalCost cost, HandMove move) {
      switch (move) {
        case HandMove.rock:
          return cost.fire;
        case HandMove.paper:
          return cost.water;
        case HandMove.scissors:
          return cost.wood;
        case HandMove.lizard:
          return cost.earth;
        case HandMove.spock:
          return cost.metal;
      }
    }

    return SingleChildScrollView(
      key: const ValueKey('temple_wing_offertory'),
      controller: _wingScrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wing Header
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const OffertoryVaultIcon(size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.t(
                      'temple_offertory_title',
                      fallback: 'Sacred Offertory',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: palette.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.rewardedAdCardSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: palette.amberBorder.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        isPhase2Elements
                            ? loc.t(
                                'offertory_phase2_elements_note',
                                fallback: 'Phase 2+: All 5 Elements',
                              )
                            : loc.t(
                                'offertory_phase1_elements_note',
                                fallback: 'Phase 1: 3 Main Elements',
                              ),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: palette.amberText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===================================================================
          // CARD 1 — SACRED OFFERTORY VAULT (LIVE IDLE COUNTER & COLLECTION)
          // ===================================================================
          Container(
            key: const ValueKey('offertory_vault_card'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFull
                    ? (palette.isDark
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFC88A00))
                    : palette.amberBorder.withValues(
                        alpha: palette.isDark ? 0.40 : 0.55,
                      ),
                width: isFull ? 1.8 : 1.1,
              ),
              boxShadow: isFull
                  ? [
                      BoxShadow(
                        color: _goldFill.withValues(alpha: 0.24),
                        blurRadius: 10,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              key: _offertoryVaultAnchorKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vault Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: palette.amberBorder.withValues(
                          alpha: palette.isDark ? 0.16 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.amberBorder.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const OffertoryVaultIcon(size: 32),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                vaultHeaderTitle,
                                key: const ValueKey('offertory_level_header'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: palette.primaryText,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.successText.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: palette.successText.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  loc.t(
                                    'offertory_permanent_badge',
                                    fallback: 'Permanent',
                                  ),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.successText,
                                  ),
                                ),
                              ),
                              if (milestonePercent > 0)
                                Container(
                                  key: const ValueKey(
                                    'offertory_milestone_badge',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _goldFill.withValues(
                                      alpha: palette.isDark ? 0.22 : 0.30,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: palette.amberBorder.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    loc
                                        .t(
                                          'offertory_milestone_badge',
                                          fallback: '+{percent}% Milestone',
                                        )
                                        .replaceAll(
                                          '{percent}',
                                          '$milestonePercent',
                                        ),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: palette.amberText,
                                    ),
                                  ),
                                ),
                              Container(
                                key: const ValueKey(
                                  'offertory_vault_cap_badge',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.rewardedAdCardSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: palette.amberBorder.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 10.5,
                                      color: palette.amberIcon,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      currentCapLabel,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: palette.amberText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (isBoostActive) ...[
                                Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _goldFill,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    '2x',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: _goldDarkInk,
                                    ),
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  rateLine,
                                  key: const ValueKey('offertory_rate_text'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isBoostActive
                                        ? palette.amberText
                                        : palette.amberSubtitle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),

                // Live Ticking Storage Display (3D Elemental Orbs)
                Container(
                  key: const ValueKey('offertory_storage_display'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.summaryBarSurface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: palette.amberBorder.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (lv == 0)
                        Text(
                          loc
                              .t(
                                'offertory_unbuilt_hint',
                                fallback:
                                    'Consecrate Elemental Orbs below to awaken permanent idle orb generation (up to {cap} offline).',
                              )
                              .replaceAll('{cap}', currentCapFormatted),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: palette.secondaryText,
                          ),
                        )
                      else ...[
                        Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            for (final move in activeMoves)
                              Row(
                                key: ValueKey(
                                  'offertory_stored_orb_${move.orbKey}',
                                ),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElementalEnergySphere(
                                    key: ValueKey(
                                      'offertory_stored_sphere_${move.orbKey}',
                                    ),
                                    size: 20,
                                    primaryColor: move.elementalPrimaryColor,
                                    secondaryColor:
                                        move.elementalSecondaryColor,
                                    isDark: palette.isDark,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatGroupedInt(storedOrbs, loc),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: palette.elementalText(move),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              flex: 6,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: isFull
                                    ? Container(
                                        key: const ValueKey(
                                          'offertory_full_badge',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _goldFill,
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _goldFill.withValues(
                                                alpha: 0.45,
                                              ),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          loc
                                              .t(
                                                'offertory_full_badge',
                                                fallback: 'FULL ({cap} Cap)',
                                              )
                                              .replaceAll(
                                                '{cap}',
                                                currentCapFormatted,
                                              ),
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: _goldDarkInk,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        loc
                                            .t(
                                              'offertory_full_in',
                                              fallback: 'Full in {time}',
                                            )
                                            .replaceAll(
                                              '{time}',
                                              _formatOffertoryDuration(
                                                timeUntilFull,
                                              ),
                                            ),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: palette.secondaryText,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              flex: 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${(fillProgress * 100).floor()}% • $currentCapLabel',
                                  key: const ValueKey(
                                    'offertory_cap_progress_text',
                                  ),
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: palette.amberText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            key: const ValueKey('offertory_cap_progress_bar'),
                            value: fillProgress,
                            minHeight: 7,
                            backgroundColor: palette.isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : const Color(0xFFD6C9B2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isFull
                                  ? const Color(0xFFFFD54F)
                                  : palette.amberBorder,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 9),

                // Collect (1x) and 2x Collect Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        key: const ValueKey('offertory_collect_button'),
                        onPressed: canCollect ? _handleOffertoryCollect1x : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _goldFill,
                          foregroundColor: _goldDarkInk,
                          disabledBackgroundColor: palette.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : palette.sandCardSurface,
                          disabledForegroundColor: palette.mutedText,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.download_done_rounded,
                          size: 16,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            loc.t('offertory_collect_btn', fallback: 'Collect'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        key: const ValueKey('offertory_double_collect_button'),
                        onPressed:
                            canDoubleCollect ? _handleOffertoryCollect2x : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.isDark
                              ? const Color(0xFF2B3447)
                              : const Color(0xFFE6D5B2),
                          foregroundColor: palette.amberText,
                          disabledBackgroundColor: palette.isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : palette.sandCardSurface,
                          disabledForegroundColor: palette.mutedText,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: canDoubleCollect
                                  ? palette.amberBorder.withValues(alpha: 0.75)
                                  : palette.sandCardBorder,
                              width: 1.1,
                            ),
                          ),
                        ),
                        icon: Icon(
                          isRemoveAds
                              ? Icons.auto_awesome_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 15,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isRemoveAds
                                ? (isFreeDoubleReady
                                      ? loc.t(
                                          'offertory_sanctuary_grace_2x_btn',
                                          fallback:
                                              '2x Collect (Sanctuary Grace)',
                                        )
                                      : loc
                                            .t(
                                              'offertory_sanctuary_grace_cooldown',
                                              fallback: 'Grace in {time}',
                                            )
                                            .replaceAll(
                                              '{time}',
                                              _formatOffertoryDuration(
                                                freeDoubleRemaining,
                                              ),
                                            ))
                                : loc.t(
                                    'offertory_watch_ad_2x_btn',
                                    fallback: 'Watch Ad (2x Collect)',
                                  ),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isRemoveAds) ...[
                  const SizedBox(height: 6),
                  Row(
                    key: const ValueKey('offertory_ad_disclosure_box'),
                    children: [
                      Icon(
                        Icons.ondemand_video_rounded,
                        size: 13,
                        color: palette.amberIcon,
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
                            height: 1.25,
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

          // ===================================================================
          // CARD 2A — CONSECRATION RATE UPGRADE (HOURLY RATE • 1x | 10x | MAX)
          // ===================================================================
          Container(
            key: const ValueKey('offertory_upgrade_card'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.amberBorder.withValues(
                  alpha: palette.isDark ? 0.36 : 0.50,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      key: const ValueKey('offertory_rate_icon_badge'),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _goldFill.withValues(
                          alpha: palette.isDark ? 0.16 : 0.22,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.amberBorder.withValues(alpha: 0.50),
                        ),
                      ),
                      child: const ConsecrationCenserIcon(size: 32),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  loc.t(
                                    'offertory_rate_upgrade_title',
                                    fallback: 'Consecration Rate',
                                  ),
                                  key: const ValueKey(
                                    'offertory_rate_upgrade_title',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: palette.primaryText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildOffertoryBatchSelector(
                                palette: palette,
                                loc: loc,
                                canAfford10x: canAfford10x,
                                selectedOption: _selectedOffertoryBatch,
                                onSelected: (option) => setState(
                                  () => _selectedOffertoryBatch = option,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            loc.t(
                              'offertory_rate_upgrade_desc',
                              fallback:
                                  'Increases idle orbs generated per hour (+12/h per level, +25% every 10 levels).',
                            ),
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.25,
                              color: palette.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lv. ${_formatGroupedInt(lv, loc)} → Lv. ${_formatGroupedInt(previewTargetLv, loc)}',
                          key: const ValueKey('offertory_level_jump_preview'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: palette.amberText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '+${_formatRateValue(hourlyRate, loc)}/h → +${_formatRateValue(previewHourlyRate, loc)}/h',
                          key: const ValueKey('offertory_rate_jump_preview'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: palette.successText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (crossesMilestone) ...[
                  const SizedBox(height: 5),
                  Container(
                    key: const ValueKey('offertory_next_milestone_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _goldFill.withValues(
                        alpha: palette.isDark ? 0.18 : 0.28,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.70),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: palette.amberIcon,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            loc
                                .t(
                                  'offertory_next_milestone_reached',
                                  fallback:
                                      'Reaches +{percent}% Milestone (Lv. {level})!',
                                )
                                .replaceAll(
                                  '{percent}',
                                  '$nextReachedMilestonePercent',
                                )
                                .replaceAll(
                                  '{level}',
                                  '$nextReachedMilestoneLv',
                                ),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: palette.amberText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 7),

                // Real-Time 3D Elemental Orb Cost Breakdown
                Container(
                  key: const ValueKey('offertory_upgrade_cost_box'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: palette.summaryBarSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: palette.amberBorder.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      for (final move in activeMoves)
                        Builder(
                          builder: (_) {
                            final req = costForMove(
                              upgradePreview.totalCost,
                              move,
                            );
                            final hasEnough = controller.orbsFor(move) >= req;
                            return Row(
                              key: ValueKey(
                                'offertory_upgrade_cost_${move.orbKey}',
                              ),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElementalEnergySphere(
                                  size: 17,
                                  primaryColor: move.elementalPrimaryColor,
                                  secondaryColor: move.elementalSecondaryColor,
                                  isDark: palette.isDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatGroupedInt(req, loc),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: hasEnough
                                        ? palette.elementalText(move)
                                        : palette.dangerText,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                ElevatedButton.icon(
                  key: const ValueKey('offertory_upgrade_button'),
                  onPressed: upgradePreview.isAffordable
                      ? _handleOffertoryUpgradeTap
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldFill,
                    foregroundColor: _goldDarkInk,
                    disabledBackgroundColor: palette.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : palette.sandCardSurface,
                    disabledForegroundColor: palette.mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.upgrade_rounded, size: 17),
                  label: Text(
                    (lv == 0
                            ? loc.t(
                                'offertory_build_btn',
                                fallback: 'Build Offertory (+{count} Lv)',
                              )
                            : loc.t(
                                'offertory_upgrade_btn',
                                fallback: 'Upgrade (+{count} Lv)',
                              ))
                        .replaceAll(
                          '{count}',
                          _formatGroupedInt(upgradePreview.levels, loc),
                        ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===================================================================
          // CARD 2B — MAX OFFLINE TIME CAP UPGRADE (+30m PER LEVEL, UNCAPPED)
          // ===================================================================
          Container(
            key: const ValueKey('offertory_cap_upgrade_card'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.amberBorder.withValues(
                  alpha: palette.isDark ? 0.36 : 0.50,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      key: const ValueKey('offertory_cap_icon_badge'),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _goldFill.withValues(
                          alpha: palette.isDark ? 0.16 : 0.22,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.amberBorder.withValues(alpha: 0.50),
                        ),
                      ),
                      child: const SanctuaryHourglassIcon(size: 32),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  loc.t(
                                    'offertory_cap_upgrade_title',
                                    fallback: 'Offline Cap',
                                  ),
                                  key: const ValueKey(
                                    'offertory_cap_upgrade_title',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: palette.primaryText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildOffertoryBatchSelector(
                                palette: palette,
                                loc: loc,
                                canAfford10x: canAffordCap10x,
                                selectedOption: _selectedOffertoryCapBatch,
                                onSelected: (option) => setState(
                                  () => _selectedOffertoryCapBatch = option,
                                ),
                                keyPrefix: 'offertory_cap_batch',
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            loc.t(
                              'offertory_cap_upgrade_desc',
                              fallback:
                                  'Extends maximum offline orb storage (+30m per level, no level cap).',
                            ),
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.25,
                              color: palette.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lv. ${_formatGroupedInt(capLv, loc)} → Lv. ${_formatGroupedInt(capPreviewTargetLv, loc)}',
                          key: const ValueKey(
                            'offertory_cap_level_jump_preview',
                          ),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: palette.amberText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          loc
                              .t(
                                'offertory_cap_preview',
                                fallback: '{current} → {next}',
                              )
                              .replaceAll('{current}', currentCapFormatted)
                              .replaceAll('{next}', capPreviewTargetFormatted),
                          key: const ValueKey('offertory_cap_jump_preview'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: palette.successText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Container(
                  key: const ValueKey('offertory_cap_cost_box'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: palette.summaryBarSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: palette.amberBorder.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      for (final move in activeMoves)
                        Builder(
                          builder: (_) {
                            final req = costForMove(capPreview.totalCost, move);
                            final hasEnough = controller.orbsFor(move) >= req;
                            return Row(
                              key: ValueKey(
                                'offertory_cap_cost_${move.orbKey}',
                              ),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElementalEnergySphere(
                                  size: 17,
                                  primaryColor: move.elementalPrimaryColor,
                                  secondaryColor: move.elementalSecondaryColor,
                                  isDark: palette.isDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatGroupedInt(req, loc),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: hasEnough
                                        ? palette.elementalText(move)
                                        : palette.dangerText,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  key: const ValueKey('offertory_cap_upgrade_button'),
                  onPressed: capPreview.isAffordable
                      ? _handleOffertoryCapUpgradeTap
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldFill,
                    foregroundColor: _goldDarkInk,
                    disabledBackgroundColor: palette.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : palette.sandCardSurface,
                    disabledForegroundColor: palette.mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.more_time_rounded, size: 17),
                  label: Text(
                    loc
                        .t(
                          'offertory_cap_upgrade_btn',
                          fallback: 'Expand Cap (+{delta})',
                        )
                        .replaceAll('{delta}', capDeltaFormatted),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===================================================================
          // CARD 3 — VOW OF TITHE: 10% OFFERING (2x PRODUCTION SPEED FOR 4H)
          // ===================================================================
          Container(
            key: const ValueKey('offertory_tithe_card'),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isBoostActive
                  ? Color.alphaBlend(
                      _goldFill.withValues(alpha: palette.isDark ? 0.11 : 0.14),
                      cardBg,
                    )
                  : cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isBoostActive
                    ? (palette.isDark
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFC88A00))
                    : palette.amberBorder.withValues(
                        alpha: palette.isDark ? 0.36 : 0.50,
                      ),
                width: isBoostActive ? 2.0 : 1.0,
              ),
              boxShadow: isBoostActive
                  ? [
                      BoxShadow(
                        color: _goldFill.withValues(alpha: 0.25),
                        blurRadius: 9,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _goldFill.withValues(
                          alpha: palette.isDark ? 0.16 : 0.22,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.amberBorder.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const TitheBlessingIcon(size: 30),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.t(
                              'offertory_tithe_card_title',
                              fallback: 'Vow of Tithe — 10% Offering',
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: palette.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.t(
                              'offertory_tithe_card_desc',
                              fallback:
                                  'Sacrifice 10% of each active element to invoke 2x idle production speed for 4 hours (up to 8h cap).',
                            ),
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.25,
                              color: palette.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isBoostActive) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const ValueKey('offertory_boost_timer'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _goldFill.withValues(
                        alpha: palette.isDark ? 0.22 : 0.30,
                      ),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: palette.amberBorder.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: palette.amberIcon,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              loc
                                  .t(
                                    'offertory_tithe_active_timer',
                                    fallback: '2x Speed Active: {time}',
                                  )
                                  .replaceAll(
                                    '{time}',
                                    _formatOffertoryDuration(boostRemaining),
                                  ),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: palette.amberText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Exact 10% Orb Cost per Active Element (3D Orbs)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: palette.summaryBarSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: palette.amberBorder.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      for (final move in activeMoves)
                        Builder(
                          builder: (_) {
                            final bal = controller.orbsFor(move);
                            final meetsMin =
                                bal >= GameController.offertoryTitheMinBalance;
                            final displayCost = meetsMin
                                ? (titheCosts[move] ?? 5)
                                : 5;
                            return Row(
                              key: ValueKey(
                                'offertory_tithe_cost_${move.orbKey}',
                              ),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElementalEnergySphere(
                                  size: 17,
                                  primaryColor: move.elementalPrimaryColor,
                                  secondaryColor: move.elementalSecondaryColor,
                                  isDark: palette.isDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '-${_formatGroupedInt(displayCost, loc)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: meetsMin
                                        ? palette.elementalText(move)
                                        : palette.dangerText,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  loc.t(
                    'offertory_tithe_min_req',
                    fallback:
                        'Requires at least 50 of each active element (min. 5/element)',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: palette.mutedText,
                  ),
                ),
                const SizedBox(height: 8),

                ElevatedButton.icon(
                  key: const ValueKey('offertory_tithe_button'),
                  onPressed: canTithe ? _handleOffertoryTitheBoostTap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldFill,
                    foregroundColor: _goldDarkInk,
                    disabledBackgroundColor: palette.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : palette.sandCardSurface,
                    disabledForegroundColor: palette.mutedText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(
                    isBoostAtMaxCap
                        ? loc.t(
                            'offertory_tithe_max_cap_btn',
                            fallback: 'Max 8h Boost Cap Reached',
                          )
                        : (isBoostActive
                              ? loc.t(
                                  'offertory_tithe_extend_btn',
                                  fallback: 'Extend 2x Blessing (+4h)',
                                )
                              : loc.t(
                                  'offertory_tithe_btn',
                                  fallback: 'Consecrate 10% Tithe (2x • 4h)',
                                )),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TempleCompactVerticalTabPill extends StatelessWidget {
  final Widget Function(bool isSelected) iconBuilder;
  final String label;
  final bool selected;
  final bool showDot;
  final AppPalette palette;
  final VoidCallback onTap;

  const _TempleCompactVerticalTabPill({
    super.key,
    required this.iconBuilder,
    required this.label,
    required this.selected,
    this.showDot = false,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseSurface = palette.dialogCardSurface;
    final bgColor = selected
        ? Color.alphaBlend(
            (palette.isDark
                    ? const Color(0xFFF5C22B)
                    : const Color(0xFFD99B00))
                .withValues(alpha: 0.14),
            baseSurface,
          )
        : baseSurface;
    final borderColor = selected
        ? (palette.isDark
              ? const Color(0xFFFFD54F)
              : const Color(0xFFC88A00))
        : (palette.isDark
              ? Colors.white.withValues(alpha: 0.16)
              : const Color(0xFFC8961E).withValues(alpha: 0.45));
    final textColor = selected
        ? (palette.isDark
              ? const Color(0xFFFFD54F)
              : const Color(0xFF7A4E00))
        : (palette.isDark
              ? Colors.white70
              : const Color(0xFF5C4934));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 1.8 : 3.0,
                vertical: selected ? 4.8 : 6.0,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2.2 : 1.0,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF5C22B).withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
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
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            top: -3,
            right: -2,
            child: Container(
              key: key is ValueKey<String>
                  ? Key('${(key as ValueKey<String>).value}_dot')
                  : null,
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ShopDialogState._alertRed,
                border: Border.all(
                  color: palette.dialogSurface,
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _ShopDialogState._goldFill.withValues(alpha: 0.55),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShopItemTile extends StatelessWidget {
  final Widget? iconWidget;
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
    this.iconWidget,
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

  Widget _buildIconBadge(AppPalette palette, {bool highlightActive = false}) {
    final accentColor = highlightActive ? palette.successIcon : palette.amberBorder;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: accentColor.withValues(
          alpha: palette.isDark ? 0.14 : 0.16,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(
            alpha: highlightActive ? 0.48 : 0.38,
          ),
        ),
      ),
      child: iconWidget,
    );
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (iconWidget != null) ...[
              _buildIconBadge(palette, highlightActive: isActive),
              const SizedBox(width: 10),
            ],
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
                  const SizedBox(height: 3),
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
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            softWrap: true,
            style: TextStyle(
              fontSize: 11,
              color: palette.amberSubtitle,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLockedContent(AppPalette palette, bool hasRealMoneyPrice) {
    final entries = cost.nonZeroEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (iconWidget != null) ...[
              _buildIconBadge(palette),
              const SizedBox(width: 10),
            ],
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
                ],
              ),
            ),
          ],
        ),
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

class _OverchargedStaffShopTile extends StatelessWidget {
  final Widget iconWidget;
  final String title;
  final String subtitle;
  final int level;
  final bool isActive;
  final int selectedSpeed;
  final ElementalCost? nextCost;
  final String enabledLabel;
  final String disabledLabel;
  final String unlockLabel;
  final String levelPrefix;
  final String maxBadgeLabel;
  final String speedSectionLabel;
  final VoidCallback onUnlockOrUpgrade;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onSelectSpeed;

  const _OverchargedStaffShopTile({
    super.key,
    this.iconWidget = const OverchargedStaffIcon(size: 32),
    required this.title,
    required this.subtitle,
    required this.level,
    required this.isActive,
    required this.selectedSpeed,
    required this.nextCost,
    required this.enabledLabel,
    required this.disabledLabel,
    required this.unlockLabel,
    required this.levelPrefix,
    required this.maxBadgeLabel,
    required this.speedSectionLabel,
    required this.onUnlockOrUpgrade,
    required this.onToggle,
    required this.onSelectSpeed,
  });

  Widget _buildIconBadge(AppPalette palette, {bool highlightActive = false}) {
    final accentColor = highlightActive ? palette.successIcon : palette.amberBorder;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: accentColor.withValues(
          alpha: palette.isDark ? 0.14 : 0.16,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(
            alpha: highlightActive ? 0.48 : 0.38,
          ),
        ),
      ),
      child: iconWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final isUnlocked = level >= 1;

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
                  ? Border.all(
                      color: palette.amberBorder.withValues(alpha: 0.25),
                      width: 1.0,
                    )
                  : Border.all(
                      color: palette.sandCardBorder,
                      width: 1.0,
                    )),
      ),
      child: isUnlocked
          ? _buildUnlockedContent(palette)
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onUnlockOrUpgrade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: _buildLockedContent(palette),
                ),
              ),
            ),
    );
  }

  Widget _buildLockedContent(AppPalette palette) {
    final entries =
        (nextCost ?? GameController.costOverchargedStaffLv1).nonZeroEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIconBadge(palette),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.amberSubtitle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              unlockLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    palette.isDark ? FontWeight.normal : FontWeight.w600,
                color: palette.isDark ? Colors.grey : palette.secondaryText,
              ),
            ),
            ElevatedButton(
              key: const ValueKey('overcharged_staff_upgrade_button'),
              onPressed: onUnlockOrUpgrade,
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
          ],
        ),
      ],
    );
  }

  Widget _buildUnlockedContent(AppPalette palette) {
    final activeColor = palette.successIcon;
    final inactiveColor = palette.isDark ? Colors.grey : palette.mutedText;
    final isMaxLevel = level >= GameController.overchargedStaffMaxLevel;
    final nextLevel = level + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + ON/OFF Toggle
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onToggle(!isActive),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIconBadge(palette, highlightActive: isActive),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: palette.primaryText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                key: const ValueKey('overcharged_staff_level_pill'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isMaxLevel
                                      ? _ShopDialogState._goldFill
                                      : palette.rewardedAdCardSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isMaxLevel
                                        ? const Color(0xFFFFB300)
                                        : palette.amberBorder.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  isMaxLevel
                                      ? maxBadgeLabel
                                      : '$levelPrefix $level/${GameController.overchargedStaffMaxLevel}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isMaxLevel
                                        ? _ShopDialogState._goldDarkInk
                                        : palette.amberText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive
                                    ? Icons.check_circle
                                    : Icons.cancel_outlined,
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
                      key: const ValueKey('overcharged_staff_switch'),
                      value: isActive,
                      onChanged: onToggle,
                      activeTrackColor: activeColor,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.amberSubtitle,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Compact Horizontal Row of 6 Speed Pills (1x, 2x, 5x, 10x, 20x, 30x)
          AnimatedOpacity(
            key: const ValueKey('overcharged_staff_speed_row_opacity'),
            opacity: isActive ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 160),
            child: Container(
              key: const ValueKey('overcharged_staff_speed_row'),
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: palette.isDark
                    ? const Color(0xFF14171F)
                    : const Color(0xFFE9E0CD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(
                    alpha: palette.isDark ? 0.25 : 0.45,
                  ),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  for (int i = 0;
                      i < GameController.overchargedStaffSpeedOptions.length;
                      i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: _buildSpeedPill(
                        speed: GameController.overchargedStaffSpeedOptions[i],
                        palette: palette,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Next-Level Upgrade Row (Lv. 2..6) or MAX Badge
          if (!isMaxLevel && nextCost != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$levelPrefix $nextLevel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.amberText,
                  ),
                ),
                ElevatedButton(
                  key: const ValueKey('overcharged_staff_upgrade_button'),
                  onPressed: onUnlockOrUpgrade,
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
                    entries: nextCost!.nonZeroEntries,
                    palette: palette,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  speedSectionLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: palette.secondaryText,
                  ),
                ),
                Container(
                  key: const ValueKey('overcharged_staff_max_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ShopDialogState._goldFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB300)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: _ShopDialogState._goldDarkInk,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        maxBadgeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _ShopDialogState._goldDarkInk,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedPill({
    required int speed,
    required AppPalette palette,
  }) {
    final requiredLevel =
        GameController.overchargedStaffRequiredLevelForSpeed(speed);
    final isTierUnlocked = level >= requiredLevel;
    final isSelected = isTierUnlocked && selectedSpeed == speed;
    final intervalMs = GameController.overchargedStaffIntervalMsForSpeed(speed);

    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isSelected) {
      bgColor = _ShopDialogState._goldFill;
      borderColor = const Color(0xFFFFB300);
      textColor = _ShopDialogState._goldDarkInk;
    } else if (isTierUnlocked) {
      bgColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFFAF6EE);
      borderColor = palette.amberBorder.withValues(
        alpha: palette.isDark ? 0.30 : 0.45,
      );
      textColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.92)
          : palette.primaryText;
    } else {
      bgColor = Colors.transparent;
      borderColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : palette.sandCardBorder.withValues(alpha: 0.55);
      textColor = palette.isDark
          ? Colors.white.withValues(alpha: 0.32)
          : palette.mutedText.withValues(alpha: 0.45);
    }

    return Tooltip(
      message: '${speed}x (${intervalMs}ms)',
      child: Semantics(
        button: true,
        selected: isSelected,
        enabled: isTierUnlocked,
        label: '${speed}x',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('overcharged_staff_speed_${speed}x'),
            onTap: isTierUnlocked ? () => onSelectSpeed(speed) : null,
            borderRadius: BorderRadius.circular(7.5),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(7.5),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isTierUnlocked) ...[
                      Icon(
                        Icons.lock_rounded,
                        size: 9.5,
                        color: textColor,
                      ),
                      const SizedBox(width: 1.5),
                    ],
                    Text(
                      '${speed}x',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfiniteStatUpgradeTile extends StatelessWidget {
  final Key cardKey;
  final Key buttonKey;
  final Key adButtonKey;
  final Key? floatingGainKey;
  final Widget iconWidget;
  final String title;
  final String subtitle;
  final String statusText;
  final String actionLabel;
  final ElementalCost cost;
  final bool formatThousands;
  final String numberLocale;
  final bool isAffordable;
  final bool showAdButton;
  final String adButtonLabel;
  final bool canWatchAd;
  final Animation<double>? feedbackAnimation;
  final String? floatingGainText;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final VoidCallback onPurchase;
  final VoidCallback onWatchAd;

  const _InfiniteStatUpgradeTile({
    required this.cardKey,
    required this.buttonKey,
    required this.adButtonKey,
    this.floatingGainKey,
    required this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.actionLabel,
    required this.cost,
    this.formatThousands = false,
    this.numberLocale = 'en',
    this.isAffordable = true,
    required this.showAdButton,
    required this.adButtonLabel,
    required this.canWatchAd,
    this.feedbackAnimation,
    this.floatingGainText,
    this.onHoldStart,
    this.onHoldEnd,
    required this.onPurchase,
    required this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final entries = cost.nonZeroEntries;
    final baseBg = palette.isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : palette.shopTileSurface;
    final baseBorder = palette.isDark
        ? palette.amberBorder.withValues(alpha: 0.32)
        : palette.sandCardBorder;

    Widget buildCard(double flashStrength) {
      final flashBg = flashStrength > 0
          ? Color.lerp(
              baseBg,
              _ShopDialogState._goldFill.withValues(
                alpha: palette.isDark ? 0.24 : 0.35,
              ),
              flashStrength,
            )!
          : baseBg;
      final flashBorder = flashStrength > 0
          ? Color.lerp(baseBorder, _ShopDialogState._goldFill, flashStrength)!
          : baseBorder;

      return Container(
        key: cardKey,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: flashBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: flashBorder,
            width: flashStrength > 0.1 ? 1.5 : 1.0,
          ),
        ),
        child: Listener(
          onPointerDown: onHoldStart != null ? (_) => onHoldStart!() : null,
          onPointerUp: onHoldEnd != null ? (_) => onHoldEnd!() : null,
          onPointerCancel: onHoldEnd != null ? (_) => onHoldEnd!() : null,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPurchase,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        iconWidget,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: palette.primaryText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    flex: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.rewardedAdCardSurface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: palette.amberBorder.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          statusText,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: palette.amberText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: palette.amberSubtitle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
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
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: ElevatedButton(
                                  key: buttonKey,
                                  onPressed: onPurchase,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.isDark
                                        ? null
                                        : palette.dialogSurface,
                                    elevation: palette.isDark ? null : 1,
                                    side: isAffordable
                                        ? (palette.isDark
                                              ? null
                                              : BorderSide(
                                                  color: palette.sandCardBorder,
                                                ))
                                        : BorderSide(
                                            color: palette.dangerText
                                                .withValues(alpha: 0.55),
                                          ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    minimumSize: const Size(52, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: _ElementalCostPillRow(
                                    entries: entries,
                                    palette: palette,
                                    formatThousands: formatThousands,
                                    numberLocale: numberLocale,
                                  ),
                                ),
                              ),
                              if (showAdButton)
                                Listener(
                                  onPointerDown: onHoldEnd != null
                                      ? (_) => onHoldEnd!()
                                      : null,
                                  child: ElevatedButton.icon(
                                    key: adButtonKey,
                                    onPressed: canWatchAd ? onWatchAd : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: const Color(0xFF231F1A),
                                      disabledBackgroundColor: Colors.amber
                                          .withValues(alpha: 0.28),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      minimumSize: const Size(52, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
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
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final anim = feedbackAnimation;
    if (anim == null) {
      return buildCard(0.0);
    }

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        final isActive =
            t > 0.0 && anim.status != AnimationStatus.dismissed && t < 1.0;
        final flashStrength = isActive ? (1.0 - t).clamp(0.0, 1.0) : 0.0;
        final showFloating =
            floatingGainText != null &&
            (isActive || anim.status == AnimationStatus.forward);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            buildCard(flashStrength),
            if (showFloating)
              Positioned(
                top: 6,
                right: 12,
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(0, -18.0 * t),
                    child: Opacity(
                      opacity: (1.0 - t * 0.85).clamp(0.0, 1.0),
                      child: Container(
                        key: floatingGainKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _ShopDialogState._goldFill,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          floatingGainText!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: _ShopDialogState._goldDarkInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConsumableBundleTile extends StatelessWidget {
  final Key cardKey;
  final Key buttonKey;
  final IconData? icon;
  final Widget? iconWidget;
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
    this.icon,
    this.iconWidget,
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
          if (iconWidget != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _ShopDialogState._goldFill.withValues(
                  alpha: palette.isDark ? 0.14 : 0.20,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: palette.amberBorder.withValues(
                    alpha: palette.isDark ? 0.40 : 0.50,
                  ),
                ),
              ),
              child: iconWidget,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (singleMove != null) ...[
                      ElementalEnergySphere(
                        size: 17,
                        primaryColor: singleMove!.elementalPrimaryColor,
                        secondaryColor: singleMove!.elementalSecondaryColor,
                        isDark: palette.isDark,
                      ),
                      const SizedBox(width: 6),
                    ] else if (iconWidget == null && icon != null) ...[
                      Icon(
                        icon,
                        size: 17,
                        color: palette.amberIcon,
                      ),
                      const SizedBox(width: 6),
                    ],
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
  final bool canFreePray;
  final bool canAdPray;
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
    required this.canFreePray,
    required this.canAdPray,
    required this.activeLabel,
    required this.freePrayLabel,
    required this.adPrayLabel,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = !isThisActive && (canFreePray || canAdPray);
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withValues(alpha: palette.isDark ? 0.35 : 0.42),
                width: 0.9,
              ),
            ),
            child: SacredBlessingBadgeIcon(blessing: blessing, size: 22),
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
  final bool formatThousands;
  final String numberLocale;

  const _ElementalCostPillRow({
    required this.entries,
    required this.palette,
    this.formatThousands = false,
    this.numberLocale = 'en',
  });

  String _formatAmount(int value) {
    final str = value.toString();
    if (!formatThousands || str.length <= 3) return str;
    final sep = numberLocale == 'en' ? ',' : '.';
    return str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}$sep',
    );
  }

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
                  _formatAmount(entries[i].value),
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
