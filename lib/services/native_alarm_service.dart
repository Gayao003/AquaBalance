import 'dart:convert';
import 'package:flutter/services.dart';

class NativeAlarmService {
  static const platform = MethodChannel('com.watertracking.aquabalance/alarm');

  static void configureActionHandler(
    Future<void> Function(String actionId, Map<String, dynamic> payload)
    onAction,
  ) {
    platform.setMethodCallHandler((call) async {
      if (call.method != 'nativeNotificationAction') return;
      final args = Map<String, dynamic>.from(call.arguments ?? {});
      final actionId = args['actionId'] as String? ?? '';
      final payloadJson = args['payload'] as String? ?? '';

      Map<String, dynamic> payload = {};
      if (payloadJson.isNotEmpty) {
        try {
          payload = Map<String, dynamic>.from(jsonDecode(payloadJson));
        } catch (_) {
          payload = {};
        }
      }

      await onAction(actionId, payload);
    });
  }

  // Schedule a native Android alarm that fires after N seconds (test)
  static Future<bool> scheduleNativeAlarm(int seconds) async {
    try {
      final bool result = await platform.invokeMethod('scheduleAlarm', {
        'seconds': seconds,
      });
      return result;
    } catch (_) {
      return false;
    }
  }

  // Test alarm - fires in 5 seconds
  static Future<bool> testAlarmNow() async {
    return scheduleNativeAlarm(5);
  }

  // Schedule a repeating daily alarm at specific time
  static Future<bool> scheduleDailyWaterAlarm({
    required int alarmId,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final bool result = await platform.invokeMethod('scheduleDailyAlarm', {
        'alarmId': alarmId,
        'hour': hour,
        'minute': minute,
        'title': title,
        'body': body,
        'payload': payload,
      });
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> cancelAlarm(int alarmId) async {
    try {
      final bool result = await platform.invokeMethod('cancelAlarm', {
        'alarmId': alarmId,
      });
      return result;
    } catch (_) {
      return false;
    }
  }
}
