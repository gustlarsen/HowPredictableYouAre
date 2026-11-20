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

/// Result of a user-initiated manual update check from Settings.
enum ManualUpdateCheckResult {
  updateStarted,
  updateAlreadyDownloaded,
  upToDate,
  unavailable,
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
  bool _isManualChecking = false;
  bool _isDownloading = false;
  bool _isCompletingUpdate = false;
  bool _isAppForeground = true;
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

  bool get isChecking => _isChecking || _isManualChecking;
  bool get isManualChecking => _isManualChecking;
  bool get isDownloading => _isDownloading;
  bool get isCompletingUpdate => _isCompletingUpdate;
  bool get isUpdateAvailable => _isUpdateAvailable;
  bool get isUpdateDownloaded => _isUpdateDownloaded;
  AppUpdateInfo? get updateInfo => _updateInfo;
  InstallStatus get installStatus => _installStatus;

  void setAppForeground(bool isForeground) {
    _isAppForeground = isForeground;
  }

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
        _isCompletingUpdate = false;
        _markUpdateDownloaded();
        break;
      case InstallStatus.installing:
      case InstallStatus.installed:
      case InstallStatus.failed:
      case InstallStatus.canceled:
      case InstallStatus.unknown:
        _isDownloading = false;
        if (status != InstallStatus.installing) {
          _isCompletingUpdate = false;
        }
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
    if (!isSupportedPlatform ||
        _isChecking ||
        _isDownloading ||
        _isUpdateDownloaded ||
        _isCompletingUpdate) {
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

  /// Manually checks Google Play for an available update when triggered by the
  /// user from Settings:
  /// - Returns [ManualUpdateCheckResult.updateAlreadyDownloaded] if an update is
  ///   already downloaded and ready to install.
  /// - Triggers [InAppUpdateClient.startFlexibleUpdate] immediately if a new
  ///   version is available and returns [ManualUpdateCheckResult.updateStarted].
  /// - Returns [ManualUpdateCheckResult.upToDate] when no update is available.
  /// - Returns [ManualUpdateCheckResult.unavailable] when offline, sideloaded,
  ///   on an unsupported platform, or when Play Services throws an error.
  Future<ManualUpdateCheckResult> checkForUpdateManually() async {
    if (!isSupportedPlatform) {
      return ManualUpdateCheckResult.unavailable;
    }

    if (_isUpdateDownloaded) {
      return ManualUpdateCheckResult.updateAlreadyDownloaded;
    }

    if (_isManualChecking || _isDownloading) {
      return ManualUpdateCheckResult.updateStarted;
    }

    _isManualChecking = true;
    notifyListeners();
    _ensureInstallListenerSubscribed();

    try {
      final info = await _client.checkForUpdate();
      _updateInfo = info;
      _installStatus = info.installStatus;
      _isUpdateAvailable =
          info.updateAvailability == UpdateAvailability.updateAvailable;

      if (info.installStatus == InstallStatus.downloaded) {
        _isManualChecking = false;
        _isDownloading = false;
        _markUpdateDownloaded();
        return ManualUpdateCheckResult.updateAlreadyDownloaded;
      }

      if (info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress &&
          (info.installStatus == InstallStatus.pending ||
              info.installStatus == InstallStatus.downloading)) {
        _isManualChecking = false;
        _isDownloading = true;
        notifyListeners();
        return ManualUpdateCheckResult.updateStarted;
      }

      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.flexibleUpdateAllowed) {
        _isManualChecking = false;
        _isDownloading = true;
        notifyListeners();

        final result = await _client.startFlexibleUpdate();
        _isDownloading = false;
        if (result == AppUpdateResult.success) {
          _markUpdateDownloaded();
          return ManualUpdateCheckResult.updateStarted;
        }
        notifyListeners();
        if (result == AppUpdateResult.inAppUpdateFailed) {
          return ManualUpdateCheckResult.unavailable;
        }
        return ManualUpdateCheckResult.updateStarted;
      }

      _isManualChecking = false;
      notifyListeners();
      if (info.updateAvailability == UpdateAvailability.updateNotAvailable) {
        return ManualUpdateCheckResult.upToDate;
      }

      return ManualUpdateCheckResult.unavailable;
    } catch (_) {
      _isManualChecking = false;
      _isDownloading = false;
      notifyListeners();
      return ManualUpdateCheckResult.unavailable;
    }
  }

  /// Re-checks whether a background flexible update finished downloading or
  /// completed/canceled installation while the app was backgrounded.
  Future<void> handleAppResumed() async {
    _isAppForeground = true;
    if (!isSupportedPlatform) {
      return;
    }
    final wasCompleting = _isCompletingUpdate;
    _isCompletingUpdate = false;
    if (!_isDownloading && !wasCompleting) {
      return;
    }
    try {
      final info = await _client.checkForUpdate();
      _updateInfo = info;
      _installStatus = info.installStatus;
      if (info.installStatus == InstallStatus.downloaded) {
        _isDownloading = false;
        _markUpdateDownloaded();
      } else if (info.installStatus == InstallStatus.installed ||
          info.updateAvailability == UpdateAvailability.updateNotAvailable) {
        _isDownloading = false;
        _isUpdateDownloaded = false;
        notifyListeners();
      } else if (wasCompleting) {
        notifyListeners();
      }
    } catch (_) {
      // Fail silently on resume check errors.
      if (wasCompleting) {
        notifyListeners();
      }
    }
  }

  /// Triggers the final installation and restart for a downloaded flexible
  /// update via Play Core's `completeFlexibleUpdate()`.
  ///
  /// Guards against duplicate calls and background invocations so Play Core
  /// restarts the Activity cleanly while the Flutter window is active.
  Future<bool> completeFlexibleUpdate() async {
    if (!isSupportedPlatform || _isCompletingUpdate || !_isAppForeground) {
      return false;
    }
    final wasDownloaded = _isUpdateDownloaded;
    _isCompletingUpdate = true;
    _isUpdateDownloaded = false;
    _installStatus = InstallStatus.installing;
    notifyListeners();
    try {
      await _client.completeFlexibleUpdate();
      _isCompletingUpdate = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isCompletingUpdate = false;
      _isUpdateDownloaded = wasDownloaded;
      _installStatus = wasDownloaded
          ? InstallStatus.downloaded
          : InstallStatus.unknown;
      notifyListeners();
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
