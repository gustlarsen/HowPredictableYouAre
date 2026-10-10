import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

class HelpDialog extends StatelessWidget {
  final LocalizationService localization;

  const HelpDialog({super.key, required this.localization});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helpText = localization.t(
      'string34',
      fallback: 'See How Predictable You Are !!\n'
          'Play Rock Paper Scissors Game and try to defeat the Artificial Intelligence (AI) Machine.\n'
          'Understand the Algorithm that Master Hand uses to Predict you.\n'
          'Reverse Engineer the Algorithm to beat the Master Hand.\n'
          'Earn Diamonds every won round.\n'
          'Unlock upgrades to help your path.',
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    localization.t('string35', fallback: 'How It Works'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helpText,
                        style: const TextStyle(height: 1.5, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💡 Pro Tip: The Markov Model',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'The AI tracks your transitions (what you play right after Rock, Paper, or Scissors). '
                              'To outsmart it, avoid repetitive patterns or unlock the Markov Transition Matrix from the shop to see what it expects!',
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localization.t('string36', fallback: 'Got It')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
