import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

String fmtSecs(int s) => s >= 3600
    ? '${s ~/ 3600}h ${(s % 3600) ~/ 60}m'
    : '${s ~/ 60}m ${s % 60}s';

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

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Scroll control'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Today'),
            Tab(text: 'Progress'),
            Tab(text: 'Rules'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!enabled) _enableBanner(),
          Expanded(
            child: TabBarView(children: [_today(), _progress(), _rules()]),
          ),
        ],
      ),
    ),
  );

  Widget _enableBanner() => Card(
    margin: const EdgeInsets.all(12),
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.warning_amber),
      title: const Text('Tracking is off'),
      subtitle: const Text(
        'Enable "Focus scroll control" in Accessibility settings.',
      ),
      trailing: FilledButton(
        onPressed: () => _ch.invokeMethod('openSettings'),
        child: const Text('Enable'),
      ),
    ),
  );

  // ---------------- Today ----------------
  Widget _today() {
    final t = Theme.of(context).textTheme;
    final total = apps.fold<int>(0, (a, e) => a + (e['n'] as int));
    final lim = apps.where((e) => e['limited'] == true);
    final limSw = lim.fold<int>(0, (a, e) => a + (e['n'] as int));
    final limSecs = lim.fold<int>(0, (a, e) => a + (e['secs'] as int));
    final today = days.isEmpty ? null : days.first;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (lecture != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Lecture lock active'),
              subtitle: Text('${lecture!['subject']}: ${lecture!['topic']}'),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (today != null)
                  _ScoreRing(score: dayScore(today, limit, tlimit)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Swipes today', style: t.labelLarge),
                      Text('$total', style: t.displaySmall),
                      Text('Feed apps: ${fmtSecs(limSecs)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (limit > 0) _budget('Swipe budget', limSw / limit, '$limSw / $limit'),
        if (tlimit > 0)
          _budget(
            'Time budget',
            limSecs / (tlimit * 60),
            '${fmtSecs(limSecs)} / ${tlimit}m',
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text('By app'),
        ),
        if (apps.isEmpty) const ListTile(title: Text('No scrolling yet today')),
        for (final a in apps)
          ListTile(
            leading: Icon(
              a['limited'] == true
                  ? Icons.slow_motion_video
                  : Icons.swipe_vertical,
            ),
            title: Text(a['name'] as String),
            subtitle: Text('${fmtSecs(a['secs'] as int)} on screen'),
            trailing: Text('${a['n']}', style: t.titleLarge),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Last scroll seen: $last', style: const TextStyle(fontSize: 12)),
        ),
        const _SessionsHint(),
      ],
    );
  }

  Widget _budget(String label, double v, String text) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $text'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: v.clamp(0, 1).toDouble(),
            color: v >= 1 ? Colors.red : null,
          ),
        ],
      ),
    ),
  );

  // ---------------- Progress ----------------
  Widget _progress() {
    final v = _valid;
    final week = v.take(7).toList().reversed.toList();
    final scores = [for (final d in v) dayScore(d, limit, tlimit)];
    final avg = scores.isEmpty
        ? 0
        : (scores.take(7).fold<int>(0, (a, b) => a + b) /
                  scores.take(7).length)
              .round();
    final good = scores.where((s) => s >= goodDay).length;
    final blocks = v.fold<int>(0, (a, d) => a + (d['lectureBlocks'] as int));
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            _stat('Streak', '$_streak', Icons.local_fire_department, '🔥 days'),
            _stat('7-day avg', '$avg', Icons.insights, 'score'),
          ],
        ),
        Row(
          children: [
            _stat('Good days', '$good', Icons.check_circle_outline,
                'of ${v.length}'),
            _stat('Lecture slips', '$blocks', Icons.lock_open, 'blocked'),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last 7 days (score)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in week)
                        Expanded(
                          child: _bar(
                            dayScore(d, limit, tlimit),
                            (d['date'] as String).substring(8),
                            scheme,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final d in v.take(14))
                ListTile(
                  dense: true,
                  title: Text(d['date'] as String),
                  subtitle: Text(
                    '${d['limitedSwipes']} feed swipes · '
                    '${fmtSecs(d['limitedSecs'] as int)} · '
                    '${d['sessions']} sessions',
                  ),
                  trailing: Text(
                    '${dayScore(d, limit, tlimit)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(int score, String label, ColorScheme s) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$score', style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 2),
        Container(
          height: 100 * score / 100 + 2,
          decoration: BoxDecoration(
            color: score >= goodDay ? Colors.green : Colors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _stat(String t, String v, IconData i, String sub) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i),
            Text(v, style: Theme.of(context).textTheme.headlineMedium),
            Text('$t · $sub', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );

  // ---------------- Rules ----------------
  Widget _rules() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Card(
        child: SwitchListTile(
          secondary: const Icon(Icons.lock),
          title: const Text('Lecture lock'),
          subtitle: const Text(
            'During PW lectures (from your GATE schedule) YouTube, Instagram, '
            'TikTok, Facebook, X, Snapchat, Reddit, LinkedIn and similar are '
            'sent straight back to the home screen. No bypass. Each attempt '
            'costs 15 score points.',
          ),
          value: lock,
          onChanged: (v) => _call('setLock', {'on': v}),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                limit == 0 ? 'Swipe limit: off' : 'Swipe limit: $limit / day',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: (limit / 50).clamp(0, 40).toDouble(),
                max: 40,
                divisions: 40,
                label: limit == 0 ? 'Off' : '$limit',
                onChanged: (v) => setState(() => limit = (v * 50).round()),
                onChangeEnd: (v) => _call('setLimit', {'limit': (v * 50).round()}),
              ),
              Text(
                tlimit == 0
                    ? 'Time limit: off'
                    : 'Time limit: $tlimit min / day',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: (tlimit / 5).clamp(0, 36).toDouble(),
                max: 36,
                divisions: 36,
                label: tlimit == 0 ? 'Off' : '$tlimit min',
                onChanged: (v) => setState(() => tlimit = (v * 5).round()),
                onChangeEnd: (v) =>
                    _call('setTimeLimit', {'minutes': (v * 5).round()}),
              ),
              const Text(
                'When either limit is reached, feed apps are sent back to the '
                'home screen for the rest of the day.',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SessionsHint extends StatelessWidget {
  const _SessionsHint();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(12),
    child: Text(
      'A session is a stretch of scrolling in one app, ended by 60 seconds '
      'of inactivity. Sessions feed the Progress tab.',
      style: TextStyle(fontSize: 12),
    ),
  );
}

class _ScoreRing extends StatelessWidget {
  final int score;
  const _ScoreRing({required this.score});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 84,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            color: score >= goodDay ? Colors.green : Colors.orange,
            backgroundColor: Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score', style: Theme.of(context).textTheme.headlineSmall),
            const Text('score', style: TextStyle(fontSize: 10)),
          ],
        ),
      ],
    ),
  );
}
