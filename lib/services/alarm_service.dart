import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/hydration_models.dart';
import '../services/checkin_service.dart';
import '../services/native_alarm_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;
  final _checkInService = CheckInService();
  final bool _preferNativeAndroid = true;

  static const String actionDrink = 'action_drink';
  static const String actionSkip = 'action_skip';

  factory AlarmService() {
    return _instance;
  }

  AlarmService._internal() {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(timezoneInfo.identifier);
      tz.setLocalLocation(location);
      debugPrint('Local timezone set to ${timezoneInfo.identifier}');
    } catch (e) {
      debugPrint('Failed to set local timezone: $e');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    NativeAlarmService.configureActionHandler(_handleNativeAction);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'water_reminder_channel',
          'Water Reminders',
          description: 'Daily hydration reminder notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      final enabled = await androidPlugin.areNotificationsEnabled();
      if (enabled != true) {
        await androidPlugin.requestNotificationsPermission();
      }

      try {
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Exact alarm permission request failed: $e');
      }
    }

    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.payload == null || response.payload!.isEmpty) return;

    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    await _handleAction(response.actionId, data);
  }

  Future<void> _handleNativeAction(
    String actionId,
    Map<String, dynamic> payload,
  ) async {
    if (payload.isEmpty) return;
    await _handleAction(actionId, payload);
  }

  Future<void> _handleAction(
    String? actionId,
    Map<String, dynamic> data,
  ) async {
    final userId = data['userId'] as String? ?? '';
    final scheduleId = data['scheduleId'] as int?;
    final amountMl = (data['amountMl'] as num?)?.toDouble() ?? 250;
    final beverageType = data['beverageType'] as String? ?? 'Water';

    if (userId.isEmpty) return;

    if (actionId == actionSkip) {
      final checkIn = HydrationCheckIn(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        scheduleId: scheduleId,
        beverageType: 'Skipped',
        amountMl: 0,
        timestamp: DateTime.now(),
      );
      await _checkInService.addCheckIn(userId, checkIn);
      return;
    }

    final isDefaultTap = actionId == null || actionId.isEmpty;
    if (actionId != actionDrink && !isDefaultTap) return;

    final checkIn = HydrationCheckIn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      scheduleId: scheduleId,
      beverageType: beverageType,
      amountMl: amountMl,
      timestamp: DateTime.now(),
    );

    await _checkInService.addCheckIn(userId, checkIn);
  }

  Future<void> scheduleWaterReminder({
    required int id,
    required int hour,
    required int minute,
    required String? timezoneIdentifier,
    DateTime? startDate,
    String title = 'Time to Hydrate! 💧',
    String body = 'Remember to log your water intake and stay hydrated!',
    Map<String, dynamic>? payloadData,
  }) async {
    if (!_initialized) {
      debugPrint('Initializing AlarmService...');
      await initialize();
      debugPrint('AlarmService initialized: $_initialized');
    }

    final location = _resolveLocation(timezoneIdentifier);
    final tz.TZDateTime scheduledTime = _nextInstanceOfTimeOnOrAfter(
      hour,
      minute,
      startDate,
      location,
    );

    debugPrint('Scheduling reminder:');
    debugPrint('  ID: $id (notification ID: ${_getNotificationId(id)})');
    debugPrint(
      '  Time: ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}',
    );
    debugPrint('  Title: $title');

    var scheduledWithFlutter = false;
    if (!(Platform.isAndroid && _preferNativeAndroid)) {
      try {
        await _notificationsPlugin.zonedSchedule(
          _getNotificationId(id),
          title,
          body,
          scheduledTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'water_reminder_channel',
              'Water Reminders',
              channelDescription: 'Daily hydration reminder notifications',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
              category: AndroidNotificationCategory.reminder,
              // Keep notification visible until user acts
              autoCancel: false,
              actions: [
                const AndroidNotificationAction(
                  actionDrink,
                  'I Drank Water',
                  showsUserInterface: false,
                ),
                const AndroidNotificationAction(
                  actionSkip,
                  'Skip',
                  showsUserInterface: false,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
              presentBadge: true,
              sound: 'default',
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          payload: payloadData == null ? null : jsonEncode(payloadData),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        scheduledWithFlutter = true;
        debugPrint('✅ Reminder scheduled successfully!');
      } catch (e) {
        debugPrint('❌ Error scheduling reminder: $e');
        debugPrint('Stack trace: ${StackTrace.current}');
      }
    }

    if (Platform.isAndroid && (!scheduledWithFlutter || _preferNativeAndroid)) {
      try {
        final alarmId = _getNotificationId(id);
        final ok = await NativeAlarmService.scheduleDailyWaterAlarm(
          alarmId: alarmId,
          hour: hour,
          minute: minute,
          title: title,
          body: body,
          payload: payloadData == null ? null : jsonEncode(payloadData),
        );
        if (ok) {
          debugPrint('✅ Native alarm scheduled for ID $alarmId');
        } else {
          debugPrint('❌ Native alarm scheduling failed for ID $alarmId');
        }
      } catch (e) {
        debugPrint('❌ Native alarm error: $e');
      }
    }
  }

  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(_getNotificationId(id));
    if (Platform.isAndroid) {
      await NativeAlarmService.cancelAlarm(_getNotificationId(id));
    }
  }

  /// Converts a schedule ID to a valid 32-bit notification ID.
  /// Schedule IDs from millisecondsSinceEpoch are too large for Android.
  int _getNotificationId(int scheduleId) {
    // Use absolute value of hash to ensure positive 32-bit integer
    return (scheduleId.hashCode).abs() % (0x7FFFFFFF); // Max 32-bit signed int
  }

  /// Shows a test notification immediately to verify notification permissions
  /// and functionality. Useful for debugging.
  Future<void> showTestNotification({String? userId}) async {
    try {
      if (!_initialized) await initialize();

      debugPrint('Showing test notification...');
      const androidDetails = AndroidNotificationDetails(
        'water_reminder_channel',
        'Water Reminders',
        channelDescription: 'Daily hydration reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        autoCancel: false,
        actions: [
          AndroidNotificationAction(
            actionDrink,
            'I Drank Water',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            actionSkip,
            'Skip',
            showsUserInterface: false,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = userId != null
          ? jsonEncode({
              'userId': userId,
              'scheduleId': 99999,
              'amountMl': 250,
              'beverageType': 'Water',
            })
          : null;

      var shownWithFlutter = false;
      try {
        await _notificationsPlugin.show(
          99999, // Test notification ID
          'Test Notification 💧',
          'If you see this with action buttons, notifications are working!',
          details,
          payload: payload,
        );
        shownWithFlutter = true;
        debugPrint('✅ Test notification shown!');
      } catch (e) {
        debugPrint('❌ Error showing test notification: $e');
      }

      if (Platform.isAndroid && !shownWithFlutter) {
        final nativeOk = await NativeAlarmService.testAlarmNow();
        if (nativeOk) {
          debugPrint('✅ Native test alarm scheduled (fires in ~5s)');
        } else {
          debugPrint('❌ Native test alarm failed');
        }
      }
    } catch (e) {
      debugPrint('❌ Error showing test notification: $e');
      debugPrint('Note: Check if notifications are enabled in device settings');
    }
  }

  tz.TZDateTime _nextInstanceOfTimeOnOrAfter(
    int hour,
    int minute,
    DateTime? startDate,
    tz.Location location,
  ) {
    final tz.TZDateTime now = tz.TZDateTime.now(location);
    final baseDate = startDate ?? DateTime(now.year, now.month, now.day);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      location,
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  tz.Location _resolveLocation(String? timezoneIdentifier) {
    if (timezoneIdentifier == null || timezoneIdentifier.isEmpty) {
      return tz.local;
    }

    if (timezoneIdentifier.toLowerCase() == 'local') {
      return tz.local;
    }

    try {
      final location = tz.getLocation(timezoneIdentifier);
      tz.setLocalLocation(location);
      return location;
    } catch (e) {
      debugPrint('Invalid timezone "$timezoneIdentifier", using local.');
      return tz.local;
    }
  }

  List<String> getDefaultReminderTimes() {
    return ['08:00', '11:00', '14:00', '17:00', '20:00'];
  }
}
