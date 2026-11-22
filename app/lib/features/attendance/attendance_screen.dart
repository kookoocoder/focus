import 'package:flutter/material.dart';
import '../../core/store.dart';
import 'attendance.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _key = 'subjects';
  List<Subject> subjects = [];

  @override
  void initState() {
    super.initState();
    final raw = Store.read<List>(_key) ?? [];
    subjects = raw.map((e) => Subject.fromJson(e)).toList();
  }

  void _save() {
    Store.write(_key, subjects.map((e) => e.toJson()).toList());
    setState(() {});
  }

  Future<void> _addSubject() async {
    final c = TextEditingController();
    bool lab = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add subject'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: c, decoration: const InputDecoration(labelText: 'Name')),
            SwitchListTile(
              title: const Text('Practical / lab'),
              value: lab,
              onChanged: (v) => set(() => lab = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      subjects.add(Subject(name: c.text.trim(), isLab: lab));
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final overall = overallPercent(subjects);
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      floatingActionButton:
          FloatingActionButton(onPressed: _addSubject, child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            title: const Text('Overall'),
            subtitle: const Text('Must stay above 50%'),
            trailing: Text('${overall.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: overall >= 50 ? Colors.green : Colors.red)),
          ),
        ),
        for (final s in subjects) _tile(s),
        if (subjects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Add your subjects with +')),
          ),
      ]),
    );
  }

  Widget _tile(Subject s) {
    final ok = s.isLab || s.percent >= 75;
    final advice = s.isLab
        ? 'Lab: no minimum'
        : ok
            ? 'Can skip ${s.safeSkips} more'
            : 'Attend next ${s.mustAttend} in a row';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(s.name + (s.isLab ? ' (Lab)' : ''),
                    style: Theme.of(context).textTheme.titleMedium)),
            Text('${s.percent.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ok ? Colors.green : Colors.red)),
          ]),
          Text('${s.attended}/${s.total} - $advice'),
          Row(children: [
            TextButton(
                onPressed: () { s.attended++; s.total++; _save(); },
                child: const Text('Attended')),
            TextButton(
                onPressed: () { s.total++; _save(); },
                child: const Text('Skipped')),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () { subjects.remove(s); _save(); }),
          ]),
        ]),
      ),
    );
  }
}
