import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Abstraction over static [InAppUpdate] calls so that [UpdateService]
/// uses the official `in_app_update` Google Play Core wrapper in production
/// while remaining deterministically testable in unit and widget tests.
abstract class InAppUpdateClient {
  Stream<InstallStatus> get installUpdateListener;
  Future<AppUpdateInfo> checkForUpdate();
  Future<AppUpdateResult> startFlexibleUpdate();
  Future<void> completeFlexibleUpdate();
}

/// Default production implementation of [InAppUpdateClient] backed by
/// the official `in_app_update` plugin.
class DefaultInAppUpdateClient implements InAppUpdateClient {
  const DefaultInAppUpdateClient();

  @override
  Stream<InstallStatus> get installUpdateListener =>
      InAppUpdate.installUpdateListener;

  @override
  Future<AppUpdateInfo> checkForUpdate() => InAppUpdate.checkForUpdate();

  @override
  Future<AppUpdateResult> startFlexibleUpdate() =>
      InAppUpdate.startFlexibleUpdate();

  @override
  Future<void> completeFlexibleUpdate() =>
      InAppUpdate.completeFlexibleUpdate();
}

/// Manages Google Play In-App Updates in Flexible mode with silent offline
/// and sideloaded-build fallback.
class UpdateService extends ChangeNotifier {
  static const String updateReadyMessage =
      'Update ready! Restart to apply the latest version.';
  static const String restartActionLabel = 'RESTART';

  final InAppUpdateClient _client;
  final bool? _isAndroidOverride;
  StreamSubscription<InstallStatus>? _installStatusSubscription;

  bool _isChecking = false;
  bool _isDownloading = false;
  bool _isUpdateAvailable = false;
  bool _isUpdateDownloaded = false;
  AppUpdateInfo? _updateInfo;
  InstallStatus _installStatus = InstallStatus.unknown;

  /// Invoked when a flexible update finishes downloading (or is already
  /// downloaded and pending installation) so the UI layer can prompt the
  /// player to restart and apply the update.
  VoidCallback? onUpdateDownloaded;

  UpdateService({
    InAppUpdateClient? client,
    bool? isAndroidOverride,
    this.onUpdateDownloaded,
  }) : _client = client ?? const DefaultInAppUpdateClient(),
       _isAndroidOverride = isAndroidOverride;

  /// Restricts all Play Core update checks strictly to Android devices,
  /// returning false on non-Android or web platforms.
  bool get isSupportedPlatform =>
      _isAndroidOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  bool get isUpdateAvailable => _isUpdateAvailable;
  bool get isUpdateDownloaded => _isUpdateDownloaded;
  AppUpdateInfo? get updateInfo => _updateInfo;
  InstallStatus get installStatus => _installStatus;

  void _ensureInstallListenerSubscribed() {
    if (_installStatusSubscription != null) return;
    try {
      _installStatusSubscription = _client.installUpdateListener.listen(
        _handleInstallStatusChanged,
        onError: (_) {
          // Fail silently if the Play Core state stream emits an error.
        },
      );
    } catch (_) {
      // Fail silently if the EventChannel is unavailable.
    }
  }

  void _handleInstallStatusChanged(InstallStatus status) {
    _installStatus = status;
    switch (status) {
      case InstallStatus.pending:
      case InstallStatus.downloading:
        _isDownloading = true;
        notifyListeners();
        break;
      case InstallStatus.downloaded:
        _isDownloading = false;
        _markUpdateDownloaded();
        break;
      case InstallStatus.installing:
      case InstallStatus.installed:
      case InstallStatus.failed:
      case InstallStatus.canceled:
      case InstallStatus.unknown:
        _isDownloading = false;
        notifyListeners();
        break;
    }
  }

  void _markUpdateDownloaded() {
    final wasAlreadyDownloaded = _isUpdateDownloaded;
    _isUpdateDownloaded = true;
    _installStatus = InstallStatus.downloaded;
    if (!wasAlreadyDownloaded) {
      onUpdateDownloaded?.call();
    }
    notifyListeners();
  }

  /// Asynchronously checks Google Play for an available update and manages
  /// the Flexible update lifecycle:
  /// 1. Returns silently on non-Android or web platforms.
  /// 2. If an update is already downloaded (`InstallStatus.downloaded`),
  ///    immediately notifies the UI layer to prompt installation.
  /// 3. If a newer version is available and flexible updates are permitted,
  ///    starts the native Google Play flexible update flow in the background.
  /// 4. Once the background download finishes, notifies the UI layer so the
  ///    player can trigger the final installation and restart.
  /// 5. Fails silently when offline, sideloaded, or missing Play Services.
  Future<void> checkForUpdate() async {
    if (!isSupportedPlatform || _isChecking) {
      return;
    }

    _isChecking = true;
    _ensureInstallListenerSubscribed();

    try {
      final info = await _client.checkForUpdate();
      _updateInfo = info;
      _installStatus = info.installStatus;
      _isUpdateAvailable =
          info.updateAvailability == UpdateAvailability.updateAvailable;

      // 1. Update already downloaded and waiting to be installed
      if (info.installStatus == InstallStatus.downloaded) {
        _isChecking = false;
        _isDownloading = false;
        _markUpdateDownloaded();
        return;
      }

      // 2. Newer version available and flexible update permitted
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.flexibleUpdateAllowed) {
        _isChecking = false;
        _isDownloading = true;
        notifyListeners();

        final result = await _client.startFlexibleUpdate();
        _isDownloading = false;
        if (result == AppUpdateResult.success) {
          _markUpdateDownloaded();
        } else {
          notifyListeners();
        }
        return;
      }

      _isChecking = false;
      notifyListeners();
    } catch (_) {
      // Silent fallback when offline, sideloaded, or Play Services unavailable.
      _isChecking = false;
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// Re-checks whether a background flexible update finished downloading while
  /// the app was backgrounded.
  Future<void> handleAppResumed() async {
    if (!isSupportedPlatform || !_isDownloading) {
      return;
    }
    try {
      final info = await _client.checkForUpdate();
      _updateInfo = info;
      _installStatus = info.installStatus;
      if (info.installStatus == InstallStatus.downloaded) {
        _isDownloading = false;
        _markUpdateDownloaded();
      }
    } catch (_) {
      // Fail silently on resume check errors.
    }
  }

  /// Triggers the final installation and restart for a downloaded flexible
  /// update via Play Core's `completeFlexibleUpdate()`.
  Future<bool> completeFlexibleUpdate() async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      await _client.completeFlexibleUpdate();
      _isUpdateDownloaded = false;
      _installStatus = InstallStatus.installing;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _installStatusSubscription?.cancel();
    _installStatusSubscription = null;
    super.dispose();
  }
}
