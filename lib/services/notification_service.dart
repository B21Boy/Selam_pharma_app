import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import '../screens/trash_screen.dart';
import '../screens/notification_screen.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final String localTz = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // fallback to UTC if timezone lookup fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
        final payload = details.payload;
        if (payload != null) {
          try {
            if (payload.startsWith('notif:')) {
              navigatorKey?.currentState?.push(
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            } else if (payload.startsWith('trash:')) {
              navigatorKey?.currentState?.push(
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              );
            }
          } catch (_) {}
        }
      },
    );
    _initialized = true;
  }

  int _idFor(String id, int offset) {
    // stable, non-negative id per notification type per medicine
    final h = id.hashCode;
    return (h.abs() % 1000000) + (offset * 1000000);
  }

  Future<void> showImmediate({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await initialize();
    final android = AndroidNotificationDetails(
      'shmed_chan',
      'App notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    final ios = DarwinNotificationDetails();
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
      payload: null,
    );
  }

  Future<void> schedule({
    required String notifId,
    required int offset,
    required String title,
    required String body,
    required DateTime at,
    String? payload,
  }) async {
    await initialize();
    final ident = _idFor(notifId, offset);
    final android = AndroidNotificationDetails(
      'shmed_chan',
      'App notifications',
      importance: Importance.defaultImportance,
    );
    final ios = DarwinNotificationDetails();
    await _plugin.zonedSchedule(
      ident,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(android: android, iOS: ios),
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  Future<void> cancelFor(String notifId) async {
    await initialize();
    // cancel three offsets (2-day,1-day,final)
    for (var offset = 0; offset < 3; offset++) {
      final id = _idFor(notifId, offset);
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }
}
