import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'pw_auto_refresh.dart';
import 'pw_connect_screen.dart';
import 'pw_data.dart';

/// GATE 2028 (CSE) progress, taken only from your PW batch.
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  // GATE 2028 exam date is not announced yet; Feb 2028 is the target.
  static final target = DateTime(2028, 2, 1);
  PwCourse course = PwCourse.load();
  bool autoRefreshing = PwAutoRefresh.due;

  @override
  void initState() {
    super.initState();
    _importOldCapture();
  }

  /// One-time import of the first raw capture, then delete it (it held tokens).
  Future<void> _importOldCapture() async {
    final f = File(
      '${(await getApplicationDocumentsDirectory()).path}/pw_capture.jsonl',
    );
    if (!await f.exists()) return;
    course = await rebuildFromCapture();
    await f.delete();
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PwConnectScreen()),
    );
    setState(() => course = PwCourse.load());
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final days = target.difference(DateTime.now()).inDays;
    final subjects = course.studySubjects;
    final total = subjects.fold<int>(0, (a, s) => a + s.total);
    final done = subjects.fold<int>(0, (a, s) => a + s.completed);
    final today = DateTime.now();
    final todays = course.schedule
        .where(
          (l) =>
              l.start.year == today.year &&
              l.start.month == today.month &&
              l.start.day == today.day,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GATE 2028'),
        actions: [
          TextButton.icon(
            onPressed: _refresh,
            icon: Icon(course.subjects.isEmpty ? Icons.link : Icons.refresh),
            label: Text(course.subjects.isEmpty ? 'Connect PW' : 'Update'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text('$days days left'),
              subtitle: Text(
                course.batchName.isEmpty
                    ? 'Target: GATE Feb 2028'
                    : course.batchName,
              ),
              trailing: total == 0
                  ? null
                  : Text(
                      '$done/$total',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          if (course.subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tap "Connect PW", log in and open your batch. '
                'Subjects and lectures come straight from PW.',
              ),
            ),
          if (todays.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text("Today's PW lectures"),
            ),
            for (final l in todays)
              Card(
                child: ListTile(
                  leading: Text(
                    _hm(l.start),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  title: Text(l.subject),
                  subtitle: Text(l.topic),
                ),
              ),
          ],
          if (subjects.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text('Subjects'),
            ),
          for (final s in subjects)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.name)),
                        Text(
                          s.total == 0
                              ? 'not started by PW'
                              : '${s.completed}/${s.total}',
                        ),
                      ],
                    ),
                    if (s.total > 0) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: s.completed / s.total),
                    ],
                  ],
                ),
              ),
            ),
          if (course.updated != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'From PW · ${course.updated!.substring(0, 16).replaceFirst('T', ' ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
