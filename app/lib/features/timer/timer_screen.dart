import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/effects.dart';
import '../../ui/kit.dart';
import '../../ui/thinking_orb.dart';
import '../../ui/tokens.dart';

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
    final total = minutes * 60;
    final finished = remaining == 0;
    return FocusPage(
      subtitle: running ? 'Deep work' : finished ? 'Session complete' : 'Pomodoro',
      title: 'Focus timer',
      hue: Hue.focus,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Ring(
                value: total == 0 ? 0 : remaining / total,
                size: 290,
                stroke: 7,
                color: finished ? Dissolve.success : Hue.focus,
              ),
              Opacity(
                opacity: .55,
                child: ThinkingOrb(
                  state: finished
                      ? OrbState.done
                      : running
                      ? OrbState.thinking
                      : OrbState.idle,
                  size: 230,
                  dots: 240,
                  dotSize: 1.6,
                  interactive: true,
                ),
              ),
              IgnorePointer(
                child: NumberTicker(
                  '$m:$s',
                  style: Typo.display.copyWith(
                    fontSize: 64,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Dissolve.bg, blurRadius: 24)],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 25, label: Text('25 min')),
              ButtonSegment(value: 50, label: Text('50 min')),
              ButtonSegment(value: 90, label: Text('90 min')),
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
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlossyButton(
              size: 72,
              onPressed: _toggle,
              child: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
            ),
            const SizedBox(width: 18),
            GlassIcon(icon: Icons.replay_rounded, tooltip: 'Reset', onTap: _reset),
          ],
        ),
      ],
    );
  }
}
