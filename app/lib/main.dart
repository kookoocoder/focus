import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'core/background.dart';
import 'core/notifications.dart';
import 'core/store.dart';
import 'features/alarms/alarms.dart';
import 'features/alarms/ring_screen.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/attendance/attendance_sync.dart';
import 'features/diet/diet_screen.dart';
import 'features/gate/gate_screen.dart';
import 'features/gym/gym_screen.dart';
import 'features/scroll/scroll_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/timer/timer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
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
  Widget build(BuildContext context) => MaterialApp(
    title: 'Focus',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    navigatorKey: navigatorKey,
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  static const pages = [
    AttendanceScreen(),
    GymScreen(),
    DietScreen(),
    GateScreen(),
    TimerScreen(),
    ScrollScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: i, children: pages),
    bottomNavigationBar: NavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: i,
      onDestinationSelected: (v) => setState(() => i = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          label: 'Attendance',
        ),
        NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Gym'),
        NavigationDestination(icon: Icon(Icons.restaurant), label: 'Diet'),
        NavigationDestination(icon: Icon(Icons.school_outlined), label: 'GATE'),
        NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Focus'),
        NavigationDestination(icon: Icon(Icons.swipe_vertical), label: 'Scroll'),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    ),
  );
}
