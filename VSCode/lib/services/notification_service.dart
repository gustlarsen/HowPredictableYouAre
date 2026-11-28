import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Abstraction over [FlutterLocalNotificationsPlugin] so [NotificationService]
/// uses the official local notification SDK on mobile while remaining cleanly
/// testable and offline-safe in unit and widget tests.
abstract class LocalNotificationsClient {
  Future<bool> initialize({
    void Function(String? payload)? onNotificationTapped,
  });

  Future<bool> requestNotificationsPermission();

  Future<bool> canScheduleExactAlarms();

  Future<void> scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAtUtc,
    required bool useExactAlarm,
    String? payload,
  });

  Future<void> cancel(int id);
}

/// Default production implementation of [LocalNotificationsClient] backed by
/// `flutter_local_notifications` and `timezone`.
class DefaultLocalNotificationsClient implements LocalNotificationsClient {
  static const String offertoryChannelId = 'offertory_full_channel';
  static const String offertoryChannelName = 'Sacred Offertory';
  static const String offertoryChannelDescription =
      'Alerts when the Sacred Temple Offertory reaches 100% capacity.';

  static bool _timeZonesInitialized = false;
  static bool _handledInitialLaunchNotification = false;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _wasLastPermissionDenied = false;

  DefaultLocalNotificationsClient({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// True only when the mobile OS explicitly returned `false` from a runtime
  /// notification permission prompt (never set on desktop or headless test
  /// `MissingPluginException` fallbacks).
  bool get wasLastPermissionDenied => _wasLastPermissionDenied;

  static void _ensureTimeZonesInitialized() {
    if (_timeZonesInitialized) return;
    tz_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> initialize({
    void Function(String? payload)? onNotificationTapped,
  }) async {
    if (!_isMobilePlatform) return false;
    try {
      _ensureTimeZonesInitialized();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );
      final initialized = await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          onNotificationTapped?.call(response.payload);
        },
      );

      if (!_handledInitialLaunchNotification && onNotificationTapped != null) {
        try {
          final launchDetails = await _plugin.getNotificationAppLaunchDetails();
          if (launchDetails != null &&
              launchDetails.didNotificationLaunchApp) {
            _handledInitialLaunchNotification = true;
            onNotificationTapped(
              launchDetails.notificationResponse?.payload,
            );
          }
        } catch (_) {
          // Ignore if launch details are unsupported in the current environment.
        }
      }

      return initialized ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    _wasLastPermissionDenied = false;
    if (!_isMobilePlatform) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin == null) return false;
        final granted = await androidPlugin.requestNotificationsPermission();
        _wasLastPermissionDenied = granted == false;
        return granted ?? true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosPlugin == null) return false;
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _wasLastPermissionDenied = granted == false;
        return granted ?? false;
      }
      return false;
    } on MissingPluginException {
      _wasLastPermissionDenied = false;
      return false;
    } catch (_) {
      _wasLastPermissionDenied = false;
      return false;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin == null) return false;
      return await androidPlugin.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAtUtc,
    required bool useExactAlarm,
    String? payload,
  }) async {
    if (!_isMobilePlatform) return;
    _ensureTimeZonesInitialized();
    final requestedTz = tz.TZDateTime.from(scheduledAtUtc.toUtc(), tz.UTC);
    final minFutureTz = tz.TZDateTime.now(tz.UTC).add(
      const Duration(seconds: 1),
    );
    final scheduledTz = requestedTz.isAfter(minFutureTz)
        ? requestedTz
        : minFutureTz;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        offertoryChannelId,
        offertoryChannelName,
        channelDescription: offertoryChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final primaryMode = useExactAlarm
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: details,
        androidScheduleMode: primaryMode,
        payload: payload,
      );
    } catch (_) {
      // Safe fallback for Android 12-16 devices where exact alarms are denied
      // or restricted at runtime.
      if (useExactAlarm) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledTz,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
        } catch (_) {
          // Never crash gameplay if notifications are unavailable on device.
        }
      }
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!_isMobilePlatform) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Ignore missing plugin or unsupported runner errors.
    }
  }
}

