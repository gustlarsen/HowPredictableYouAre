import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/services/update_service.dart';

class FakeInAppUpdateClient implements InAppUpdateClient {
  final StreamController<InstallStatus> installStatusController =
      StreamController<InstallStatus>.broadcast();

  AppUpdateInfo updateInfo;
  AppUpdateResult flexibleUpdateResult;
  bool shouldThrowOnCheck;
  bool shouldThrowOnStartFlexible;
  bool shouldThrowOnComplete;
  Completer<AppUpdateInfo>? checkForUpdateCompleter;
  Completer<AppUpdateResult>? flexibleUpdateCompleter;

  int checkForUpdateCallCount = 0;
  int startFlexibleUpdateCallCount = 0;
  int completeFlexibleUpdateCallCount = 0;

  FakeInAppUpdateClient({
    AppUpdateInfo? updateInfo,
    this.flexibleUpdateResult = AppUpdateResult.success,
    this.shouldThrowOnCheck = false,
    this.shouldThrowOnStartFlexible = false,
    this.shouldThrowOnComplete = false,
    this.checkForUpdateCompleter,
    this.flexibleUpdateCompleter,
  }) : updateInfo =
           updateInfo ??
           AppUpdateInfo(
             updateAvailability: UpdateAvailability.updateNotAvailable,
             immediateUpdateAllowed: false,
             immediateAllowedPreconditions: const [],
             flexibleUpdateAllowed: false,
             flexibleAllowedPreconditions: const [],
             availableVersionCode: 104,
             installStatus: InstallStatus.unknown,
             packageName: 'com.howpredictable.app',
             clientVersionStalenessDays: null,
             updatePriority: 0,
           );

