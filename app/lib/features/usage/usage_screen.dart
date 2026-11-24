import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/kit.dart';
import '../../ui/tokens.dart';
import '../scroll/scroll_screen.dart' show fmtSecs;

const _app = MethodChannel('focus/app');

/// Digital Wellbeing-style summary of phone use, rated for the day and week.
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});
  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> with WidgetsBindingObserver {
  bool access = false;
  List<Map<String, dynamic>> days = [];
  List<Map<String, dynamic>> apps = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final ok = await _app.invokeMethod<bool>('usageAccess') ?? false;
      if (!ok) {
        if (mounted) {
          setState(() {
            access = false;
            loading = false;
            error = null;
          });
        }
        return;
      }
      final raw = await _app.invokeMethod<String>('usage', {'days': 7});
      final j = jsonDecode(raw!) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        access = true;
        loading = false;
        error = null;
        days = (j['days'] as List).cast<Map<String, dynamic>>();
        apps = (j['apps'] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = '$e'; });
    }
  }

  /// 0..100 from hours of screen time. Under 3h is excellent, over 9h is poor.
  static int rate(double hours) => (hours <= 3
          ? 95
          : hours <= 5
          ? 80
          : hours <= 7
          ? 60
          : hours <= 9
          ? 40
          : 20)
      .clamp(0, 100);

  String _verdict(int r) => r >= 85
      ? 'Excellent use of time'
      : r >= 70
      ? 'Solid day'
      : r >= 50
      ? 'A bit heavy'
      : 'Cut the doomscroll';

  @override
  Widget build(BuildContext context) {
    if (!access) {
      return FocusPage(
        subtitle: 'Needs permission',
        title: 'Usage',
        hue: Hue.focus,
        children: [
          Panel(
            onTap: () => _app.invokeMethod('openUsageAccess'),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(Icons.insights_rounded, color: Hue.focus, size: 28),
                const SizedBox(height: 12),
                Text('Grant usage access', style: Typo.heading),
                const SizedBox(height: 6),
                Text(
                  'Focus reads the same screen-time data as Digital Wellbeing. Nothing leaves the phone.',
                  textAlign: TextAlign.center,
                  style: Typo.caption,
                ),
                const SizedBox(height: 16),
                Text('Open settings', style: TextStyle(color: Hue.focus, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
    }

    final today = days.isEmpty ? 0 : (days.first['secs'] as num).toInt();
    final unlocks = days.isEmpty ? 0 : (days.first['unlocks'] as num).toInt();
    final weekSecs = days.fold<int>(0, (a, d) => a + (d['secs'] as num).toInt());
    final todayRate = rate(today / 3600);
    final weekRate = rate(weekSecs / 3600 / (days.isEmpty ? 1 : days.length));
    final color = scoreColor(todayRate.toDouble(), 70);

    return FocusPage(
      subtitle: loading ? 'Reading…' : _verdict(todayRate),
      title: 'Usage',
      hue: Hue.focus,
      busy: loading,
      onRefresh: _load,
      children: [
        if (error != null)
          Panel(glow: Dissolve.danger, child: Text(error!, style: TextStyle(color: Dissolve.danger))),
        Panel(
          glow: color,
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Ring(
                value: todayRate / 100,
                size: 120,
                stroke: 10,
                color: color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NumberTicker('$todayRate', style: Typo.metric),
                    Text('rating', style: Typo.caption),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today', style: Typo.heading),
                    const SizedBox(height: 8),
                    Text(fmtSecs(today), style: Typo.metric.copyWith(fontSize: 22, color: Dissolve.fg)),
                    const SizedBox(height: 4),
                    Text('$unlocks unlocks', style: Typo.caption),
                    const SizedBox(height: 10),
                    Text('Week avg rating $weekRate', style: Typo.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (days.length > 1) ...[
          SectionLabel('Last 7 days'),
          Panel(child: SizedBox(height: 90, child: _Bars(days: days.reversed.toList()))),
        ],
        SectionLabel('Apps · most used this week'),
        for (final a in apps.take(12))
          Panel(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a['name']}', style: Typo.heading.copyWith(fontSize: 15.5)),
                      const SizedBox(height: 4),
                      Text(
                        'Today ${fmtSecs((a['today'] as num).toInt())} · ${(a['opens'] as num).toInt()} opens',
                        style: Typo.caption,
                      ),
                    ],
                  ),
                ),
                Text(fmtSecs((a['week'] as num).toInt()), style: Typo.heading.copyWith(fontSize: 15)),
              ],
            ),
          ),
        if (apps.isEmpty && !loading)
          Panel(
            padding: const EdgeInsets.all(28),
            child: Text('No app use recorded yet today.', style: Typo.caption, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.days});
  final List<Map<String, dynamic>> days;
  @override
  Widget build(BuildContext context) {
    final max = days.map((d) => (d['secs'] as num).toDouble()).fold(1.0, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (d['secs'] as num) / max),
                duration: Motion.slow,
                curve: Motion.curve,
                builder: (_, v, _) => FractionallySizedBox(
                  heightFactor: v.clamp(.04, 1),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Hue.focus,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
