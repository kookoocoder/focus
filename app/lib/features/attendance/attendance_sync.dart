import '../../core/credentials.dart';
import '../../core/notifications.dart';
import '../../core/store.dart';
import 'attendance.dart';
import 'erp_client.dart';

const subjectsKey = 'subjects';
const _lastSummaryKey = 'lastSummary';
const lastSyncKey = 'lastSync';

List<Subject> loadSubjects() => (Store.read<List>(subjectsKey) ?? [])
    .map((e) => Subject.fromJson(e))
    .toList();

/// Subjects the ERP lists by mistake; not actually enrolled.
const _ignored = ['cloud infrastructure'];

bool _isIgnored(String name) =>
    _ignored.any((i) => name.toLowerCase().contains(i));

/// Theory subject rule: anything with "lab" in the name is a practical.
bool _isLab(String name) => name.toLowerCase().contains('lab');

/// Pull attendance from the ERP and persist it. No manual input involved.
Future<List<Subject>> syncFromErp() async {
  final (id, pw) = await Credentials.load();
  if (id == null || pw == null) {
    throw ErpException('ERP credentials missing from build');
  }
  final erp = ErpClient();
  try {
    await erp.login(id, pw);
    final fetched = await erp.fetchAttendance();
    final subjects = [
      for (final f in fetched)
        if (!_isIgnored(f.name))
          Subject(
            name: f.name,
            isLab: _isLab(f.name),
            attended: f.present,
            total: f.present + f.absent,
          ),
    ];
    await Store.write(subjectsKey, subjects.map((e) => e.toJson()).toList());
    await Store.write(lastSyncKey, DateTime.now().toIso8601String());
    return subjects;
  } finally {
    erp.close();
  }
}

String verdict(Subject s) {
  if (s.isLab) return 'lab, no minimum';
  if (s.percent >= 75) {
    return s.safeSkips == 0
        ? "don't skip next"
        : 'can skip next ${s.safeSkips}';
  }
  return 'attend, ${s.mustAttend} in a row to reach 75%';
}

String summary(List<Subject> subjects) {
  final theory = subjects.where((s) => !s.isLab).toList()
    ..sort((a, b) => a.percent.compareTo(b.percent));
  final lines = [
    for (final s in theory)
      '${s.percent >= 75 ? "✅" : "⛔"} ${s.name} ${s.percent.toStringAsFixed(0)}%: ${verdict(s)}',
  ];
  final o = overallPercent(subjects);
  lines.add(
    'Overall ${o.toStringAsFixed(1)}% ${o >= 50 ? "(ok)" : "(below 50%!)"}',
  );
  return lines.join('\n');
}

/// Background entry: sync, and notify only when the picture changed.
Future<void> syncAndNotify({bool force = false}) async {
  final subjects = await syncFromErp();
  final text = summary(subjects);
  final last = Store.read<String>(_lastSummaryKey);
  if (force || text != last) {
    final canSkip = subjects.where((s) => !s.isLab && s.safeSkips > 0).length;
    await Notifier.show(
      1,
      canSkip == 0
          ? 'Attendance: attend all theory lectures'
          : 'Attendance: $canSkip subject(s) can be skipped',
      text,
    );
    await Store.write(_lastSummaryKey, text);
  }
}
