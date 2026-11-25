import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Abstraction over [FlutterLocalNotificationsPlugin] so [NotificationService]
/// uses the official local notification SDK on mobile while remaining cleanly
/// testable and offline-safe in unit and widget tests.
abstract class LocalNotificationsClient {
  Future<bool> initialize();

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
      'Alerts when the Sacred Temple Offertory reaches 100% capacity (8-hour cap).';

  static bool _timeZonesInitialized = false;

  final FlutterLocalNotificationsPlugin _plugin;

  DefaultLocalNotificationsClient({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

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
  Future<bool> initialize() async {
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
      final initialized = await _plugin.initialize(settings: initSettings);
      return initialized ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationsPermission() async {
    if (!_isMobilePlatform) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin == null) return false;
        return await androidPlugin.requestNotificationsPermission() ?? true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosPlugin == null) return false;
        return await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (_) {
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
    final scheduledTz = tz.TZDateTime.from(scheduledAtUtc.toUtc(), tz.UTC);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        offertoryChannelId,
        offertoryChannelName,
        channelDescription: offertoryChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
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
      // Safe fallback for Android 12-15+ devices where exact alarms are denied
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

/// Manages local push notifications for the Sacred Temple's Offertory
/// (Gazofilácio) 8-hour full-capacity alert.
class NotificationService {
  /// Fixed notification ID for the Offertory 100%-capacity alert so rescheduling
  /// always replaces any previous pending alert cleanly.
  static const int offertoryFullNotificationId = 1001;

  /// Minimum remaining seconds required before scheduling a future notification.
  static const int minScheduleLeadSeconds = 60;

  static const String offertoryFullPayload = 'offertory_full';

  final LocalNotificationsClient _client;
  bool _isInitialized = false;

  NotificationService({LocalNotificationsClient? client})
      : _client = client ?? DefaultLocalNotificationsClient();

  bool get isInitialized => _isInitialized;

  /// Initializes the underlying local notifications plugin safely without
  /// blocking offline gameplay.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _isInitialized = await _client.initialize();
    } catch (_) {
      _isInitialized = false;
    }
  }

  /// Requests OS notification permission contextually (Android 13+
  /// `POST_NOTIFICATIONS` / iOS alert permission).
  Future<bool> requestPermission() async {
    await initialize();
    try {
      return await _client.requestNotificationsPermission();
    } catch (_) {
      return false;
    }
  }

  /// Cancels any previous Offertory-full notification and schedules a new one
  /// for `now + remainingUntilFull` when `remainingUntilFull > 60s`.
  Future<void> scheduleOffertoryFullNotification({
    required Duration remainingUntilFull,
    required String title,
    required String body,
    DateTime? now,
  }) async {
    await cancelOffertoryFullNotification();
    if (remainingUntilFull.inSeconds <= minScheduleLeadSeconds) {
      return;
    }
    await initialize();
    try {
      final canExact = await _client.canScheduleExactAlarms();
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
  }

  /// Cancels any pending or active Offertory-full notification (`1001`).
  Future<void> cancelOffertoryFullNotification() async {
    try {
      await _client.cancel(offertoryFullNotificationId);
    } catch (_) {
      // Fail gracefully without interrupting gameplay.
    }
  }
}
