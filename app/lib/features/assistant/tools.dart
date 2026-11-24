import 'package:flutter/services.dart';

import '../../core/store.dart';
import '../alarms/alarms.dart';
import '../attendance/attendance.dart';
import '../attendance/attendance_sync.dart';

String _today() => DateTime.now().toIso8601String().substring(0, 10);

class AssistantTool {
  final String name;
  final String description;
  final Map<String, dynamic> properties;
  final List<String> required;
  final bool mutates;
  final Future<Object?> Function(Map<String, dynamic> args) run;
  const AssistantTool(
    this.name,
    this.description,
    this.run, {
    this.properties = const {},
    this.required = const [],
    this.mutates = false,
  });

  Map<String, dynamic> toSchema() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': properties,
        'required': required,
      },
    },
  };
}

const _str = {'type': 'string'};
const _num = {'type': 'number'};

List<Map<String, dynamic>> _list(String k) =>
    (Store.read<List>(k) ?? []).cast<Map<String, dynamic>>();

Activity? _find(List<Activity> l, String key) {
  final k = key.toLowerCase();
  for (final a in l) {
    if (a.key.toLowerCase() == k || a.label.toLowerCase().contains(k)) return a;
  }
  return null;
}

final assistantTools = <AssistantTool>[
  AssistantTool(
    'get_attendance',
    'Attendance for every subject: percent, safe skips, lectures needed.',
    (_) async => {
      'overall_percent': overallPercent(loadSubjects()),
      'subjects': [
        for (final s in loadSubjects())
          {
            ...s.toJson(),
            'percent': s.percent.round(),
            'safe_skips': s.safeSkips,
            'must_attend': s.mustAttend,
          },
      ],
      'last_sync': Store.read<String>(lastSyncKey),
    },
  ),
  AssistantTool(
    'edit_subject',
    'Add a subject or overwrite its counts. Note: the next ERP sync replaces '
        'subjects the ERP also lists, so tell the user that.',
    (a) async {
      final list = loadSubjects();
      final q = '${a['name']}'.toLowerCase();
      var s = list.where((e) => e.name.toLowerCase().contains(q)).firstOrNull;
      if (s == null) list.add(s = Subject(name: '${a['name']}'));
      if (a['attended'] is num) s.attended = (a['attended'] as num).toInt();
      if (a['total'] is num) s.total = (a['total'] as num).toInt();
      if (a['is_lab'] is bool) s.isLab = a['is_lab'];
      await Store.write(subjectsKey, list.map((e) => e.toJson()).toList());
      return {...s.toJson(), 'percent': s.percent.round()};
    },
    properties: {'name': _str, 'attended': _num, 'total': _num, 'is_lab': {'type': 'boolean'}},
    required: ['name'],
    mutates: true,
  ),
  AssistantTool(
    'mark_lecture',
    'Record one lecture for a subject: present=true adds to attended and total, false only to total.',
    (a) async {
      final list = loadSubjects();
      final q = '${a['name']}'.toLowerCase();
      final s = list.where((e) => e.name.toLowerCase().contains(q)).firstOrNull;
      if (s == null) return 'error: no subject "${a['name']}"; subjects: ${list.map((e) => e.name).join(', ')}';
      s.total++;
      if (a['present'] != false) s.attended++;
      await Store.write(subjectsKey, list.map((e) => e.toJson()).toList());
      return {...s.toJson(), 'percent': s.percent.round()};
    },
    properties: {'name': _str, 'present': {'type': 'boolean'}},
    required: ['name'],
    mutates: true,
  ),
  AssistantTool('sync_attendance', 'Re-fetch attendance from the ERP now.', (
    _,
  ) async {
    await syncAndNotify(force: true);
    return 'synced';
  }, mutates: true),
  AssistantTool(
    'get_diet_today',
    "Today's food log with protein/carb totals.",
    (_) async {
      final t = _list('diet').where((e) => e['date'] == _today()).toList();
      num sum(String f) =>
          t.fold<num>(0, (a, e) => a + (num.tryParse('${e[f]}') ?? 0));
      return {'items': t, 'protein': sum('protein'), 'carbs': sum('carbs')};
    },
  ),
  AssistantTool(
    'add_food',
    'Log a food eaten today. Estimate protein/carbs in grams if the user did not say.',
    (a) async {
      final log = _list('diet')
        ..insert(0, {
          'date': _today(),
          'food': a['food'],
          'protein': '${a['protein'] ?? 0}',
          'carbs': '${a['carbs'] ?? 0}',
        });
      await Store.write('diet', log);
      return 'added';
    },
    properties: {'food': _str, 'protein': _num, 'carbs': _num},
    required: ['food'],
    mutates: true,
  ),
  AssistantTool(
    'delete_food',
    "Delete today's food entries whose name contains the given text.",
    (a) async {
      final q = '${a['food']}'.toLowerCase();
      final log = _list('diet');
      final before = log.length;
      log.removeWhere(
        (e) =>
            e['date'] == _today() && '${e['food']}'.toLowerCase().contains(q),
      );
      await Store.write('diet', log);
      return 'removed ${before - log.length}';
    },
    properties: {'food': _str},
    required: ['food'],
    mutates: true,
  ),
  AssistantTool(
    'get_gym_log',
    'Recent gym sessions (most recent first).',
    (_) async => _list('gym').take(20).toList(),
  ),
  AssistantTool(
    'log_workout',
    'Record a finished gym session.',
    (a) async {
      final log = _list('gym')
        ..insert(0, {
          'date': _today(),
          'name': a['name'] ?? 'Workout session',
          'mins': (a['minutes'] as num?)?.toInt() ?? 0,
        });
      await Store.write('gym', log);
      return 'logged';
    },
    properties: {'name': _str, 'minutes': _num},
    mutates: true,
  ),
  AssistantTool(
    'list_reminders',
    'All daily reminders/alarms with key, time, days (1=Mon..7=Sun), enabled, alarm.',
    (_) async => [
      for (final a in loadActivities())
        {'key': a.key, 'label': a.label, 'time': a.time, ...a.toJson()},
    ],
  ),
  AssistantTool(
    'update_reminder',
    'Change a reminder: time as HH:MM 24h, days, enabled, alarm (true=ringing alarm, false=notification).',
    (a) async {
      final list = loadActivities();
      final act = _find(list, '${a['key']}');
      if (act == null) {
        return 'error: no reminder "${a['key']}"; keys: ${list.map((e) => e.key).join(', ')}';
      }
      if (a['time'] is String) {
        final p = (a['time'] as String).split(':');
        act.hour = int.parse(p[0]);
        act.minute = int.parse(p[1]);
      }
      if (a['days'] is List) {
        act.days = (a['days'] as List)
            .cast<num>()
            .map((e) => e.toInt())
            .toList();
      }
      if (a['enabled'] is bool) act.enabled = a['enabled'];
      if (a['alarm'] is bool) act.alarm = a['alarm'];
      await saveActivities(list);
      return {'key': act.key, 'time': act.time, ...act.toJson()};
    },
    properties: {
      'key': _str,
      'time': _str,
      'days': {'type': 'array', 'items': _num},
      'enabled': {'type': 'boolean'},
      'alarm': {'type': 'boolean'},
    },
    required: ['key'],
    mutates: true,
  ),
  AssistantTool(
    'list_data',
    'Every key stored on the device with its type and size. Known keys: '
        'subjects (attendance), activities (reminders), diet, gym, pwCourse/pwPages '
        '(GATE from PW), theme_mode, lastSync.',
    (_) async => {
      for (final k in Store.keys)
        k: switch (_raw(k)) {
          List l => 'list(${l.length})',
          Map m => 'map(${m.length})',
          final v => v.runtimeType.toString(),
        },
    },
  ),
  AssistantTool(
    'read_data',
    'Read the raw JSON value of a stored key. Lists can be sliced with offset/limit.',
    (a) async {
      final v = _raw('${a['key']}');
      if (v is! List) return v;
      final o = (a['offset'] as num?)?.toInt() ?? 0;
      final n = (a['limit'] as num?)?.toInt() ?? 50;
      return {'total': v.length, 'items': v.skip(o).take(n).toList()};
    },
    properties: {'key': _str, 'offset': _num, 'limit': _num},
    required: ['key'],
  ),
  AssistantTool(
    'write_data',
    'Overwrite a stored key with a JSON value (same shape as read_data), or '
        'delete it with delete=true. Use for anything the specific tools do not cover.',
    (a) async {
      final k = '${a['key']}';
      if (a['delete'] == true) {
        await Store.remove(k);
        return 'deleted $k';
      }
      await Store.write(k, a['value']);
      if (k == 'activities') await saveActivities(loadActivities());
      return 'saved $k';
    },
    properties: {
      'key': _str,
      'value': {'description': 'Any JSON value'},
      'delete': {'type': 'boolean'},
    },
    required: ['key'],
    mutates: true,
  ),
  AssistantTool(
    'get_scroll_control',
    'Scroll control status: service enabled, scroll limit, time limit (min), lock, usage stats.',
    (_) async => {
      'enabled': await _scroll.invokeMethod<bool>('isEnabled'),
      'scroll_limit': await _scroll.invokeMethod<int>('getLimit'),
      'time_limit_minutes': await _scroll.invokeMethod<int>('getTimeLimit'),
      'lock': await _scroll.invokeMethod<bool>('getLock'),
      'stats': await _scroll.invokeMethod<String>('stats'),
    },
  ),
  AssistantTool(
    'set_scroll_control',
    'Change scroll control: scroll_limit (scrolls), time_limit_minutes, lock (bool). '
        'open_settings=true opens the accessibility settings to enable the service.',
    (a) async {
      if (a['scroll_limit'] is num) {
        await _scroll.invokeMethod('setLimit', {'limit': (a['scroll_limit'] as num).toInt()});
      }
      if (a['time_limit_minutes'] is num) {
        await _scroll.invokeMethod('setTimeLimit', {
          'minutes': (a['time_limit_minutes'] as num).toInt(),
        });
      }
      if (a['lock'] is bool) await _scroll.invokeMethod('setLock', {'on': a['lock']});
      if (a['open_settings'] == true) await _scroll.invokeMethod('openSettings');
      return 'ok';
    },
    properties: {
      'scroll_limit': _num,
      'time_limit_minutes': _num,
      'lock': {'type': 'boolean'},
      'open_settings': {'type': 'boolean'},
    },
    mutates: true,
  ),
];

const _scroll = MethodChannel('focus/scroll');

Object? _raw(String k) {
  try {
    return Store.read<Object>(k);
  } catch (_) {
    return 'non-JSON value';
  }
}
