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
  });
}