  @override
  Stream<InstallStatus> get installUpdateListener =>
      installStatusController.stream;

  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    checkForUpdateCallCount++;
    if (checkForUpdateCompleter != null) {
      return checkForUpdateCompleter!.future;
    }
    if (shouldThrowOnCheck) {
      throw PlatformException(
        code: 'TASK_FAILURE',
        message: 'Install Error(-6): Device is offline or sideloaded.',
      );
    }
    return updateInfo;
  }

  @override
  Future<AppUpdateResult> startFlexibleUpdate() async {
    startFlexibleUpdateCallCount++;
    if (shouldThrowOnStartFlexible) {
      throw PlatformException(
        code: 'IN_APP_UPDATE_FAILED',
        message: 'Flexible update failed to start.',
      );
    }
    if (flexibleUpdateCompleter != null) {
      return flexibleUpdateCompleter!.future;
    }
    return flexibleUpdateResult;
  }

  @override
  Future<void> completeFlexibleUpdate() async {
    completeFlexibleUpdateCallCount++;
    if (shouldThrowOnComplete) {
      throw PlatformException(
        code: 'COMPLETE_UPDATE_FAILED',
        message: 'Could not complete flexible update.',
      );
    }
  }

  void emitInstallStatus(InstallStatus status) {
    installStatusController.add(status);
  }

  void dispose() {
    installStatusController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService & Google Play In-App Updates Tests', () {
    test(
      '1. Starts a flexible update when a newer version is available and notifies UI when background download finishes',
      () async {
        final downloadCompleter = Completer<AppUpdateResult>();
        final fakeClient = FakeInAppUpdateClient(
          updateInfo: AppUpdateInfo(
            updateAvailability: UpdateAvailability.updateAvailable,
            immediateUpdateAllowed: true,
            immediateAllowedPreconditions: const [],
            flexibleUpdateAllowed: true,
            flexibleAllowedPreconditions: const [],
            availableVersionCode: 105,
            installStatus: InstallStatus.pending,
            packageName: 'com.howpredictable.app',
            clientVersionStalenessDays: 2,
            updatePriority: 3,
          ),
          flexibleUpdateCompleter: downloadCompleter,
        );
        addTearDown(fakeClient.dispose);

        int downloadedCallbackCount = 0;
        final updateService = UpdateService(
          client: fakeClient,
          onUpdateDownloaded: () {
            downloadedCallbackCount++;
          },
        );
        addTearDown(updateService.dispose);

        final checkFuture = updateService.checkForUpdate();
        await Future<void>.delayed(Duration.zero);

        expect(fakeClient.checkForUpdateCallCount, 1);
        expect(fakeClient.startFlexibleUpdateCallCount, 1);
        expect(updateService.isUpdateAvailable, isTrue);
        expect(updateService.isDownloading, isTrue);
        expect(updateService.isUpdateDownloaded, isFalse);
        expect(downloadedCallbackCount, 0);

        // Emit background downloading progress then downloaded completion
        fakeClient.emitInstallStatus(InstallStatus.downloading);
        await Future<void>.delayed(Duration.zero);
        expect(updateService.installStatus, InstallStatus.downloading);
        expect(updateService.isDownloading, isTrue);

        fakeClient.emitInstallStatus(InstallStatus.downloaded);
        downloadCompleter.complete(AppUpdateResult.success);
        await checkFuture;

        expect(updateService.isDownloading, isFalse);
        expect(updateService.isUpdateDownloaded, isTrue);
        expect(updateService.installStatus, InstallStatus.downloaded);
        // Callback is invoked exactly once even if both stream and future complete
        expect(downloadedCallbackCount, 1);
      },
    );

    test(
      '2. Prompts installation immediately when an update is already downloaded without starting a duplicate download',
      () async {
        final fakeClient = FakeInAppUpdateClient(
          updateInfo: AppUpdateInfo(
            updateAvailability:
                UpdateAvailability.developerTriggeredUpdateInProgress,
            immediateUpdateAllowed: true,
            immediateAllowedPreconditions: const [],
            flexibleUpdateAllowed: true,
            flexibleAllowedPreconditions: const [],
            availableVersionCode: 105,
            installStatus: InstallStatus.downloaded,
            packageName: 'com.howpredictable.app',
            clientVersionStalenessDays: 1,
            updatePriority: 2,
          ),
        );
        addTearDown(fakeClient.dispose);

        bool promptedInstallation = false;
        final updateService = UpdateService(
          client: fakeClient,
          onUpdateDownloaded: () {
            promptedInstallation = true;
          },
        );
        addTearDown(updateService.dispose);

        await updateService.checkForUpdate();

        expect(fakeClient.checkForUpdateCallCount, 1);
        expect(fakeClient.startFlexibleUpdateCallCount, 0);
        expect(updateService.isUpdateDownloaded, isTrue);
        expect(promptedInstallation, isTrue);

        // Completing the flexible update calls Play Core completeFlexibleUpdate
        final completed = await updateService.completeFlexibleUpdate();
        expect(completed, isTrue);
        expect(fakeClient.completeFlexibleUpdateCallCount, 1);
        expect(updateService.isUpdateDownloaded, isFalse);
      },
    );

    test(
      '3. Silent, graceful fallback when offline, sideloaded, or when the store check throws an exception',
      () async {
        final fakeClient = FakeInAppUpdateClient(
          shouldThrowOnCheck: true,
          shouldThrowOnStartFlexible: true,
          shouldThrowOnComplete: true,
        );
        addTearDown(fakeClient.dispose);

        bool callbackTriggered = false;
        final updateService = UpdateService(
          client: fakeClient,
          onUpdateDownloaded: () {
            callbackTriggered = true;
          },
        );
        addTearDown(updateService.dispose);

        // Must not throw when checkForUpdate fails
        await expectLater(updateService.checkForUpdate(), completes);
        expect(fakeClient.checkForUpdateCallCount, 1);
        expect(fakeClient.startFlexibleUpdateCallCount, 0);
        expect(updateService.isChecking, isFalse);
        expect(updateService.isDownloading, isFalse);
        expect(updateService.isUpdateDownloaded, isFalse);
        expect(callbackTriggered, isFalse);

        // Must not throw when completeFlexibleUpdate fails
        final completeResult = await updateService.completeFlexibleUpdate();
        expect(completeResult, isFalse);
      },
    );

    test(
      '4. Restricts all update checks strictly to Android devices, returning silently on non-Android platforms',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          final fakeClient = FakeInAppUpdateClient(
            updateInfo: AppUpdateInfo(
              updateAvailability: UpdateAvailability.updateAvailable,
              immediateUpdateAllowed: true,
              immediateAllowedPreconditions: const [],
              flexibleUpdateAllowed: true,
              flexibleAllowedPreconditions: const [],
              availableVersionCode: 105,
              installStatus: InstallStatus.unknown,
              packageName: 'com.howpredictable.app',
              clientVersionStalenessDays: null,
              updatePriority: 0,
            ),
          );
          addTearDown(fakeClient.dispose);

          final updateService = UpdateService(client: fakeClient);
          addTearDown(updateService.dispose);

          expect(updateService.isSupportedPlatform, isFalse);
          await updateService.checkForUpdate();

          expect(fakeClient.checkForUpdateCallCount, 0);
          expect(fakeClient.startFlexibleUpdateCallCount, 0);
          expect(await updateService.completeFlexibleUpdate(), isFalse);
          expect(fakeClient.completeFlexibleUpdateCallCount, 0);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      '5. GameScreen triggers non-blocking update check after initial frame render and shows dark/amber SnackBar with RESTART action when downloaded',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakeInAppUpdateClient(
          updateInfo: AppUpdateInfo(
            updateAvailability: UpdateAvailability.updateAvailable,
            immediateUpdateAllowed: true,
            immediateAllowedPreconditions: const [],
            flexibleUpdateAllowed: true,
            flexibleAllowedPreconditions: const [],
            availableVersionCode: 105,
            installStatus: InstallStatus.pending,
            packageName: 'com.howpredictable.app',
            clientVersionStalenessDays: 1,
            updatePriority: 1,
          ),
          flexibleUpdateResult: AppUpdateResult.success,
        );
        addTearDown(fakeClient.dispose);

        final updateService = UpdateService(client: fakeClient);
        addTearDown(updateService.dispose);

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          updateService: updateService,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );

        // Allow post-frame callback, async update check, and SnackBar entrance animation to finish
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(fakeClient.checkForUpdateCallCount, 1);
        expect(fakeClient.startFlexibleUpdateCallCount, 1);

        // Themed dark/amber update SnackBar is visible with RESTART button
        expect(
          find.byKey(const ValueKey('update_ready_snackbar')),
          findsOneWidget,
        );
        expect(find.text(UpdateService.updateReadyMessage), findsOneWidget);
        expect(find.text(UpdateService.restartActionLabel), findsOneWidget);

        // Tap RESTART -> triggers completeFlexibleUpdate()
        await tester.tap(find.byType(SnackBarAction));
        await tester.pump();

        expect(fakeClient.completeFlexibleUpdateCallCount, 1);
      },
    );

    test(
      '6. checkForUpdateManually returns accurate ManualUpdateCheckResult across up-to-date, update-available, already-downloaded, and error/unsupported states',
      () async {
        // A. Up to date
        final upToDateClient = FakeInAppUpdateClient();
        addTearDown(upToDateClient.dispose);
        final upToDateService = UpdateService(client: upToDateClient);
        addTearDown(upToDateService.dispose);

        expect(
          await upToDateService.checkForUpdateManually(),
          ManualUpdateCheckResult.upToDate,
        );
        expect(upToDateClient.checkForUpdateCallCount, 1);
        expect(upToDateClient.startFlexibleUpdateCallCount, 0);

        // B. Update available -> starts flexible update immediately
        final availableClient = FakeInAppUpdateClient(
          updateInfo: AppUpdateInfo(
            updateAvailability: UpdateAvailability.updateAvailable,
            immediateUpdateAllowed: false,
            immediateAllowedPreconditions: const [],
            flexibleUpdateAllowed: true,
            flexibleAllowedPreconditions: const [],
            availableVersionCode: 105,
            installStatus: InstallStatus.pending,
            packageName: 'com.howpredictable.app',
            clientVersionStalenessDays: 1,
            updatePriority: 2,
          ),
        );
        addTearDown(availableClient.dispose);
        final availableService = UpdateService(client: availableClient);
        addTearDown(availableService.dispose);

        expect(
          await availableService.checkForUpdateManually(),
          ManualUpdateCheckResult.updateStarted,
        );
        expect(availableClient.checkForUpdateCallCount, 1);
        expect(availableClient.startFlexibleUpdateCallCount, 1);
        expect(availableService.isUpdateDownloaded, isTrue);

        // Calling again when already downloaded prompts installation immediately
        expect(
          await availableService.checkForUpdateManually(),
          ManualUpdateCheckResult.updateAlreadyDownloaded,
        );
        expect(availableClient.startFlexibleUpdateCallCount, 1);

        // C. Offline / Play Store error -> unavailable
        final errorClient = FakeInAppUpdateClient(shouldThrowOnCheck: true);
        addTearDown(errorClient.dispose);
        final errorService = UpdateService(client: errorClient);
        addTearDown(errorService.dispose);

        expect(
          await errorService.checkForUpdateManually(),
          ManualUpdateCheckResult.unavailable,
        );
        expect(errorService.isChecking, isFalse);

        // D. Non-Android platform -> unavailable without querying Play Store
        final iosService = UpdateService(
          client: upToDateClient,
          isAndroidOverride: false,
        );
        addTearDown(iosService.dispose);
        expect(
          await iosService.checkForUpdateManually(),
          ManualUpdateCheckResult.unavailable,
        );
        expect(upToDateClient.checkForUpdateCallCount, 1);
      },
    );

    testWidgets(
      '7. Tapping version button in SettingsDialog shows loading indicator while checking, triggers flexible update when available, and prompts installation when downloaded',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final fakeClient = FakeInAppUpdateClient();
        addTearDown(fakeClient.dispose);

        final updateService = UpdateService(client: fakeClient);
        addTearDown(updateService.dispose);

        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
          updateService: updateService,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Open SettingsDialog
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        final versionBtn = find.byKey(
          const ValueKey('settings_version_check_button'),
        );
        expect(versionBtn, findsOneWidget);
        expect(
          find.byKey(const ValueKey('settings_version_update_icon')),
          findsOneWidget,
        );

        // Prepare a pending check to verify compact loading indicator & disabled state
        final checkCompleter = Completer<AppUpdateInfo>();
        fakeClient.checkForUpdateCompleter = checkCompleter;
        fakeClient.checkForUpdateCallCount = 0;

        await tester.tap(versionBtn);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('settings_version_loading_indicator')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('settings_version_update_icon')),
          findsNothing,
        );
        // Tapping again while checking is ignored (disabled)
        await tester.tap(versionBtn);
        await tester.pump();
        expect(fakeClient.checkForUpdateCallCount, 1);

        // Complete with an available flexible update
        checkCompleter.complete(
          AppUpdateInfo(
            updateAvailability: UpdateAvailability.updateAvailable,
            immediateUpdateAllowed: false,
            immediateAllowedPreconditions: const [],
            flexibleUpdateAllowed: true,
            flexibleAllowedPreconditions: const [],
            availableVersionCode: 105,
            installStatus: InstallStatus.pending,
            packageName: 'com.howpredictable.app',
            clientVersionStalenessDays: 1,
            updatePriority: 2,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(fakeClient.startFlexibleUpdateCallCount, 1);
        expect(
          find.byKey(const ValueKey('update_install_dialog')),
          findsOneWidget,
        );
        expect(find.text(UpdateService.updateReadyMessage), findsOneWidget);
        expect(find.text(UpdateService.restartActionLabel), findsOneWidget);

        // Dismiss prompt with Later, then tap version button again -> prompts immediately
        await tester.tap(
          find.byKey(const ValueKey('update_install_later_button')),
        );
        await tester.pumpAndSettle();

        fakeClient.checkForUpdateCompleter = null;
        await tester.tap(versionBtn);
        await tester.pumpAndSettle();

        expect(fakeClient.startFlexibleUpdateCallCount, 1);
        expect(
          find.byKey(const ValueKey('update_install_dialog')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('update_install_restart_button')),
        );
        await tester.pumpAndSettle();

        expect(fakeClient.completeFlexibleUpdateCallCount, 1);
      },
    );

    testWidgets(
      '8. Tapping version button in SettingsDialog when up to date shows localized SnackBar in English and Portuguese',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await localization.load();

        final fakeClient = FakeInAppUpdateClient();
        addTearDown(fakeClient.dispose);

        final updateService = UpdateService(client: fakeClient);
        addTearDown(updateService.dispose);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          updateService: updateService,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        final versionBtn = find.byKey(
          const ValueKey('settings_version_check_button'),
        );

        // English check
        await tester.tap(versionBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('update_up_to_date_snackbar')),
          findsOneWidget,
        );
        expect(find.text("You're on the latest version!"), findsOneWidget);

        // Switch to Portuguese and re-check
        controller.setLanguage('pt');
        await tester.pumpAndSettle();

        await tester.tap(versionBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('update_up_to_date_snackbar')),
          findsOneWidget,
        );
        expect(
          find.text('Você já está na versão mais recente!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '9. Tapping version button in SettingsDialog fails gracefully when offline or sideloaded and shows localized error SnackBar',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
        });
        final storage = StorageService();
        await storage.init();

        final localization = LocalizationService();
        await localization.load();

        final fakeClient = FakeInAppUpdateClient(shouldThrowOnCheck: true);
        addTearDown(fakeClient.dispose);

        final updateService = UpdateService(client: fakeClient);
        addTearDown(updateService.dispose);

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
          updateService: updateService,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        final versionBtn = find.byKey(
          const ValueKey('settings_version_check_button'),
        );

        // English offline/sideloaded error fallback
        await tester.tap(versionBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('update_unavailable_snackbar')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Could not check for updates. Make sure you installed via Google Play and are online.',
          ),
          findsOneWidget,
        );
        expect(updateService.isChecking, isFalse);

        // Portuguese offline/sideloaded error fallback
        controller.setLanguage('pt');
        await tester.pumpAndSettle();

        await tester.tap(versionBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.text(
            'Não foi possível verificar atualizações. Certifique-se de ter instalado pela Google Play e estar online.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
