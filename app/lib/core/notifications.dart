import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Notifier {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    await _p.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  static Future<void> requestPermission() async {
    await init();
    await _p
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static NotificationDetails _details(String channel, String name, String body) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          name,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static Future<void> show(int id, String title, String body,
      {String channel = 'attendance', String channelName = 'Attendance'}) async {
    await init();
    await _p.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(channel, channelName, body),
    );
  }

  /// Repeats every day at [hour]:[minute] (IST).
  static Future<void> daily(int id, int hour, int minute, String title,
      String body, {String channel = 'gym', String channelName = 'Gym'}) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _p.zonedSchedule(
      id: id,
      scheduledDate: at,
      title: title,
      body: body,
      notificationDetails: _details(channel, channelName, body),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) async {
    await init();
    await _p.cancel(id: id);
  }
}
