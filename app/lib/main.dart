import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/background.dart';
import 'core/notifications.dart';
import 'core/store.dart';
import 'core/updater.dart';
import 'features/alarms/alarms.dart';
import 'features/alarms/ring_screen.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/attendance/attendance_sync.dart';
import 'features/diet/diet_screen.dart';
import 'features/gate/gate_screen.dart';
import 'features/gym/gym_screen.dart';
import 'features/scroll/scroll_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/timer/timer_screen.dart';
import 'ui/kit.dart';
import 'ui/theme.dart';
import 'ui/thinking_orb.dart';
import 'ui/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  Dissolve.apply(
    Look.values.asNameMap()[Store.read<String>(lookKey)] ?? Look.dark,
    rebuild: false,
  );
  WidgetsBinding.instance.addObserver(_LookObserver());
  await Alarm.init();
  runApp(const FocusApp());
  _listenForRinging();
  await scheduleActivities();
  await Notifier.requestPermission();
  await scheduleBackgroundSync();
  if (Store.read<String>(lastSyncKey) == null) {
    syncAndNotify(force: true).ignore();
  }
}

const lookKey = 'theme_mode';

class _LookObserver with WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() {
    if (Dissolve.look == Look.system) Dissolve.apply(Look.system);
  }
}

void _systemBars() => SystemChrome.setSystemUIOverlayStyle(
  SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Dissolve.light
        ? Brightness.dark
        : Brightness.light,
    systemNavigationBarColor: Dissolve.bg,
    systemNavigationBarIconBrightness: Dissolve.light
        ? Brightness.dark
        : Brightness.light,
  ),
);

final navigatorKey = GlobalKey<NavigatorState>();
final _shown = <int>{};

void _listenForRinging() {
  Alarm.ringing.listen((set) {
    for (final a in set.alarms) {
      if (_shown.add(a.id)) {
        navigatorKey.currentState
            ?.push(MaterialPageRoute(builder: (_) => RingScreen(alarm: a)))
            .then((_) => _shown.remove(a.id));
      }
    }
  });
}

class FocusApp extends StatelessWidget {
  const FocusApp({super.key});
  @override
  Widget build(BuildContext context) {
    _systemBars();
    return MaterialApp(
      title: 'Focus',
      debugShowCheckedModeBanner: false,
      theme: focusTheme(),
      navigatorKey: navigatorKey,
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(child: Backdrop()),
          ?child,
        ],
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  int epoch = 0;
  bool _opening = false;
  static const pages = [
    AttendanceScreen(),
    GateScreen(),
    _Split(labels: ['Gym', 'Diet'], pages: [GymScreen(), DietScreen()]),
    _Split(labels: ['Timer', 'Scroll'], pages: [TimerScreen(), ScrollScreen()]),
  ];
  static List<(IconData, IconData, Color)> get tabs => [
    (Icons.fact_check_outlined, Icons.fact_check_rounded, Hue.classes),
    (Icons.school_outlined, Icons.school_rounded, Hue.gate),
    (Icons.fitness_center_outlined, Icons.fitness_center_rounded, Hue.body),
    (
      Icons.center_focus_strong_outlined,
      Icons.center_focus_strong_rounded,
      Hue.focus,
    ),
  ];

  @override
  void initState() {
    super.initState();
    FocusPage.openSettings = () => navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    checkForUpdate(navigatorKey);
  }

  Future<void> _openAssistant() async {
    if (_opening) return;
    _opening = true;
    HapticFeedback.lightImpact();
    final changed = await navigatorKey.currentState!.push<bool>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const AssistantScreen(),
        transitionsBuilder: (_, a, _, child) {
          final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: c,
            child: ScaleTransition(
              scale: Tween(begin: .94, end: 1.0).animate(c),
              alignment: Alignment.bottomRight,
              child: child,
            ),
          );
        },
      ),
    );
    _opening = false;
    if (changed == true) setState(() => epoch++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    extendBody: true,
    body: IndexedStack(
      index: i,
      children: [
        // Hidden tabs stay alive but must not animate: on slow phones their
        // tickers starve the frame budget and taps get dropped.
        for (final (n, p) in pages.indexed)
          TickerMode(
            enabled: n == i,
            child: KeyedSubtree(key: ValueKey((n, epoch)), child: p),
          ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: _NavPill(
                index: i,
                tabs: tabs,
                onSelect: (v) {
                  if (v != i) HapticFeedback.selectionClick();
                  setState(() => i = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            // Fires on touch-down and skips the blur layer, so a busy frame
            // can't swallow the tap.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _openAssistant(),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Dissolve.surface,
                  border: Border.all(color: Dissolve.edge),
                  boxShadow: [
                    BoxShadow(
                      color: Dissolve.shadow,
                      blurRadius: 30,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: const Center(
                  child: IgnorePointer(
                    child: ThinkingOrb(size: 40, dots: 70, dotSize: 2.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, required this.radius});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Dissolve.shadow,
          blurRadius: 30,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: Dissolve.surface.withValues(alpha: .72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: Dissolve.edge),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.index,
    required this.tabs,
    required this.onSelect,
  });
  final int index;
  final List<(IconData, IconData, Color)> tabs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => _Glass(
    radius: 32,
    child: SizedBox(
      height: 62,
      child: LayoutBuilder(
        builder: (_, box) {
          final w = (box.maxWidth - 12) / tabs.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                left: 6 + index * w + 3,
                top: 9,
                width: w - 6,
                height: 44,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: tabs[index].$3,
                    gradient: Dissolve.light
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(tabs[index].$3, Colors.white, .15)!,
                              tabs[index].$3,
                            ],
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: tabs[index].$3.withValues(alpha: .35),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    for (final (n, (off, on, _)) in tabs.indexed)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(n),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (c, a) =>
                                  ScaleTransition(scale: a, child: c),
                              child: Icon(
                                n == index ? on : off,
                                key: ValueKey(n == index),
                                size: 22,
                                color: n == index
                                    ? Dissolve.ink
                                    : Dissolve.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// Two screens behind one nav tab, switched by the [SubTabs] bar each
/// screen's [FocusPage] draws above its title.
class _Split extends StatefulWidget {
  const _Split({required this.labels, required this.pages});
  final List<String> labels;
  final List<Widget> pages;
  @override
  State<_Split> createState() => _SplitState();
}

class _SplitState extends State<_Split> {
  int i = 0;
  @override
  Widget build(BuildContext context) => SubTabs(
    labels: widget.labels,
    index: i,
    onSelect: (v) => setState(() => i = v),
    child: IndexedStack(
      index: i,
      children: [
        for (final (n, p) in widget.pages.indexed)
          TickerMode(enabled: n == i, child: p),
      ],
    ),
  );
}
