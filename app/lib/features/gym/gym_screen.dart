import 'package:flutter/material.dart';
import '../../core/store.dart';

/// Simple gym log: one entry per exercise set group, grouped by date.
class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  static const _key = 'gym';
  List<Map<String, dynamic>> log = [];

  @override
  void initState() {
    super.initState();
    log = (Store.read<List>(_key) ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final sets = TextEditingController();
    final reps = TextEditingController();
    final kg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log exercise'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Exercise')),
          TextField(controller: sets, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sets')),
          TextField(controller: reps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps')),
          TextField(controller: kg, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      log.insert(0, {
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'name': name.text.trim(),
        'sets': sets.text,
        'reps': reps.text,
        'kg': kg.text,
      });
      Store.write(_key, log);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gym')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: log.isEmpty
          ? const Center(child: Text('No workouts logged yet'))
          : ListView.builder(
              itemCount: log.length,
              itemBuilder: (_, i) {
                final e = log[i];
                return Dismissible(
                  key: ValueKey('${e['date']}${e['name']}$i'),
                  onDismissed: (_) {
                    log.removeAt(i);
                    Store.write(_key, log);
                    setState(() {});
                  },
                  child: ListTile(
                    title: Text(e['name']),
                    subtitle: Text('${e['sets']} x ${e['reps']} @ ${e['kg']} kg'),
                    trailing: Text(e['date']),
                  ),
                );
              },
            ),
    );
  }
}
