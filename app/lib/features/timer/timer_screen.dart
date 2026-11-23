import 'dart:async';

import 'package:flutter/material.dart';

/// Pomodoro-style focus timer.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});
  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int minutes = 25;
  late int remaining = minutes * 60;
  Timer? _t;

  bool get running => _t != null;

  void _toggle() {
    if (running) {
      _t!.cancel();
      _t = null;
    } else {
      _t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (remaining <= 1) {
          t.cancel();
          _t = null;
          remaining = 0;
        } else {
          remaining--;
        }
        setState(() {});
      });
    }
    setState(() {});
  }

  void _reset() {
    _t?.cancel();
    _t = null;
    remaining = minutes * 60;
    setState(() {});
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$m:$s',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 25, label: Text('25')),
                ButtonSegment(value: 50, label: Text('50')),
                ButtonSegment(value: 90, label: Text('90')),
              ],
              selected: {minutes},
              onSelectionChanged: running
                  ? null
                  : (v) {
                      minutes = v.first;
                      remaining = minutes * 60;
                      setState(() {});
                    },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: _toggle,
                  child: Text(running ? 'Pause' : 'Start'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
