import 'package:flutter/material.dart';
import '../../core/credentials.dart';
import '../../core/store.dart';
import 'erp_client.dart';
import 'attendance.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const _key = 'subjects';
  List<Subject> subjects = [];
  bool syncing = false;

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


  Future<void> _sync() async {
    var (id, pw) = await Credentials.load();
    if (id == null || pw == null) {
      final idC = TextEditingController();
      final pwC = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ERP login'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: idC, decoration: const InputDecoration(labelText: 'ERP ID')),
            TextField(controller: pwC, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true) return;
      id = idC.text.trim();
      pw = pwC.text;
      await Credentials.save(id, pw);
    }
    setState(() => syncing = true);
    final erp = ErpClient();
    try {
      await erp.login(id, pw);
      final fetched = await erp.fetchAttendance();
      for (final f in fetched) {
        final i = subjects.indexWhere((s) => s.name == f.name);
        final total = f.present + f.absent;
        if (i >= 0) {
          subjects[i].attended = f.present;
          subjects[i].total = total;
        } else {
          subjects.add(Subject(
            name: f.name,
            isLab: f.name.toLowerCase().contains('lab'),
            attended: f.present,
            total: total,
          ));
        }
      }
      _save();
      _msg('Synced ${fetched.length} subjects from ERP');
    } catch (e) {
      _msg('Sync failed: $e');
    } finally {
      erp.close();
      if (mounted) setState(() => syncing = false);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
      appBar: AppBar(title: const Text('Attendance'), actions: [
        syncing
            ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(icon: const Icon(Icons.sync), tooltip: 'Sync from ERP', onPressed: _sync),
      ]),
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
      child: InkWell(
        onLongPress: () { s.isLab = !s.isLab; _save(); },
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
      )),
    );
  }
}
