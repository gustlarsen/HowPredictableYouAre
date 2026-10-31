import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../services/localization_service.dart';

class SettingsDialog extends StatelessWidget {
  final GameController controller;

  const SettingsDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);

    final Map<String, String> languageNames = {
      'en': 'English 🇬🇧',
      'de': 'Deutsch 🇩🇪',
      'pt': 'Português 🇧🇷',
      'es': 'Español 🇪🇸',
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_outlined, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Language selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loc.t('string55', fallback: 'Language:')),
                  DropdownButton<String>(
                    value: loc.currentLanguage,
                    underline: const SizedBox.shrink(),
                    items: LocalizationService.supportedLanguages.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(languageNames[code] ?? code),
                      );
                    }).toList(),
                    onChanged: (lang) {
                      if (lang != null) controller.setLanguage(lang);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dark mode toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(loc.t('string54', fallback: 'Dark Mode:')),
                value: controller.darkMode,
                onChanged: controller.toggleDarkMode,
              ),

              // Sound toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sound Effects:'),
                value: controller.soundEnabled,
                onChanged: (_) => controller.toggleSound(),
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Background Music:'),
                value: controller.musicEnabled,
                onChanged: controller.toggleMusic,
              ),

              // Vibration toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibration:'),
                value: controller.vibrationEnabled,
                onChanged: controller.toggleVibration,
              ),

              // Animations toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Animations:'),
                value: controller.animationsEnabled,
                onChanged: controller.toggleAnimations,
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.t('string36', fallback: 'Ok')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
