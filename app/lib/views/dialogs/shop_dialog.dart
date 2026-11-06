import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/game_controller.dart';

class ShopDialog extends StatelessWidget {
  final GameController controller;

  const ShopDialog({super.key, required this.controller});

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
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: Unlocked and Enabled!'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('string79', fallback: 'Not enough Diamonds')),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: '+50 💎',
            onPressed: () => controller.addFreeDiamonds(50),
          ),
        ),
      );
    }
  }

  void _handleToggle(BuildContext context, String title, bool enabled) {
    HapticFeedback.selectionClick();
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

  Widget _buildDialog(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);

    final enabledStr = loc.t('string49', fallback: 'Enabled');
    final disabledStr = loc.t('string48', fallback: 'Disabled');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Upgrades & Shop',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '${controller.diamonds}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Shop items list
              Expanded(
                child: ListView(
                  children: [
                    _ShopItemTile(
                      title: loc.t('string37', fallback: 'Reset Button'),
                      cost: 100,
                      isUnlocked: controller.unlockedReset,
                      isActive: controller.showReset,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockReset();
                        _handleUnlock(context, loc.t('string37', fallback: 'Reset Button'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowReset(val);
                        _handleToggle(context, loc.t('string37', fallback: 'Reset Button'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t(
                        'string38',
                        fallback: 'Predictability Score',
                      ),
                      cost: 150,
                      isUnlocked: controller.unlockedPredictability,
                      isActive: controller.showPredictability,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockPredictability();
                        _handleUnlock(context, loc.t('string38', fallback: 'Predictability Score'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowPredictability(val);
                        _handleToggle(context, loc.t('string38', fallback: 'Predictability Score'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t('string39', fallback: 'Random Move Button'),
                      cost: 300,
                      isUnlocked: controller.unlockedRandom,
                      isActive: controller.showRandom,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockRandom();
                        _handleUnlock(context, loc.t('string39', fallback: 'Random Move Button'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowRandom(val);
                        _handleToggle(context, loc.t('string39', fallback: 'Random Move Button'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t(
                        'string40',
                        fallback: 'Show Markov Algorithm',
                      ),
                      cost: 500,
                      isUnlocked: controller.unlockedAlgorithm,
                      isActive: controller.showAlgorithm,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockAlgorithm();
                        _handleUnlock(context, loc.t('string40', fallback: 'Show Markov Algorithm'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowAlgorithm(val);
                        _handleToggle(context, loc.t('string40', fallback: 'Show Markov Algorithm'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t(
                        'string56',
                        fallback: 'New Hands (Lizard & Spock)',
                      ),
                      cost: 100,
                      isUnlocked: controller.unlockedNewHands,
                      isActive: controller.showNewHands,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockNewHands();
                        _handleUnlock(context, loc.t('string56', fallback: 'New Hands (Lizard & Spock)'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowNewHands(val);
                        _handleToggle(context, loc.t('string56', fallback: 'New Hands (Lizard & Spock)'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t(
                        'string41',
                        fallback: 'Your Prediction Hint',
                      ),
                      cost: 1000,
                      isUnlocked: controller.unlockedYourPrediction,
                      isActive: controller.showYourPrediction,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockYourPrediction();
                        _handleUnlock(context, loc.t('string41', fallback: 'Your Prediction Hint'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowYourPrediction(val);
                        _handleToggle(context, loc.t('string41', fallback: 'Your Prediction Hint'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t('string42', fallback: 'PC Next Move Reveal'),
                      cost: 3000,
                      isUnlocked: controller.unlockedNextMove,
                      isActive: controller.showNextMove,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockNextMove();
                        _handleUnlock(context, loc.t('string42', fallback: 'PC Next Move Reveal'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowNextMove(val);
                        _handleToggle(context, loc.t('string42', fallback: 'PC Next Move Reveal'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t('string43', fallback: 'Optimal Suggestion'),
                      cost: 5000,
                      isUnlocked: controller.unlockedSuggestion,
                      isActive: controller.showSuggestion,
                      enabledLabel: enabledStr,
                      disabledLabel: disabledStr,
                      onUnlock: () {
                        final ok = controller.unlockSuggestion();
                        _handleUnlock(context, loc.t('string43', fallback: 'Optimal Suggestion'), ok);
                      },
                      onToggle: (val) {
                        controller.toggleShowSuggestion(val);
                        _handleToggle(context, loc.t('string43', fallback: 'Optimal Suggestion'), val);
                      },
                    ),
                    _ShopItemTile(
                      title: loc.t('string44', fallback: 'Remove Ads'),
                      cost: 10000,
                      isUnlocked: controller.unlockedAds,
                      isActive: controller.unlockedAds,
                      enabledLabel: 'Ads Removed',
                      disabledLabel: 'Not Active',
                      onUnlock: () {
                        final ok = controller.unlockAds();
                        _handleUnlock(context, loc.t('string44', fallback: 'Remove Ads'), ok);
                      },
                      onToggle: (_) {},
                    ),
                    _ShopItemTile(
                      title: 'Source Code Link',
                      cost: 100,
                      isUnlocked: controller.unlockedSourceCode,
                      isActive: controller.unlockedSourceCode,
                      enabledLabel: 'Unlocked',
                      disabledLabel: 'Locked',
                      onUnlock: () {
                        final ok = controller.unlockSourceCode();
                        _handleUnlock(context, 'Source Code', ok);
                      },
                      onToggle: (_) {},
                    ),

                    const SizedBox(height: 12),
                    // Free diamonds action
                    Card(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.t('string45', fallback: 'Free Diamonds'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '+50 💎 bonus',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                controller.addFreeDiamonds(50);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('+50 💎 Diamonds added!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.card_giftcard, size: 16),
                              label: const Text('Claim'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.t('string36', fallback: 'Close')),
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
  final int cost;
  final bool isUnlocked;
  final bool isActive;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback onUnlock;
  final ValueChanged<bool> onToggle;

  const _ShopItemTile({
    required this.title,
    required this.cost,
    required this.isUnlocked,
    required this.isActive,
    required this.enabledLabel,
    required this.disabledLabel,
    required this.onUnlock,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: isUnlocked && isActive
            ? Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isUnlocked ? () => onToggle(!isActive) : onUnlock,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (!isUnlocked)
                        Text(
                          '$cost 💎',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? Icons.check_circle : Icons.cancel_outlined,
                              size: 13,
                              color: isActive ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? enabledLabel : disabledLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  Switch(
                    value: isActive,
                    onChanged: onToggle,
                    activeTrackColor: Colors.green,
                  )
                else
                  ElevatedButton(
                    onPressed: onUnlock,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      minimumSize: const Size(64, 34),
                    ),
                    child: const Text('Unlock'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
