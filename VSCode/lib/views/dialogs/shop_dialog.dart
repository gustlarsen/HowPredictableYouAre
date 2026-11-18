import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../services/ad_service.dart';
import '../../services/billing_service.dart';
import 'story_dialog.dart';

class ShopDialog extends StatefulWidget {
  final GameController controller;

  const ShopDialog({super.key, required this.controller});

  @override
  State<ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<ShopDialog> {
  GameController get controller => widget.controller;

  bool _restoredDuringCurrentRequest = false;
  bool _errorDuringCurrentRequest = false;

  @override
  void initState() {
    super.initState();
    controller.billingService.addEventListener(_onBillingEvent);
  }

  @override
  void dispose() {
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
        return loc.t('string56', fallback: 'New Hands (Lizard & Spock)');
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
      default:
        return 'Item';
    }
  }

  void _onBillingEvent(BillingPurchaseEvent event) {
    if (!mounted) return;
    final title = _titleForProductId(event.productId);

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
      fallback: 'New Hands (Lizard & Spock)',
    );
    final ok = controller.unlockNewHands();
    _handleUnlock(context, title, ok);
  }

  Future<void> _handleNewHandsToggle(BuildContext context, bool val) async {
    final title = controller.localization.t(
      'string56',
      fallback: 'New Hands (Lizard & Spock)',
    );
    if (controller.hasGameStarted) {
      final confirmed = await _confirmResetForNewHands(context);
      if (!confirmed || !context.mounted) return;
    }
    controller.toggleShowNewHands(val);
    _handleToggle(context, title, val);
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

  Widget _buildOrbSummaryBar() {
    return Container(
      key: const ValueKey('shop_orb_summary_bar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.32),
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
                Icon(
                  move.elementalIcon,
                  size: 14,
                  color: move.elementalPrimaryColor,
                ),
                const SizedBox(width: 3),
                Text(
                  '${controller.orbsFor(move)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: move.elementalPrimaryColor,
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

    final enabledStr = loc.t('string49', fallback: 'Enabled');
    final disabledStr = loc.t('string48', fallback: 'Disabled');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 18.0, 16.0, 14.0),
          child: Column(
            children: [
              // Dialog Header
              Row(
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        loc.t('shop_title', fallback: 'Upgrades & Shop'),
                        maxLines: 1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Compact Horizontal Summary Bar of all 5 Elemental Orb Balances
              _buildOrbSummaryBar(),
              const Divider(height: 14),

              // Shop items list (ordered ascending by Elemental Orb cost)
              Expanded(
                child: ListView(
                  cacheExtent: 1000,
                  children: [
                    _buildShopItem(
                      context: context,
                      title: loc.t(
                        'string38',
                        fallback: 'Predictability Score',
                      ),
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
                      title: loc.t(
                        'string56',
                        fallback: 'New Hands (Lizard & Spock)',
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
                      title: loc.t(
                        'string40',
                        fallback: 'Show Markov Algorithm',
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
                      title: loc.t(
                        'string41',
                        fallback: 'Your Prediction Hint',
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
                      subtitle: loc.t(
                        'gift_box_desc',
                        fallback:
                            'Unlocks a periodic 🎁 gift chest on the top bar granting +5 orbs of every element',
                      ),
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

                    if (!controller.isRemoveAdsActive) ...[
                      const SizedBox(height: 12),
                      // Voluntary Rewarded Video Ad (+50 of each Elemental Orb) action
                      Card(
                        key: const ValueKey('shop_rewarded_ad_card'),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.amber.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.amber.withValues(alpha: 0.35),
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
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      loc.t(
                                        'string45',
                                        fallback: 'Free Elemental Orbs',
                                      ),
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    controller.isRewardedAdOnCooldown
                                        ? 'Cooldown active (2m)'
                                        : loc.t(
                                            'rewarded_ad_desc',
                                            fallback:
                                                'Watch a video ad for +50 of each Elemental Orb',
                                          ),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: controller.isRewardedAdOnCooldown
                                          ? Colors.grey
                                          : Colors.amber,
                                    ),
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
                                                const SnackBar(
                                                  content: Text(
                                                    GameController
                                                        .rewardedAdSnackBarMessage,
                                                  ),
                                                  duration: Duration(seconds: 2),
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
                                  foregroundColor: Colors.black87,
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
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton.icon(
                      key: const ValueKey('shop_restore_purchases_button'),
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
                      label: const Text(
                        'Restore Purchases',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('shop_close_button'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.t('string36', fallback: 'Close')),
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
    final hasRealMoneyPrice =
        localizedPrice != null && localizedPrice!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: isUnlocked && isActive
            ? Border.all(
                color: Colors.green.withValues(alpha: 0.4),
                width: 1.2,
              )
            : null,
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
                ? _buildUnlockedContent()
                : _buildLockedContent(hasRealMoneyPrice),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedContent() {
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.withValues(alpha: 0.85),
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.cancel_outlined,
                    size: 13,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isActive ? enabledLabel : disabledLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? Colors.green : Colors.grey,
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
          activeTrackColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildLockedContent(bool hasRealMoneyPrice) {
    final entries = cost.nonZeroEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber.withValues(alpha: 0.85),
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
            const Text(
              'Unlock',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    minimumSize: const Size(52, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final entry in entries)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              entry.key.elementalIcon,
                              size: 12,
                              color: entry.key.elementalPrimaryColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: entry.key.elementalPrimaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
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
