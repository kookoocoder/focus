import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/store.dart';

const pwKey = 'pwCourse';

class PwSubject {
  final String id;
  final String name;
  int total;
  int completed;
  PwSubject(this.id, this.name, this.total, this.completed);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'total': total,
    'completed': completed,
  };
  factory PwSubject.fromJson(Map<String, dynamic> j) =>
      PwSubject(j['id'], j['name'], j['total'] ?? 0, j['completed'] ?? 0);
}

class PwLecture {
  final String subject;
  final String topic;
  final DateTime start;
  final DateTime end;
  PwLecture(this.subject, this.topic, this.start, this.end);

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'topic': topic,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };
  factory PwLecture.fromJson(Map<String, dynamic> j) => PwLecture(
    j['subject'],
    j['topic'],
    DateTime.parse(j['start']),
    DateTime.parse(j['end']),
  );
}

/// Course data read from PW's own API responses (captured in the PW WebView).
class PwCourse {
  String batchName;
  List<PwSubject> subjects;
  List<PwLecture> schedule;
  String? updated;

  PwCourse({
    this.batchName = '',
    List<PwSubject>? subjects,
    List<PwLecture>? schedule,
    this.updated,
  }) : subjects = subjects ?? [],
       schedule = schedule ?? [];

  static PwCourse load() {
    final j = Store.read<Map<String, dynamic>>(pwKey);
    if (j == null) return PwCourse();
    return PwCourse(
      batchName: j['batchName'] ?? '',
      subjects: [for (final s in j['subjects'] ?? []) PwSubject.fromJson(s)],
      schedule: [for (final s in j['schedule'] ?? []) PwLecture.fromJson(s)],
      updated: j['updated'],
    );
  }

  Future<void> save() => Store.write(pwKey, {
    'batchName': batchName,
    'subjects': subjects.map((e) => e.toJson()).toList(),
    'schedule': schedule.map((e) => e.toJson()).toList(),
    'updated': DateTime.now().toIso8601String(),
  });

  /// Subjects that are real GATE subjects (skips "Notices", "Starter Kit").
  List<PwSubject> get studySubjects => subjects
      .where(
        (s) => !const ['notices', 'starter kit'].contains(s.name.toLowerCase()),
      )
      .toList();

  /// Feed one captured response. Returns true if anything changed.
  bool ingest(String url, String body) {
    final path = Uri.tryParse(url)?.path ?? url;
    Map<String, dynamic> j;
    try {
      j = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    final data = j['data'];
    if (path.endsWith('/details') &&
        path.contains('/v3/batches/') &&
        data is Map) {
      batchName = '${data['name'] ?? data['batchName'] ?? batchName}'.trim();
      final old = {for (final s in subjects) s.id: s};
      subjects = [
        for (final s in (data['subjects'] as List? ?? []))
          PwSubject(
            s['_id'],
            '${s['subject']}'.trim(),
            old[s['_id']]?.total ?? (s['lectureCount'] ?? 0),
            old[s['_id']]?.completed ?? 0,
          ),
      ];
      return true;
    }
    if (path.endsWith('/subject/progress') && data is List) {
      final byId = {for (final s in subjects) s.id: s};
      for (final p in data) {
        final s = byId[p['subjectId']];
        if (s == null) continue;
        s.total = (p['totalLectures'] as num?)?.toInt() ?? s.total;
        s.completed = (p['completedLectures'] as num?)?.toInt() ?? s.completed;
      }
      return true;
    }
    if (path.endsWith('/todays-schedule') && data is List) {
      schedule = [
        for (final e in data)
          if (e['type'] == 'LECTURE' && e['data'] is Map)
            PwLecture(
              '${e['data']['subjectId']?['name'] ?? ''}',
              '${e['data']['topic'] ?? ''}',
              DateTime.parse(e['data']['startTime']).toLocal(),
              DateTime.parse(e['data']['endTime']).toLocal(),
            ),
      ];
      return true;
    }
    return false;
  }
}

/// Re-reads everything captured so far (used once after an update).
Future<PwCourse> rebuildFromCapture() async {
  final course = PwCourse.load();
  final f = File(
    '${(await getApplicationDocumentsDirectory()).path}/pw_capture.jsonl',
  );
  if (!await f.exists()) return course;
  var changed = false;
  for (final line in await f.readAsLines()) {
    try {
      final m = jsonDecode(line) as Map<String, dynamic>;
      if (m['url'] != null) changed |= course.ingest(m['url'], m['body'] ?? '');
    } catch (_) {}
  }
  if (changed) await course.save();
  return course;
}
