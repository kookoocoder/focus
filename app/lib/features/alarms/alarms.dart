import 'package:alarm/alarm.dart';

import '../../core/notifications.dart';
import '../../core/store.dart';

const _activitiesKey = 'activities';

/// A daily activity (gym, PW lecture, ...) that reminds you at a set time,
/// either as a full ringing alarm or as a normal notification.
class Activity {
  final String key;
  final String label;
  int hour;
  int minute;

  /// Weekdays it repeats on (1 = Mon … 7 = Sun).
  List<int> days;
  bool enabled;
  bool alarm;

  Activity(
    this.key,
    this.label,
    this.hour,
    this.minute, {
    List<int>? days,
    this.enabled = false,
    this.alarm = true,
  }) : days = days ?? [1, 2, 3, 4, 5, 6, 7];

  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DateTime nextRing([DateTime? from]) {
    final now = from ?? DateTime.now();
    for (var d = 0; d < 8; d++) {
      final t = DateTime(now.year, now.month, now.day + d, hour, minute);
      if (t.isAfter(now) && days.contains(t.weekday)) return t;
    }
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  Map<String, dynamic> toJson() => {
    'hour': hour,
    'minute': minute,
    'days': days,
    'enabled': enabled,
    'alarm': alarm,
  };

  void apply(Map<String, dynamic> j) {
    hour = j['hour'];
    minute = j['minute'];
    days = (j['days'] as List).cast<int>();
    enabled = j['enabled'];
    alarm = j['alarm'];
  }
}

List<Activity> _defaults() => [
  Activity('wake', 'Wake up', 6, 0),
  Activity('gymMorning', 'Gym (morning)', 7, 0, enabled: true),
  Activity('gymEvening', 'Gym (evening)', 18, 0),
  Activity('pwLecture', 'PW lecture', 20, 0, enabled: true),
  Activity('diet', 'Log your diet', 21, 30, enabled: true, alarm: false),
];

List<Activity> loadActivities() {
  final saved = Store.read<Map<String, dynamic>>(_activitiesKey) ?? {};
  final list = _defaults();
  for (final a in list) {
    if (saved[a.key] != null) a.apply(saved[a.key]);
  }
  return list;
}

Future<void> saveActivities(List<Activity> list) async {
  await Store.write(_activitiesKey, {for (final a in list) a.key: a.toJson()});
  await scheduleActivities(list);
}

int _alarmId(int i) => 100 + i;
int _notifId(int i, int day) => 200 + i * 10 + day;

AlarmSettings _settings(int id, DateTime at, String title) => AlarmSettings(
  id: id,
  dateTime: at,
  vibrate: true,
  loopAudio: true,
  androidFullScreenIntent: true,
  warningNotificationOnKill: false,
  volumeSettings: VolumeSettings.fade(
    volume: 1.0,
    fadeDuration: const Duration(seconds: 10),
    volumeEnforced: true,
  ),
  notificationSettings: NotificationSettings(
    title: title,
    body: 'Tap to open Focus',
    stopButton: 'Stop',
  ),
);

/// Puts every activity's next reminder in place, as an alarm or a notification.
Future<void> scheduleActivities([List<Activity>? list]) async {
  list ??= loadActivities();
  await Notifier.cancel(101); // legacy gym reminders
  await Notifier.cancel(102);
  for (final old in await Alarm.getAlarms()) {
    if (old.id < 100 || old.id >= 100 + list.length) {
      if (old.id != _testId) await Alarm.stop(old.id);
    }
  }
  for (var i = 0; i < list.length; i++) {
    final a = list[i];
    for (var d = 1; d <= 7; d++) {
      await Notifier.cancel(_notifId(i, d));
    }
    if (!a.enabled || !a.alarm) await Alarm.stop(_alarmId(i));
    if (!a.enabled) continue;
    if (a.alarm) {
      await Alarm.set(
        alarmSettings: _settings(_alarmId(i), a.nextRing(), a.label),
      );
    } else {
      for (final d in a.days) {
        await Notifier.weekly(
          _notifId(i, d),
          d,
          a.hour,
          a.minute,
          a.label,
          "It's time: ${a.label}",
        );
      }
    }
  }
}

const _testId = 9999;

Future<void> testAlarm() => Alarm.set(
  alarmSettings: _settings(
    _testId,
    DateTime.now().add(const Duration(seconds: 10)),
    'Test alarm',
  ),
);

Future<void> snooze(int id, String title) => Alarm.set(
  alarmSettings: _settings(
    id,
    DateTime.now().add(const Duration(minutes: 5)),
    '$title (snoozed)',
  ),
);

/// After an alarm is stopped, schedule its next ring.
Future<void> afterDismiss(int id) async {
  await Alarm.stop(id);
  if (id != _testId) await scheduleActivities();
}
