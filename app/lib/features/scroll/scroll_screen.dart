import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/kit.dart';
import '../../ui/tokens.dart';

const _ch = MethodChannel('focus/scroll');

/// Day score 0-100: full marks under half your budget, falling to 0 at 1.5x,
/// minus 15 for every time you tried to open a feed app during a lecture.
int dayScore(Map<String, dynamic> d, int swipeLimit, int minLimit) {
  final sw = (d['limitedSwipes'] as int) / (swipeLimit > 0 ? swipeLimit : 300);
  final tm = (d['limitedSecs'] as int) / ((minLimit > 0 ? minLimit : 60) * 60);
  final r = sw > tm ? sw : tm;
  final base = r <= 0.5
      ? 100.0
      : r <= 1
      ? 100 - (r - 0.5) * 120
      : (40 - (r - 1) * 80).clamp(0, 40).toDouble();
  return (base - 15 * (d['lectureBlocks'] as int)).clamp(0, 100).round();
}

const goodDay = 70;

String fmtSecs(int s) =>
    s >= 3600 ? '${s ~/ 3600}h ${(s % 3600) ~/ 60}m' : '${s ~/ 60}m ${s % 60}s';

class ScrollScreen extends StatefulWidget {
  const ScrollScreen({super.key});
  @override
  State<ScrollScreen> createState() => _ScrollScreenState();
}

