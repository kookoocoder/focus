import 'package:flutter/material.dart';
import '../../core/store.dart';

/// Minimal diet log: you type what you ate plus protein/carbs totals. No auto breakdown.
class DietScreen extends StatefulWidget {
  const DietScreen({super.key});
  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  static const _key = 'diet';
  List<Map<String, dynamic>> log = [];
  String get today => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    log = (Store.read<List>(_key) ?? []).cast<Map<String, dynamic>>();
  }

  num _sum(String f) => log
      .where((e) => e['date'] == today)
      .fold<num>(0, (a, e) => a + (num.tryParse('${e[f]}') ?? 0));

  Future<void> _add() async {
    final food = TextEditingController();
    final protein = TextEditingController();
    final carbs = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What did you eat?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: food, decoration: const InputDecoration(labelText: 'Food')),
          TextField(controller: protein, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
          TextField(controller: carbs, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && food.text.trim().isNotEmpty) {
      log.insert(0, {
        'date': today,
        'food': food.text.trim(),
        'protein': protein.text,
        'carbs': carbs.text,
      });
      Store.write(_key, log);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final todays = log.where((e) => e['date'] == today).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Diet')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            title: const Text('Today'),
            subtitle: Text('Protein ${_sum('protein')} g   Carbs ${_sum('carbs')} g'),
          ),
        ),
        Expanded(
          child: ListView(children: [
            for (final e in todays)
              ListTile(
                title: Text(e['food']),
                subtitle: Text('P ${e['protein']} g  C ${e['carbs']} g'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    log.remove(e);
                    Store.write(_key, log);
                    setState(() {});
                  },
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
