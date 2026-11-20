import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/move.dart';
import '../../services/ad_service.dart';
import '../../services/billing_service.dart';
import '../../theme/app_theme.dart';
import 'story_dialog.dart';

class ShopDialog extends StatefulWidget {
  final GameController controller;
  final bool fromTemple;

  const ShopDialog({
    super.key,
    required this.controller,
    this.fromTemple = false,
  });

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
                Icon(
                  move.elementalIcon,
                  size: 14,
                  color: palette.elementalText(move),
                ),
                const SizedBox(width: 3),
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

    final enabledStr = loc.t('string49', fallback: 'Enabled');
    final disabledStr = loc.t('string48', fallback: 'Disabled');

    return Dialog(
      backgroundColor: palette.isDark ? null : palette.dialogSurface,
      surfaceTintColor: palette.isDark ? null : Colors.transparent,
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
                  Icon(
                    widget.fromTemple
                        ? Icons.auto_awesome_rounded
                        : Icons.shopping_cart_outlined,
                    color: palette.amberIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.fromTemple
                            ? loc.t(
                                'sacred_temple_altar_title',
                                fallback: 'Altar of Offerings',
                              )
                            : loc.t('shop_title', fallback: 'Upgrades & Shop'),
                        maxLines: 1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: palette.primaryText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Compact Horizontal Summary Bar of all 5 Elemental Orb Balances
              _buildOrbSummaryBar(context),
              // Pinned "Free Elemental Orbs" rewarded ad card directly below the balance box
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: !controller.isRemoveAdsActive
                      ? Padding(
                          key: const ValueKey('shop_rewarded_ad_pinned'),
                          padding: const EdgeInsets.only(top: 10),
                          child: _buildRewardedAdCard(context),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('shop_rewarded_ad_hidden'),
                        ),
                ),
              ),
              Divider(height: 18, color: palette.isDark ? null : palette.divider),

              // Shop items list (infinite Cleric stat upgrades first, then unlocks)
              Expanded(
                child: ListView(
                  cacheExtent: 1000,
                  children: [
                    _InfiniteStatUpgradeTile(
                      cardKey: const ValueKey('shop_upgrade_max_hp_card'),
                      buttonKey: const ValueKey('shop_upgrade_max_hp_button'),
                      icon: Icons.favorite_rounded,
                      iconColor: palette.dangerText,
                      title: loc.t(
                        'upgrade_max_hp_title',
                        fallback: '+1 Max HP',
                      ),
                      subtitle: loc.t(
                        'upgrade_max_hp_desc',
                        fallback:
                            "Permanently raises your Cleric's maximum HP by +1 for this campaign.",
                      ),
                      statusText:
                          'Lv. ${controller.hpUpgradeLevel} • ${controller.playerMaxHp} → ${controller.playerMaxHp + 1} HP',
                      actionLabel: loc.t(
                        'stat_upgrade_action_label',
                        fallback: 'Upgrade',
                      ),
                      cost: controller.nextMaxHpUpgradeCost,
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
                                  loc.t(
                                    'string79',
                                    fallback: 'Not enough Elemental Orbs',
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        }
                      },
                    ),
                    _InfiniteStatUpgradeTile(
                      cardKey: const ValueKey('shop_upgrade_max_mana_card'),
                      buttonKey: const ValueKey('shop_upgrade_max_mana_button'),
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFF00B0FF),
                      title: loc.t(
                        'upgrade_max_mana_title',
                        fallback: '+1 Max Mana Pool',
                      ),
                      subtitle: loc.t(
                        'upgrade_max_mana_desc',
                        fallback:
                            "Permanently expands your Cleric's maximum Mana Pool by +1 turn per battle.",
                      ),
                      statusText:
                          'Lv. ${controller.manaUpgradeLevel} • ${controller.playerMaxMana} → ${controller.playerMaxMana + 1} ${loc.t('mana_label', fallback: 'Mana')}',
                      actionLabel: loc.t(
                        'stat_upgrade_action_label',
                        fallback: 'Upgrade',
                      ),
                      cost: controller.nextMaxManaUpgradeCost,
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
                                  loc.t(
                                    'string79',
                                    fallback: 'Not enough Elemental Orbs',
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                        }
                      },
                    ),
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
                      title: loc.t(
                        'string56',
                        fallback: 'Unlock Earth & Metal',
                      ),
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
                      title: loc.t(
                        'string40',
                        fallback: 'Show Markov Algorithm',
                      ),
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
                      title: loc.t(
                        'string41',
                        fallback: 'Your Prediction Hint',
                      ),
                      subtitle: loc.t(
                        'your_prediction_desc',
                        fallback:
                            'Displays the move(s) the AI predicts you will play next',
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
                      label: const Text(
                        'Restore Purchases',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('shop_close_button'),
                    style: palette.isDark
                        ? null
                        : TextButton.styleFrom(
                            foregroundColor: palette.amberText,
                          ),
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
                FittedBox(
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
                        child: Icon(
                          move.elementalIcon,
                          key: ValueKey('shop_ad_orb_icon_${move.name}'),
                          size: 15,
                          color: palette.elementalText(move),
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
                              color: palette.elementalText(entry.key),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: palette.elementalText(entry.key),
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
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String statusText;
  final String actionLabel;
  final ElementalCost cost;
  final VoidCallback onPurchase;

  const _InfiniteStatUpgradeTile({
    required this.cardKey,
    required this.buttonKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.actionLabel,
    required this.cost,
    required this.onPurchase,
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
                        Icon(icon, size: 16, color: iconColor),
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
                const SizedBox(height: 6),
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
                                  color: palette.elementalText(entry.key),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${entry.value}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: palette.elementalText(entry.key),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
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