class _ScrollScreenState extends State<ScrollScreen>
    with WidgetsBindingObserver {
  bool enabled = false, lock = true;
  int limit = 0, tlimit = 0;
  Map<String, dynamic>? lecture;
  List<Map<String, dynamic>> apps = [], days = [];
  String since = '', last = '';
  int view = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _t?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final e = await _ch.invokeMethod<bool>('isEnabled') ?? false;
      final l = await _ch.invokeMethod<int>('getLimit') ?? 0;
      final tl = await _ch.invokeMethod<int>('getTimeLimit') ?? 0;
      final lk = await _ch.invokeMethod<bool>('getLock') ?? true;
      final ls = await _ch.invokeMethod<String>('last');
      final lec = await _ch.invokeMethod<String>('lecture');
      final s = await _ch.invokeMethod<String>('stats') ?? '[]';
      final h = jsonDecode(await _ch.invokeMethod<String>('history') ?? '{}');
      final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>()
        ..sort((a, b) => (b['n'] as int).compareTo(a['n'] as int));
      if (!mounted) return;
      setState(() {
        enabled = e;
        limit = l;
        tlimit = tl;
        lock = lk;
        last = ls ?? 'nothing yet';
        lecture = lec == null ? null : jsonDecode(lec);
        apps = list;
        days = (h['days'] as List? ?? []).cast<Map<String, dynamic>>();
        since = h['since'] ?? '';
      });
    } on MissingPluginException {
      // Not running on Android.
    }
  }

  Future<void> _call(String m, Map<String, dynamic> a) async {
    await _ch.invokeMethod(m, a);
    _refresh();
  }

  /// Days that count (since tracking began), newest first.
  List<Map<String, dynamic>> get _valid =>
      days.where((d) => (d['date'] as String).compareTo(since) >= 0).toList();

  int get _streak {
    var n = 0;
    final v = _valid;
    for (var i = 0; i < v.length; i++) {
      final ok = dayScore(v[i], limit, tlimit) >= goodDay;
      if (ok) {
        n++;
      } else if (i > 0) {
        break; // today may still be in progress
      }
    }
    return n;
  }

  Color _scoreColor(int s) => scoreColor(s.toDouble(), goodDay.toDouble());

  @override
  Widget build(BuildContext context) => FocusPage(
    title: 'Scroll control',
    subtitle: enabled ? 'Tracking on' : 'Tracking off',
    hue: Hue.focus,
    children: [
      if (!enabled) _enableGuide(),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('Today')),
            ButtonSegment(value: 1, label: Text('Progress')),
            ButtonSegment(value: 2, label: Text('Rules')),
          ],
          selected: {view},
          onSelectionChanged: (v) => setState(() => view = v.first),
        ),
      ),
      ...switch (view) {
        0 => _today(),
        1 => _progress(),
        _ => _rules(),
      },
    ],
  );

  Widget _enableGuide() => Panel(
    glow: Dissolve.warning,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.accessibility_new_rounded, color: Dissolve.warning, size: 20),
            const SizedBox(width: 10),
            Text('Turn on tracking', style: Typo.heading.copyWith(color: Dissolve.warning)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '1. Tap Open settings.\n'
          '2. Look for "Focus". On Android 11 it is often under '
          '"Downloaded apps" or "Installed services" at the bottom of the list.\n'
          '3. Turn it on and allow.',
          style: Typo.caption,
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Dissolve.warning),
          onPressed: () => _ch.invokeMethod('openSettings'),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );

  // ---------------- Today ----------------
  List<Widget> _today() {
    final total = apps.fold<int>(0, (a, e) => a + (e['n'] as int));
    final lim = apps.where((e) => e['limited'] == true);
    final limSw = lim.fold<int>(0, (a, e) => a + (e['n'] as int));
    final limSecs = lim.fold<int>(0, (a, e) => a + (e['secs'] as int));
    final today = days.isEmpty ? null : days.first;
    final score = today == null ? null : dayScore(today, limit, tlimit);
    return [
      if (lecture != null)
        Panel(
          glow: Hue.gate,
          child: Row(
            children: [
              Icon(Icons.lock_rounded, color: Hue.gate, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lecture lock active', style: Typo.heading),
                    Text('${lecture!['subject']}: ${lecture!['topic']}', style: Typo.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      Panel(
        glow: score == null ? Hue.focus : _scoreColor(score),
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            if (score != null) ...[
              Ring(
                value: score / 100,
                size: 104,
                stroke: 9,
                color: _scoreColor(score),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score', style: Typo.metric),
                    Text('score', style: Typo.caption),
                  ],
                ),
              ),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Swipes today', style: Typo.caption),
                  Text('$total', style: Typo.metric.copyWith(fontSize: 36)),
                  const SizedBox(height: 6),
                  Text('Feed apps ${fmtSecs(limSecs)}', style: Typo.caption),
                ],
              ),
            ),
          ],
        ),
      ),
      if (limit > 0) _budget('Swipe budget', limSw / limit, '$limSw / $limit'),
      if (tlimit > 0)
        _budget('Time budget', limSecs / (tlimit * 60), '${fmtSecs(limSecs)} / ${tlimit}m'),
      SectionLabel('By app'),
      if (apps.isEmpty)
        Panel(child: Text('No scrolling yet today', style: Typo.caption)),
      for (final a in apps)
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
          child: Row(
            children: [
              Icon(
                a['limited'] == true ? Icons.slow_motion_video_rounded : Icons.swipe_vertical_rounded,
                color: a['limited'] == true ? Dissolve.warning : Dissolve.muted,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['name'] as String, style: Typo.heading.copyWith(fontSize: 15.5)),
                    Text('${fmtSecs(a['secs'] as int)} on screen', style: Typo.caption),
                  ],
                ),
              ),
              Text('${a['n']}', style: Typo.metric.copyWith(fontSize: 20)),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        child: Text(
          'Last scroll seen: $last\n'
          'A session is a stretch of scrolling in one app, ended by 60 seconds '
          'of inactivity.',
          style: Typo.caption.copyWith(fontSize: 12),
        ),
      ),
    ];
  }

  Widget _budget(String label, double v, String text) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Typo.heading.copyWith(fontSize: 15.5))),
            Text(text, style: Typo.caption),
          ],
        ),
        const SizedBox(height: 10),
        Bar(value: v, color: v >= 1 ? Dissolve.danger : v >= .75 ? Dissolve.warning : Hue.focus, height: 8),
      ],
    ),
  );

  // ---------------- Progress ----------------
  List<Widget> _progress() {
    final v = _valid;
    final week = v.take(7).toList().reversed.toList();
    final scores = [for (final d in v) dayScore(d, limit, tlimit)];
    final avg = scores.isEmpty
        ? 0
        : (scores.take(7).fold<int>(0, (a, b) => a + b) / scores.take(7).length).round();
    final good = scores.where((s) => s >= goodDay).length;
    final blocks = v.fold<int>(0, (a, d) => a + (d['lectureBlocks'] as int));
    return [
      Row(
        children: [
          _stat('Streak', '$_streak', Icons.local_fire_department_rounded, Dissolve.warning),
          const SizedBox(width: 10),
          _stat('7-day avg', '$avg', Icons.insights_rounded, _scoreColor(avg)),
        ],
      ),
      Row(
        children: [
          _stat('Good days', '$good/${v.length}', Icons.check_circle_rounded, Dissolve.success),
          const SizedBox(width: 10),
          _stat('Lecture slips', '$blocks', Icons.lock_open_rounded, blocks > 0 ? Dissolve.danger : Dissolve.muted),
        ],
      ),
      SectionLabel('Last 7 days'),
      Panel(
        child: SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in week)
                Expanded(child: _bar(dayScore(d, limit, tlimit), (d['date'] as String).substring(8))),
            ],
          ),
        ),
      ),
      SectionLabel('History'),
      for (final d in v.take(14))
        Panel(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['date'] as String, style: Typo.heading.copyWith(fontSize: 15)),
                    Text(
                      '${d['limitedSwipes']} feed swipes · ${fmtSecs(d['limitedSecs'] as int)} · '
                      '${d['sessions']} sessions',
                      style: Typo.caption,
                    ),
                  ],
                ),
              ),
              Text(
                '${dayScore(d, limit, tlimit)}',
                style: Typo.metric.copyWith(fontSize: 20, color: _scoreColor(dayScore(d, limit, tlimit))),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _bar(int score, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$score', style: Typo.caption.copyWith(fontSize: 11, color: Dissolve.fg)),
        const SizedBox(height: 4),
        Container(
          height: 96 * score / 100 + 3,
          decoration: BoxDecoration(
            color: _scoreColor(score),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Typo.caption.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _stat(String t, String v, IconData i, Color c) => Expanded(
    child: Panel(
      glow: c,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, color: c, size: 20),
          const SizedBox(height: 8),
          Text(v, style: Typo.metric),
          const SizedBox(height: 2),
          Text(t, style: Typo.caption),
        ],
      ),
    ),
  );

  // ---------------- Rules ----------------
  List<Widget> _rules() => [
    Panel(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lecture lock', style: Typo.heading),
                SizedBox(height: 4),
                Text(
                  'During PW lectures (from your GATE schedule) YouTube, Instagram, '
                  'TikTok, Facebook, X, Snapchat, Reddit, LinkedIn and similar are '
                  'sent straight back to the home screen. No bypass. Each attempt '
                  'costs 15 score points.',
                  style: Typo.caption,
                ),
              ],
            ),
          ),
          Switch(value: lock, onChanged: (v) => _call('setLock', {'on': v})),
        ],
      ),
    ),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(limit == 0 ? 'Swipe limit · off' : 'Swipe limit · $limit / day', style: Typo.heading),
          Slider(
            value: (limit / 50).clamp(0, 40).toDouble(),
            max: 40,
            divisions: 40,
            activeColor: Hue.focus,
            label: limit == 0 ? 'Off' : '$limit',
            onChanged: (v) => setState(() => limit = (v * 50).round()),
            onChangeEnd: (v) => _call('setLimit', {'limit': (v * 50).round()}),
          ),
          Text(tlimit == 0 ? 'Time limit · off' : 'Time limit · $tlimit min / day', style: Typo.heading),
          Slider(
            value: (tlimit / 5).clamp(0, 36).toDouble(),
            max: 36,
            divisions: 36,
            activeColor: Hue.focus,
            label: tlimit == 0 ? 'Off' : '$tlimit min',
            onChanged: (v) => setState(() => tlimit = (v * 5).round()),
            onChangeEnd: (v) => _call('setTimeLimit', {'minutes': (v * 5).round()}),
          ),
          Text(
            'When either limit is reached, feed apps are sent back to the '
            'home screen for the rest of the day.',
            style: Typo.caption,
          ),
        ],
      ),
    ),
  ];
}
