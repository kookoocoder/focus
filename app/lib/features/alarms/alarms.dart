import 'package:alarm/alarm.dart';
import '../../core/store.dart';

const alarmsKey = 'alarms';

enum AlarmKind { wake, gym, study }

extension AlarmKindLabel on AlarmKind {
  String get label => switch (this) {
        AlarmKind.wake => 'Wake up',
        AlarmKind.gym => 'Gym',
        AlarmKind.study => 'GATE study',
      };
}

class AlarmItem {
  int id;
  AlarmKind kind;
  int hour;
  int minute;

  /// Weekdays it repeats on (1 = Mon … 7 = Sun). Empty = one-time.
  List<int> days;
  bool on;

  AlarmItem({
    required this.id,
    required this.kind,
    required this.hour,
    required this.minute,
    List<int>? days,
    this.on = true,
  }) : days = days ?? [1, 2, 3, 4, 5, 6, 7];

  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Next time this alarm should ring after [from].
  DateTime nextRing([DateTime? from]) {
    final now = from ?? DateTime.now();
    for (var d = 0; d < 8; d++) {
      final day = DateTime(now.year, now.month, now.day + d, hour, minute);
      if (!day.isAfter(now)) continue;
      if (days.isEmpty || days.contains(day.weekday)) return day;
    }
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'hour': hour,
        'minute': minute,
        'days': days,
        'on': on,
      };

  factory AlarmItem.fromJson(Map<String, dynamic> j) => AlarmItem(
        id: j['id'],
        kind: AlarmKind.values.byName(j['kind']),
        hour: j['hour'],
        minute: j['minute'],
        days: (j['days'] as List).cast<int>(),
        on: j['on'] ?? true,
      );
}

List<AlarmItem> loadAlarms() =>
    (Store.read<List>(alarmsKey) ?? []).map((e) => AlarmItem.fromJson(e)).toList();

Future<void> saveAlarms(List<AlarmItem> items) async {
  await Store.write(alarmsKey, items.map((e) => e.toJson()).toList());
  await scheduleAlarms(items);
}

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

/// (Re)schedules the next ring of every enabled alarm; one-time alarms that
/// already rang are switched off.
Future<void> scheduleAlarms([List<AlarmItem>? items]) async {
  items ??= loadAlarms();
  for (final a in items) {
    if (!a.on) {
      await Alarm.stop(a.id);
      continue;
    }
    await Alarm.set(alarmSettings: _settings(a.id, a.nextRing(), a.kind.label));
  }
}

Future<void> snooze(int id, String title) => Alarm.set(
    alarmSettings: _settings(
        id, DateTime.now().add(const Duration(minutes: 5)), '$title (snoozed)'));

/// Called after an alarm is dismissed so repeating alarms ring again.
Future<void> afterDismiss(int id) async {
  await Alarm.stop(id);
  final items = loadAlarms();
  for (final a in items) {
    if (a.id == id && a.days.isEmpty) a.on = false;
  }
  await saveAlarms(items);
}
