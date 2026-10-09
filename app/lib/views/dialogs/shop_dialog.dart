import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';

class ShopDialog extends StatelessWidget {
  final GameController controller;

  const ShopDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
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
                      const Icon(Icons.shopping_cart_outlined, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Upgrades & Shop',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      onUnlock: controller.unlockReset,
                      onToggle: (v) => controller.showReset = v,
                    ),
                    _ShopItemTile(
                      title: loc.t('string38', fallback: 'Predictability Score'),
                      cost: 150,
                      isUnlocked: controller.unlockedPredictability,
                      isActive: controller.showPredictability,
                      onUnlock: controller.unlockPredictability,
                      onToggle: (v) => controller.showPredictability = v,
                    ),
                    _ShopItemTile(
                      title: loc.t('string39', fallback: 'Random Move Button'),
                      cost: 300,
                      isUnlocked: controller.unlockedRandom,
                      isActive: controller.showRandom,
                      onUnlock: controller.unlockRandom,
                      onToggle: (v) => controller.showRandom = v,
                    ),
                    _ShopItemTile(
                      title: loc.t('string40', fallback: 'Show Markov Algorithm'),
                      cost: 500,
                      isUnlocked: controller.unlockedAlgorithm,
                      isActive: controller.showAlgorithm,
                      onUnlock: controller.unlockAlgorithm,
                      onToggle: controller.toggleShowAlgorithm,
                    ),
                    _ShopItemTile(
                      title: loc.t('string56', fallback: 'New Hands (Lizard & Spock)'),
                      cost: 100,
                      isUnlocked: controller.unlockedNewHands,
                      isActive: controller.showNewHands,
                      onUnlock: controller.unlockNewHands,
                      onToggle: controller.toggleShowNewHands,
                    ),
                    _ShopItemTile(
                      title: loc.t('string41', fallback: 'Your Prediction Hint'),
                      cost: 1000,
                      isUnlocked: controller.unlockedYourPrediction,
                      isActive: controller.showYourPrediction,
                      onUnlock: controller.unlockYourPrediction,
                      onToggle: controller.toggleShowYourPrediction,
                    ),
                    _ShopItemTile(
                      title: loc.t('string42', fallback: 'PC Next Move Reveal'),
                      cost: 3000,
                      isUnlocked: controller.unlockedNextMove,
                      isActive: controller.showNextMove,
                      onUnlock: controller.unlockNextMove,
                      onToggle: controller.toggleShowNextMove,
                    ),
                    _ShopItemTile(
                      title: loc.t('string43', fallback: 'Optimal Suggestion'),
                      cost: 5000,
                      isUnlocked: controller.unlockedSuggestion,
                      isActive: controller.showSuggestion,
                      onUnlock: controller.unlockSuggestion,
                      onToggle: controller.toggleShowSuggestion,
                    ),

                    const SizedBox(height: 12),
                    // Free diamonds action
                    Card(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.t('string45', fallback: 'Free Diamonds'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  '+50 💎 bonus',
                                  style: TextStyle(fontSize: 12, color: Colors.green),
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
  final VoidCallback onUnlock;
  final ValueChanged<bool> onToggle;

  const _ShopItemTile({
    required this.title,
    required this.cost,
    required this.isUnlocked,
    required this.isActive,
    required this.onUnlock,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  isUnlocked ? 'Purchased' : '$cost 💎',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked ? Colors.green : Colors.amber,
                    fontWeight: isUnlocked ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            Switch(
              value: isActive,
              onChanged: onToggle,
            )
          else
            ElevatedButton(
              onPressed: onUnlock,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(60, 32),
              ),
              child: Text('Unlock'),
            ),
        ],
      ),
    );
  }
}
