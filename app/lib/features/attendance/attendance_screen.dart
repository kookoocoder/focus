import 'package:flutter/material.dart';
import '../../core/store.dart';
import 'attendance.dart';
import 'attendance_sync.dart';

/// Read-only view of ERP attendance. Syncs automatically when opened.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Subject> subjects = loadSubjects();
  String? error;
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    setState(() => syncing = true);
    try {
      subjects = await syncFromErp();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final overall = overallPercent(subjects);
    final last = Store.read<String>(lastSyncKey);
    final theory = subjects.where((s) => !s.isLab).toList()
      ..sort((a, b) => a.percent.compareTo(b.percent));
    final labs = subjects.where((s) => s.isLab).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        bottom: syncing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator())
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(title: const Text('ERP sync failed'), subtitle: Text(error!)),
            ),
          Card(
            child: ListTile(
              title: const Text('Overall (min 50%)'),
              subtitle: Text(last == null
                  ? 'Not synced yet'
                  : 'Synced ${last.substring(0, 16).replaceFirst('T', ' ')}'),
              trailing: Text('${overall.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: overall >= 50 ? Colors.green : Colors.red)),
            ),
          ),
          for (final s in theory) _tile(s),
          if (labs.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text('Labs & non-theory (no 75% rule)'),
            ),
          for (final s in labs) _tile(s),
        ]),
      ),
    );
  }

  Widget _tile(Subject s) {
    final ok = s.isLab || s.percent >= 75;
    return Card(
      child: ListTile(
        title: Text(s.name),
        subtitle: Text('${s.attended}/${s.total} · ${verdict(s)}'),
        trailing: Text('${s.percent.toStringAsFixed(1)}%',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ok ? Colors.green : Colors.red)),
      ),
    );
  }
}
