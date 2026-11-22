import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'alarms.dart';

/// Full-screen view shown while an alarm is ringing.
class RingScreen extends StatelessWidget {
  final AlarmSettings alarm;
  const RingScreen({super.key, required this.alarm});

  @override
  Widget build(BuildContext context) {
    final title = alarm.notificationSettings.title;
    final now = TimeOfDay.now().format(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.alarm, size: 72),
              const SizedBox(height: 16),
              Text(
                now,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () async {
                    await afterDismiss(alarm.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Stop', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () async {
                    await Alarm.stop(alarm.id);
                    await snooze(alarm.id, title.replaceAll(' (snoozed)', ''));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Snooze 5 min',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
