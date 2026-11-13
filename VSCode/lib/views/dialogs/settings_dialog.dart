import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../services/localization_service.dart';
import '../../services/play_games_service.dart';
import 'story_gallery_dialog.dart';

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

  Future<bool> _showAccountConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
    required Key confirmButtonKey,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.amber.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        key: const ValueKey('account_confirm_cancel_button'),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        key: confirmButtonKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: confirmColor == Colors.amber
                              ? Colors.black87
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(
                          confirmLabel,
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
      },
    );
    return confirmed == true;
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
    _showDiscreetSnackBar(
      context,
      ok
          ? 'Signed in as ${controller.playGames.playerName ?? "Player"}'
          : 'Could not connect to Google Play Games (Offline mode)',
    );
  }

  Future<void> _handleSwitchAccount(BuildContext context) async {
    controller.audio.playTapVibrate();
    final confirmed = await _showAccountConfirmationDialog(
      context: context,
      title: 'Switch Account?',
      message:
          'Switching Google Play accounts will disconnect your current cloud profile. '
          'Offline progression on this device is preserved and will only be replaced if the new cloud save holds higher progression or diamonds.',
      confirmLabel: 'Switch Account',
      confirmColor: Colors.amber,
      icon: Icons.swap_horiz_rounded,
      confirmButtonKey: const ValueKey('confirm_switch_account_button'),
    );
    if (!confirmed || !context.mounted) return;

    final ok = await controller.playGames.switchAccount();
    if (!context.mounted) return;
    _showDiscreetSnackBar(
      context,
      ok
          ? 'Switched account to ${controller.playGames.playerName ?? "Player"}'
          : 'Disconnected from Google Play Games (Offline mode)',
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    controller.audio.playTapVibrate();
    final confirmed = await _showAccountConfirmationDialog(
      context: context,
      title: 'Sign Out?',
      message:
          'While signed out, your offline progression and diamonds will only be saved locally on this device and will not sync to Google Play Cloud until you sign in again.',
      confirmLabel: 'Sign Out',
      confirmColor: Colors.redAccent,
      icon: Icons.logout_rounded,
      confirmButtonKey: const ValueKey('confirm_sign_out_button'),
    );
    if (!confirmed || !context.mounted) return;

    await controller.playGames.signOut();
    if (!context.mounted) return;
    _showDiscreetSnackBar(context, 'Signed out. Playing in offline mode.');
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

  Widget _buildDialog(BuildContext context) {
    final loc = controller.localization;
    final theme = Theme.of(context);

    final Map<String, String> languageNames = {
      'en': 'English 🇬🇧',
      'de': 'Deutsch 🇩🇪',
      'pt': 'Português 🇧🇷',
      'es': 'Español 🇪🇸',
    };

    const compactDensity = VisualDensity(horizontal: 0, vertical: -4);

    return Dialog(
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
              const Divider(height: 14),

              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('settings_scroll_view'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Player Profile / Cloud Account section
                      _PlayerProfileSection(
                        playGames: controller.playGames,
                        onSignIn: () => _handleSignIn(context),
                        onSwitchAccount: () => _handleSwitchAccount(context),
                        onSignOut: () => _handleSignOut(context),
                        onManualSync: () => _handleManualSync(context),
                      ),

                      const Divider(height: 14),

                      // Language selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.t('string55', fallback: 'Language:')),
                          DropdownButton<String>(
                            value: loc.currentLanguage,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            items: LocalizationService.supportedLanguages.map((
                              code,
                            ) {
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

                      // Dark mode toggle
                      SwitchListTile(
                        dense: true,
                        visualDensity: compactDensity,
                        contentPadding: EdgeInsets.zero,
                        title: Text(loc.t('string54', fallback: 'Dark Mode:')),
                        value: controller.darkMode,
                        onChanged: controller.toggleDarkMode,
                      ),

                      // Sound toggle
                      SwitchListTile(
                        dense: true,
                        visualDensity: compactDensity,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sound Effects:'),
                        value: controller.soundEnabled,
                        onChanged: (_) => controller.toggleSound(),
                      ),

                      SwitchListTile(
                        dense: true,
                        visualDensity: compactDensity,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Background Music:'),
                        value: controller.musicEnabled,
                        onChanged: controller.toggleMusic,
                      ),

                      // Vibration toggle
                      SwitchListTile(
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

                      // Animations toggle
                      SwitchListTile(
                        dense: true,
                        visualDensity: compactDensity,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Animations:'),
                        value: controller.animationsEnabled,
                        onChanged: controller.toggleAnimations,
                      ),

                      const Divider(height: 12),

                      // Story Memories / Lore Gallery button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('settings_story_memories_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber,
                            side: BorderSide(
                              color: Colors.amber.withValues(alpha: 0.55),
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
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

class _PlayerProfileSection extends StatelessWidget {
  final PlayGamesService playGames;
  final VoidCallback onSignIn;
  final VoidCallback onSwitchAccount;
  final VoidCallback onSignOut;
  final VoidCallback onManualSync;

  const _PlayerProfileSection({
    required this.playGames,
    required this.onSignIn,
    required this.onSwitchAccount,
    required this.onSignOut,
    required this.onManualSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = playGames.isSignedIn;
    final isBusy =
        playGames.isAuthenticating ||
        playGames.syncStatus == CloudSyncStatus.syncing;

    return Container(
      key: const ValueKey('settings_player_profile_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? Colors.amber.withValues(alpha: 0.45)
              : theme.colorScheme.outline.withValues(alpha: 0.25),
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
                      color: isConnected ? Colors.amber : Colors.grey,
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
                              ? Colors.amber
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _CloudSyncStatusBadge(
                status: playGames.syncStatus,
                isAuthenticating: playGames.isAuthenticating,
                onTap: isConnected && !isBusy ? onManualSync : null,
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
                  foregroundColor: Colors.black87,
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
                          color: Colors.black87,
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
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.amber,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${playGames.playerID ?? "Unknown"}',
                          key: const ValueKey('play_games_player_id'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Action Buttons: Switch Account & Sign Out
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('play_games_switch_account_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: BorderSide(
                        color: Colors.amber.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isBusy ? null : onSwitchAccount,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text(
                      'Switch Account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('play_games_sign_out_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isBusy ? null : onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 14),
                    label: const Text(
                      'Sign Out',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _CloudSyncStatusBadge extends StatelessWidget {
  final CloudSyncStatus status;
  final bool isAuthenticating;
  final VoidCallback? onTap;

  const _CloudSyncStatusBadge({
    required this.status,
    required this.isAuthenticating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSyncing =
        isAuthenticating || status == CloudSyncStatus.syncing;

    final IconData icon;
    final String label;
    final Color color;

    if (isSyncing) {
      icon = Icons.cloud_sync_outlined;
      label = 'Syncing...';
      color = Colors.amber;
    } else if (status == CloudSyncStatus.synced) {
      icon = Icons.cloud_done_outlined;
      label = 'Synced';
      color = Colors.greenAccent;
    } else {
      icon = Icons.cloud_off_outlined;
      label = 'Offline';
      color = Colors.grey;
    }

    return InkWell(
      key: const ValueKey('play_games_sync_status'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
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
