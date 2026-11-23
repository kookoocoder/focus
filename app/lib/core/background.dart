import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../features/attendance/attendance_sync.dart';
import 'store.dart';

const _attendanceTask = 'erpAttendanceSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Store.init();
    try {
      if (task == _attendanceTask) await syncAndNotify();
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Checks the ERP every 6 hours while the phone has internet.
Future<void> scheduleBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _attendanceTask,
    _attendanceTask,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
