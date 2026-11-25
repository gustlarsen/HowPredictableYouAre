import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../controllers/game_controller.dart';
import '../../services/localization_service.dart';
import '../../services/play_games_service.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/forfeit_flag_icon.dart';
import 'help_dialog.dart';
import 'story_gallery_dialog.dart';

class SettingsDialog extends StatefulWidget {
  final GameController controller;

  const SettingsDialog({super.key, required this.controller});

  static const String fallbackVersionLabel = 'Version 1.0.4 (104)';

  static String formatVersionLabel(String version, String buildNumber) {
    final cleanVersion = version.trim();
    final cleanBuild = buildNumber.trim();
    if (cleanVersion.isEmpty) return fallbackVersionLabel;
    if (cleanBuild.isEmpty) return 'Version $cleanVersion';
    return 'Version $cleanVersion ($cleanBuild)';
  }

  static Future<String> resolveVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.appName == 'flutter_tester' || info.version.trim().isEmpty) {
        return fallbackVersionLabel;
      }
      return formatVersionLabel(info.version, info.buildNumber);
    } catch (_) {
      return fallbackVersionLabel;
    }
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final Future<String> _versionFuture;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _versionFuture = SettingsDialog.resolveVersionLabel();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => _buildDialog(context),
    );
  }

  void _showDiscreetSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _handleSignIn(BuildContext context) async {
    controller.audio.playTapVibrate();
    final ok = await controller.playGames.signIn(silent: false);
    if (!context.mounted) return;
    final qaBonusMsg = controller.consumePendingQaBonusSnackBar();
    if (qaBonusMsg != null) {
      _showDiscreetSnackBar(context, qaBonusMsg);
      return;
    }
    _showDiscreetSnackBar(
      context,
      ok
          ? 'Signed in as ${controller.playGames.playerName ?? "Player"}'
          : controller.playGames.signInDiagnosticMessage,
    );
  }

  Future<void> _handleManualSync(BuildContext context) async {
    controller.audio.playTapVibrate();
    final ok = await controller.playGames.saveCloudData();
    if (!context.mounted) return;
    _showDiscreetSnackBar(
      context,
      ok ? 'Cloud save synced!' : 'Cloud sync unavailable (Offline)',
    );
  }

  Future<void> _handleCopyPlayerId(BuildContext context) async {
    final rawId = controller.playGames.playerID;
    if (!PlayGamesService.isValidPlayerId(rawId)) return;
    final cleanId = rawId!.trim();
    controller.audio.playTapVibrate();
    await Clipboard.setData(ClipboardData(text: cleanId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.amber,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Player ID copied',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF22252D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.amber.withValues(alpha: 0.45)),
          ),
        ),
      );
  }

  Future<void> _handleCheckForUpdates(BuildContext context) async {
    controller.audio.playTapVibrate();
    final loc = controller.localization;
    final result = await controller.checkForUpdateManually();
    if (!context.mounted) return;

    switch (result) {
      case ManualUpdateCheckResult.updateStarted:
        if (controller.consumePendingUpdateSnackBar()) {
          await _promptCompleteUpdateDialog(context);
        }
        break;
      case ManualUpdateCheckResult.updateAlreadyDownloaded:
        controller.consumePendingUpdateSnackBar();
        await _promptCompleteUpdateDialog(context);
        break;
      case ManualUpdateCheckResult.upToDate:
        _showThemedUpdateSnackBar(
          context,
          key: const ValueKey('update_up_to_date_snackbar'),
          icon: Icons.check_circle_outline_rounded,
          message: loc.t(
            'update_latest_version',
            fallback: "You're on the latest version!",
          ),
        );
        break;
      case ManualUpdateCheckResult.unavailable:
        _showThemedUpdateSnackBar(
          context,
          key: const ValueKey('update_unavailable_snackbar'),
          icon: Icons.cloud_off_rounded,
          message: loc.t(
            'update_check_unavailable',
            fallback:
                'Could not check for updates. Make sure you installed via Google Play and are online.',
          ),
        );
        break;
    }
  }

  Future<void> _promptCompleteUpdateDialog(BuildContext context) async {
    final loc = controller.localization;
    final shouldRestart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return AlertDialog(
          key: const ValueKey('update_install_dialog'),
          backgroundColor: palette.isDark ? null : palette.dialogSurface,
          surfaceTintColor: palette.isDark ? null : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                color: palette.amberIcon,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.t('update_ready_title', fallback: 'Update Ready'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette.primaryText,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            UpdateService.updateReadyMessage,
            style: TextStyle(color: palette.primaryText),
          ),
          actions: [
            TextButton(
              key: const ValueKey('update_install_later_button'),
              style: palette.isDark
                  ? null
                  : TextButton.styleFrom(foregroundColor: palette.secondaryText),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(loc.t('update_later', fallback: 'Later')),
            ),
            ElevatedButton(
              key: const ValueKey('update_install_restart_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: const Color(0xFF231F1A),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                UpdateService.restartActionLabel,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    if (shouldRestart == true) {
      await controller.completeFlexibleUpdate();
    }
  }

  void _showThemedUpdateSnackBar(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String message,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: key,
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF16181D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.amber.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: Colors.amber, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _confirmResetAllProgress(BuildContext context) async {
    controller.audio.playTapVibrate();
    final loc = controller.localization;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = AppPalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: palette.isDark ? null : palette.dialogSurface,
          surfaceTintColor: palette.isDark ? null : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            loc.t(
              'reset_all_progress_title',
              fallback: 'Forfeit Run?',
            ),
            style: TextStyle(color: palette.primaryText),
          ),
          content: Text(
            loc.t(
              'reset_all_progress_message',
              fallback:
                  'Ending this run counts as a defeat and returns the calendar to Week 0.\n\n• Collected Elemental Orbs and artifacts will be sent to the Royal Castle (Spoils & Relics).\n• Permanent account progress (Story Memories, Hall of Heroes, and purchased upgrades like Remove Ads) will NOT be deleted.',
            ),
            style: TextStyle(color: palette.primaryText),
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancel_reset_progress_button'),
              style: palette.isDark
                  ? null
                  : TextButton.styleFrom(foregroundColor: palette.secondaryText),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                loc.t('reset_all_progress_cancel', fallback: 'Cancel'),
              ),
            ),
            ElevatedButton(
              key: const ValueKey('confirm_reset_progress_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.dangerText,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                loc.t('reset_all_progress', fallback: 'Forfeit Run'),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReset == true && context.mounted) {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final gameController = controller;
      navigator.popUntil((route) => route.isFirst);
      await gameController.resetAllProgress();
      messenger.hideCurrentSnackBar();
      if (gameController.pendingStoryChapter == null) {
        final qaBonusMsg = gameController.consumePendingQaBonusSnackBar();
        final message = qaBonusMsg ??
            loc.t(
              'reset_all_progress_done',
              fallback:
                  'Run forfeited! Returned to Week 0 — visit the Royal Castle to recover Spoils & Relics.',
            );
        messenger.showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 2200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          ),
        );
      }
    }
  }

  Widget _buildDialog(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    final Map<String, String> languageNames = {
      'en': 'English 🇬🇧',
      'de': 'Deutsch 🇩🇪',
      'pt': 'Português 🇧🇷',
      'es': 'Español 🇪🇸',
    };

    const compactDensity = VisualDensity(horizontal: 0, vertical: -2);
    final isDark = palette.isDark;

    return Dialog(
      backgroundColor: isDark ? null : palette.dialogSurface,
      surfaceTintColor: isDark ? null : Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.settings_outlined, color: palette.blueAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: palette.primaryText,
                    ),
                  ),
                ],
              ),
              Divider(height: 14, color: isDark ? null : palette.divider),

              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('settings_scroll_view'),
                  child: SwitchTheme(
                    data: SwitchThemeData(
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return palette.amberIcon;
                        }
                        return isDark
                            ? const Color(0xFFD5D9E2)
                            : palette.secondaryText;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return palette.amberBorder.withValues(
                            alpha: isDark ? 0.35 : 0.28,
                          );
                        }
                        return isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.08);
                      }),
                      trackOutlineColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return palette.amberBorder.withValues(alpha: 0.80);
                        }
                        return isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : palette.mutedText.withValues(alpha: 0.45);
                      }),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Player Profile / Cloud Account section
                        _PlayerProfileSection(
                          playGames: controller.playGames,
                          onSignIn: () => _handleSignIn(context),
                          onManualSync: () => _handleManualSync(context),
                          onCopyPlayerId: () => _handleCopyPlayerId(context),
                        ),

                        Divider(
                          height: 16,
                          color: isDark ? null : palette.divider,
                        ),

                        // Language selector
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  loc.t('string55', fallback: 'Language:'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: loc.currentLanguage,
                                isDense: true,
                                underline: const SizedBox.shrink(),
                                items: LocalizationService.supportedLanguages
                                    .map((code) {
                                      return DropdownMenuItem(
                                        value: code,
                                        child: Text(languageNames[code] ?? code),
                                      );
                                    })
                                    .toList(),
                                onChanged: (lang) {
                                  if (lang != null) {
                                    controller.setLanguage(lang);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Dark mode toggle
                        SwitchListTile(
                          key: const ValueKey('settings_dark_mode_tile'),
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            loc.t('string54', fallback: 'Dark Mode:'),
                          ),
                          value: controller.darkMode,
                          onChanged: controller.toggleDarkMode,
                        ),
                        const SizedBox(height: 10),

                        // Sound toggle
                        SwitchListTile(
                          key: const ValueKey('settings_sound_effects_tile'),
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Sound Effects:'),
                          value: controller.soundEnabled,
                          onChanged: (_) => controller.toggleSound(),
                        ),
                        const SizedBox(height: 10),

                        SwitchListTile(
                          key: const ValueKey('settings_background_music_tile'),
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Background Music:'),
                          value: controller.musicEnabled,
                          onChanged: controller.toggleMusic,
                        ),
                        const SizedBox(height: 10),

                        // Vibration toggle
                        SwitchListTile(
                          key: const ValueKey('settings_vibration_tile'),
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Vibration:'),
                          value: controller.vibrationEnabled,
                          onChanged: (val) {
                            controller.toggleVibration(val);
                            if (val) {
                              controller.audio.playVibrate();
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // Animations toggle
                        SwitchListTile(
                          key: const ValueKey('settings_animations_tile'),
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Animations:'),
                          value: controller.animationsEnabled,
                          onChanged: controller.toggleAnimations,
                        ),
                        const SizedBox(height: 10),

                        // Confirm Battle Teleport toggle
                        SwitchListTile(
                          key: const ValueKey('settings_confirm_teleport_tile'),
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            loc.t(
                              'settings_confirm_teleport',
                              fallback: 'Confirm Battle Teleport',
                            ),
                          ),
                          value: controller.confirmBattleTeleport,
                          onChanged: controller.setConfirmBattleTeleport,
                        ),
                        const SizedBox(height: 10),

                        // Offertory Full Notification toggle
                        SwitchListTile(
                          key: const ValueKey(
                            'settings_offertory_notifications_tile',
                          ),
                          dense: true,
                          visualDensity: compactDensity,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            loc.t(
                              'settings_offertory_notifications',
                              fallback: 'Offertory Full Notification',
                            ),
                          ),
                          value: controller.offertoryNotificationsEnabled,
                          onChanged: controller.setOffertoryNotificationsEnabled,
                        ),

                        Divider(
                          height: 16,
                          color: palette.isDark ? null : palette.divider,
                        ),

                      // Story Memories / Lore Gallery button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('settings_story_memories_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.amberText,
                            backgroundColor: palette.isDark
                                ? null
                                : palette.dialogCardSurface,
                            side: BorderSide(
                              color: palette.amberBorder.withValues(
                                alpha: palette.isDark ? 0.55 : 0.72,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            controller.audio.playTapVibrate();
                            showDialog(
                              context: context,
                              builder: (_) =>
                                  StoryGalleryDialog(controller: controller),
                            );
                          },
                          icon: const Icon(
                            Icons.auto_stories_outlined,
                            size: 18,
                          ),
                          label: Text(
                            loc.t(
                              'story_gallery_title',
                              fallback: 'Story Memories',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Help / How It Works button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('settings_help_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.blueAccent,
                            backgroundColor: palette.isDark
                                ? null
                                : palette.dialogCardSurface,
                            side: BorderSide(
                              color: palette.blueAccent.withValues(
                                alpha: palette.isDark ? 0.55 : 0.65,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            controller.audio.playTapVibrate();
                            showDialog(
                              context: context,
                              builder: (_) => HelpDialog(
                                localization: loc,
                                initialFiveElements: controller.showNewHands,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.help_outline,
                            size: 18,
                          ),
                          label: Text(
                            loc.t(
                              'string35',
                              fallback: 'Help',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // GDPR / UMP Privacy & Ad Settings button (displayed when required for EEA/UK/Switzerland)
                      FutureBuilder<bool>(
                        future: controller.adService.isPrivacyOptionsRequired,
                        initialData:
                            controller.adService.isPrivacyOptionsRequiredSync,
                        builder: (context, snapshot) {
                          if (snapshot.data != true) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const ValueKey(
                                  'settings_privacy_options_button',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.isDark
                                      ? theme.colorScheme.onSurfaceVariant
                                      : palette.secondaryText,
                                  side: BorderSide(
                                    color: palette.isDark
                                        ? theme.colorScheme.outline
                                            .withValues(alpha: 0.45)
                                        : palette.sandCardBorder,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                    horizontal: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  controller.audio.playTapVibrate();
                                  controller.adService.showPrivacyOptionsForm();
                                },
                                icon: const Icon(
                                  Icons.privacy_tip_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  loc.t(
                                    'privacy_ad_settings',
                                    fallback: 'Privacy / Ad Settings',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Forfeit Run button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('settings_reset_progress_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.dangerText,
                            backgroundColor: palette.isDark
                                ? null
                                : palette.dialogCardSurface,
                            side: BorderSide(
                              color: palette.dangerText.withValues(
                                alpha: palette.isDark ? 0.55 : 0.65,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _confirmResetAllProgress(context),
                          icon: const ForfeitFlagIcon(size: 19),
                          label: Text(
                            loc.t(
                              'reset_all_progress',
                              fallback: 'Forfeit Run',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: FutureBuilder<String>(
                      future: _versionFuture,
                      initialData: SettingsDialog.fallbackVersionLabel,
                      builder: (context, snapshot) {
                        final versionText =
                            snapshot.data ??
                            SettingsDialog.fallbackVersionLabel;
                        final isBusy =
                            controller.updateService.isManualChecking ||
                            controller.updateService.isDownloading;
                        final isDownloaded =
                            controller.updateService.isUpdateDownloaded;
                        final accentColor = isBusy
                            ? palette.amberText.withValues(alpha: 0.55)
                            : palette.amberText;
                        return Tooltip(
                          message: loc.t(
                            'check_for_updates',
                            fallback: 'Check for updates',
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const ValueKey(
                                'settings_version_check_button',
                              ),
                              borderRadius: BorderRadius.circular(10),
                              splashColor: palette.amberBorder.withValues(
                                alpha: 0.16,
                              ),
                              highlightColor: palette.amberBorder.withValues(
                                alpha: 0.08,
                              ),
                              onTap: isBusy
                                  ? null
                                  : () => _handleCheckForUpdates(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.amber.withValues(
                                          alpha: isBusy ? 0.04 : 0.08,
                                        )
                                      : palette.sandCardSurface.withValues(
                                          alpha: isBusy ? 0.65 : 1.0,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: palette.amberBorder.withValues(
                                      alpha: isBusy
                                          ? 0.25
                                          : (isDark ? 0.35 : 0.55),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBusy)
                                      SizedBox(
                                        key: const ValueKey(
                                          'settings_version_loading_indicator',
                                        ),
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                          color: accentColor,
                                        ),
                                      )
                                    else
                                      Icon(
                                        isDownloaded
                                            ? Icons.system_update_rounded
                                            : Icons.refresh_rounded,
                                        key: const ValueKey(
                                          'settings_version_update_icon',
                                        ),
                                        size: 14,
                                        color: accentColor.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        versionText,
                                        key: const ValueKey(
                                          'settings_version_label',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: isBusy
                                              ? (isDark
                                                    ? theme.colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(
                                                            alpha: 0.5,
                                                          )
                                                    : palette.mutedText
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ))
                                              : (isDark
                                                    ? theme.colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(
                                                            alpha: 0.85,
                                                          )
                                                    : palette.secondaryText),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    key: const ValueKey('settings_ok_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.amberText,
                      backgroundColor: palette.isDark
                          ? Colors.amber.withValues(alpha: 0.10)
                          : palette.rewardedAdCardSurface,
                      side: BorderSide(
                        color: palette.amberBorder.withValues(
                          alpha: palette.isDark ? 0.65 : 0.85,
                        ),
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 8,
                      ),
                      minimumSize: const Size(64, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      loc.t('string36', fallback: 'Ok'),
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
}

class _PlayerProfileSection extends StatelessWidget {
  final PlayGamesService playGames;
  final VoidCallback onSignIn;
  final VoidCallback onManualSync;
  final VoidCallback onCopyPlayerId;

  const _PlayerProfileSection({
    required this.playGames,
    required this.onSignIn,
    required this.onManualSync,
    required this.onCopyPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final hasVerifiedPlayerId = PlayGamesService.isValidPlayerId(
      playGames.playerID,
    );
    final isConnected = playGames.isSignedIn && hasVerifiedPlayerId;
    final isBusy =
        playGames.isAuthenticating ||
        playGames.syncStatus == CloudSyncStatus.syncing;

    return Container(
      key: const ValueKey('settings_player_profile_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : palette.sandCardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? palette.amberBorder.withValues(
                  alpha: palette.isDark ? 0.45 : 0.72,
                )
              : (palette.isDark
                    ? theme.colorScheme.outline.withValues(alpha: 0.25)
                    : palette.sandCardBorder),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header + Cloud Sync Status Badge
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sports_esports_rounded,
                      size: 16,
                      color: isConnected
                          ? palette.amberIcon
                          : (palette.isDark ? Colors.grey : palette.mutedText),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Player Profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isConnected
                              ? palette.amberText
                              : palette.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _CloudSyncStatusBadge(
                status: playGames.syncStatus,
                isConnected: isConnected,
                isAuthenticating: playGames.isAuthenticating,
                onTap: isBusy ? null : (isConnected ? onManualSync : onSignIn),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (!isConnected) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('play_games_sign_in_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: const Color(0xFF231F1A),
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: playGames.isAuthenticating ? null : onSignIn,
                icon: playGames.isAuthenticating
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF231F1A),
                        ),
                      )
                    : const Icon(Icons.sports_esports_rounded, size: 17),
                label: Text(
                  playGames.isAuthenticating
                      ? 'Connecting...'
                      : 'Sign in with Google Play',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Connected Profile Details
            Container(
              key: const ValueKey('play_games_profile_card'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: palette.isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : palette.dialogCardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.isDark
                      ? Colors.amber.withValues(alpha: 0.2)
                      : palette.sandCardBorder,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: palette.amberBorder.withValues(
                      alpha: palette.isDark ? 0.2 : 0.18,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: palette.amberIcon,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playGames.playerName ?? 'Play Games Player',
                          key: const ValueKey('play_games_player_name'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: palette.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'ID: ${playGames.playerID ?? "Unknown"}',
                                key: const ValueKey('play_games_player_id'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  color: palette.isDark
                                      ? theme.colorScheme.onSurfaceVariant
                                      : palette.secondaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              key: const ValueKey('play_games_copy_id_button'),
                              borderRadius: BorderRadius.circular(6),
                              onTap: onCopyPlayerId,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: palette.amberText.withValues(
                                    alpha: palette.isDark ? 0.85 : 0.95,
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
          ],
        ],
      ),
    );
  }
}

class _CloudSyncStatusBadge extends StatelessWidget {
  final CloudSyncStatus status;
  final bool isConnected;
  final bool isAuthenticating;
  final VoidCallback? onTap;

  const _CloudSyncStatusBadge({
    required this.status,
    required this.isConnected,
    required this.isAuthenticating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bool isConnecting = isAuthenticating && !isConnected;
    final bool isSyncing =
        isConnected && (isAuthenticating || status == CloudSyncStatus.syncing);
    final bool isBusy = isConnecting || isSyncing;

    final IconData icon;
    final String label;
    final Color color;

    if (isConnecting) {
      icon = Icons.cloud_sync_outlined;
      label = 'Connecting...';
      color = palette.amberText;
    } else if (isSyncing) {
      icon = Icons.cloud_sync_outlined;
      label = 'Syncing...';
      color = palette.amberText;
    } else if (isConnected && status == CloudSyncStatus.synced) {
      icon = Icons.cloud_done_outlined;
      label = 'Synced';
      color = palette.successText;
    } else {
      icon = Icons.cloud_off_outlined;
      label = 'Offline';
      color = palette.isDark ? Colors.grey : palette.mutedText;
    }

    return InkWell(
      key: const ValueKey('play_games_sync_status'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: palette.isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: palette.isDark ? 0.4 : 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
