import 'package:flutter/material.dart';

import '../../core/store.dart';

/// GATE 2028 (CSE) tracker. Topics are NOT hardcoded: they will be imported from
/// the PW course. Until then you can add items manually.
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  static const _key = 'gate';
  // GATE 2028 exam date is not announced yet; Feb 2028 is the target.
  static final target = DateTime(2028, 2, 1);
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    items = (Store.read<List>(_key) ?? []).cast<Map<String, dynamic>>();
  }

  void _save() {
    Store.write(_key, items);
    setState(() {});
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add topic / lecture'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      items.add({'title': c.text.trim(), 'done': false});
      _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = target.difference(DateTime.now()).inDays;
    final done = items.where((e) => e['done'] == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('GATE 2028')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: Text('$days days left (to Feb 2028)'),
              subtitle: Text('$done / ${items.length} completed'),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final e in items)
                  CheckboxListTile(
                    value: e['done'] == true,
                    title: Text(e['title']),
                    onChanged: (v) {
                      e['done'] = v;
                      _save();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