/// Manages OS-scheduled local push notifications (`zonedSchedule`) for the
/// Sacred Temple's Offertory (Gazofilácio) 100%-capacity alert.
class NotificationService {
  /// Fixed notification ID for the Offertory 100%-capacity alert so rescheduling
  /// always replaces any previous pending alert cleanly.
  static const int offertoryFullNotificationId = 1001;

  /// Minimum remaining seconds required before scheduling (`> 0s` schedules;
  /// `0s` / already full cancels without scheduling a past-due alert).
  static const int minScheduleLeadSeconds = 0;

  static const String offertoryFullPayload = 'offertory_full';

  final LocalNotificationsClient _client;
  void Function(String? payload)? onNotificationTapped;
  bool _isInitialized = false;
  bool _wasLastPermissionDenied = false;
  int _operationGeneration = 0;
  Future<void> _operationQueue = Future<void>.value();

  NotificationService({
    LocalNotificationsClient? client,
    this.onNotificationTapped,
  }) : _client = client ?? DefaultLocalNotificationsClient();

  bool get isInitialized => _isInitialized;

  /// True when the most recent [requestPermission] call was explicitly denied
  /// by the user/OS.
  bool get wasLastPermissionDenied => _wasLastPermissionDenied;

  Future<void> _enqueueOperation(Future<void> Function() action) {
    final next = _operationQueue.then((_) => action());
    _operationQueue = next.catchError((_) {});
    return next;
  }

  /// Initializes the underlying local notifications plugin safely without
  /// blocking offline gameplay.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _isInitialized = await _client.initialize(
        onNotificationTapped: (payload) => onNotificationTapped?.call(payload),
      );
    } catch (_) {
      _isInitialized = false;
    }
  }

  /// Requests OS notification permission contextually (Android 13+
  /// `POST_NOTIFICATIONS` / iOS alert permission).
  Future<bool> requestPermission() async {
    await initialize();
    try {
      final granted = await _client.requestNotificationsPermission();
      if (_client is DefaultLocalNotificationsClient) {
        _wasLastPermissionDenied = _client.wasLastPermissionDenied;
      } else {
        _wasLastPermissionDenied = !granted;
      }
      return granted;
    } catch (_) {
      _wasLastPermissionDenied = false;
      return false;
    }
  }

  /// Cancels any previous Offertory-full notification and schedules a new one
  /// for `now + remainingUntilFull` when `remainingUntilFull.inSeconds > 0`.
  Future<void> scheduleOffertoryFullNotification({
    required Duration remainingUntilFull,
    required String title,
    required String body,
    DateTime? now,
  }) {
    final gen = ++_operationGeneration;
    return _enqueueOperation(() async {
      if (gen != _operationGeneration) return;
      try {
        await _client.cancel(offertoryFullNotificationId);
      } catch (_) {
        // Fail gracefully without interrupting gameplay.
      }
      if (gen != _operationGeneration) return;
      if (remainingUntilFull.inSeconds <= minScheduleLeadSeconds) {
        return;
      }
      await initialize();
      if (gen != _operationGeneration) return;
      try {
        final canExact = await _client.canScheduleExactAlarms();
        if (gen != _operationGeneration) return;
        final scheduledAtUtc =
            (now ?? DateTime.now()).toUtc().add(remainingUntilFull);
        await _client.scheduleZonedNotification(
          id: offertoryFullNotificationId,
          title: title,
          body: body,
          scheduledAtUtc: scheduledAtUtc,
          useExactAlarm: canExact,
          payload: offertoryFullPayload,
        );
      } catch (_) {
        // Fail gracefully without interrupting gameplay.
      }
    });
  }

  /// Cancels any pending or active Offertory-full notification (`1001`).
  Future<void> cancelOffertoryFullNotification() {
    final gen = ++_operationGeneration;
    return _enqueueOperation(() async {
      if (gen != _operationGeneration) return;
      try {
        await _client.cancel(offertoryFullNotificationId);
      } catch (_) {
        // Fail gracefully without interrupting gameplay.
      }
    });
  }
}
