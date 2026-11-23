import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _ch = MethodChannel('focus/scroll');

class ScrollScreen extends StatefulWidget {
  const ScrollScreen({super.key});
  @override
  State<ScrollScreen> createState() => _ScrollScreenState();
}

class _ScrollScreenState extends State<ScrollScreen>
    with WidgetsBindingObserver {
  bool enabled = false;
  int limit = 0;
  List<Map<String, dynamic>> apps = [];
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
      final s = await _ch.invokeMethod<String>('stats') ?? '[]';
      final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>()
        ..sort((a, b) => (b['n'] as int).compareTo(a['n'] as int));
      if (mounted) {
        setState(() {
          enabled = e;
          limit = l;
          apps = list;
        });
      }
    } on MissingPluginException {
      // Not running on Android.
    }
  }

  Future<void> _setLimit(int v) async {
    await _ch.invokeMethod('setLimit', {'limit': v});
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final total = apps.fold<int>(0, (a, e) => a + (e['n'] as int));
    final limitedTotal = apps
        .where((e) => e['limited'] == true)
        .fold<int>(0, (a, e) => a + (e['n'] as int));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Scroll control')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (!enabled)
            Card(
              color: scheme.errorContainer,
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
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Swipes today',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text('$total',
                      style: Theme.of(context).textTheme.displayMedium),
                  if (limit > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (limitedTotal / limit).clamp(0, 1).toDouble(),
                    ),
                    const SizedBox(height: 4),
                    Text('Social/feed apps: $limitedTotal / $limit'),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    limit == 0
                        ? 'Daily limit: off'
                        : 'Daily limit: $limit swipes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Applies to YouTube, Instagram, TikTok, Facebook, X, '
                    'Snapchat, Reddit, LinkedIn and similar. When reached, '
                    'those apps are sent back to the home screen.',
                  ),
                  Slider(
                    value: (limit / 50).clamp(0, 40).toDouble(),
                    max: 40,
                    divisions: 40,
                    label: limit == 0 ? 'Off' : '$limit',
                    onChanged: (v) => setState(() => limit = (v * 50).round()),
                    onChangeEnd: (v) => _setLimit((v * 50).round()),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('By app'),
          ),
          if (apps.isEmpty) const ListTile(title: Text('No scrolling yet today')),
          for (final a in apps)
            ListTile(
              leading: Icon(a['limited'] == true
                  ? Icons.slow_motion_video
                  : Icons.swipe_vertical),
              title: Text(a['name'] as String),
              subtitle: Text('${((a['px'] as int) / 1000).round()}k px'),
              trailing: Text('${a['n']}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
        ],
      ),
    );
  }
}
