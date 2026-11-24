import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/credentials.dart';
import '../../core/store.dart';
import '../../ui/kit.dart';
import '../../ui/thinking_orb.dart';
import '../../ui/tokens.dart';
import '../attendance/attendance_sync.dart';
import '../body/body_goal.dart';

const onboardedKey = 'onboarded';

bool isOnboarded() {
  if (Store.read<bool>(onboardedKey) == true) return true;
  // Existing installs from before onboarding existed.
  if (Store.read(lastSyncKey) != null || Store.read(bodyGoalKey) != null) {
    Store.write(onboardedKey, true);
    return true;
  }
  return false;
}

Future<void> markOnboarded() => Store.write(onboardedKey, true);

/// First-run flow: welcome → ERP login → BMI goal → floating assistant.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  final id = TextEditingController();
  final pw = TextEditingController();
  BodyGoal? goal;
  String? erpError;
  bool busy = false;
  bool bubbleOn = false;

  @override
  void dispose() {
    id.dispose();
    pw.dispose();
    super.dispose();
  }

  Future<void> _connectErp() async {
    final i = id.text.trim(), p = pw.text;
    if (i.isEmpty || p.isEmpty) {
      setState(() => erpError = 'Enter both ID and password.');
      return;
    }
    setState(() { busy = true; erpError = null; });
    try {
      await Credentials.connect(i, p);
      syncFromErp().ignore();
      if (mounted) setState(() { busy = false; step = 2; });
    } catch (e) {
      if (mounted) setState(() { busy = false; erpError = '$e'; });
    }
  }

  Future<void> _saveGoal() async {
    if (goal == null) return;
    await saveGoal(goal!);
    await logWeight(goal!.startKg);
    setState(() => step = 3);
  }

  Future<void> _finish({bool skipBubble = false}) async {
    if (!skipBubble && bubbleOn) {
      const ch = MethodChannel('focus/app');
      final ok = await ch.invokeMethod<bool>('setBubble', {'on': true}) ?? false;
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allow “Display over other apps” for Focus, then try again.')),
        );
        return;
      }
    }
    await markOnboarded();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.6),
                  radius: 1.2,
                  colors: [Dissolve.glow, Dissolve.bg],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: Motion.base,
                            curve: Motion.curve,
                            height: 3,
                            margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: i <= step ? Dissolve.accent : Dissolve.track,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.base,
                      switchInCurve: Motion.curve,
                      child: KeyedSubtree(key: ValueKey(step), child: _page()),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page() => switch (step) {
    0 => _welcome(),
    1 => _erp(),
    2 => _goal(),
    _ => _bubble(),
  };

  Widget _welcome() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Center(child: ThinkingOrb(size: 120, dots: 160, dotSize: 2)),
      const SizedBox(height: 28),
      Text('Welcome to Focus', style: Typo.title),
      const SizedBox(height: 10),
      Text(
        'Attendance from your college ERP, GATE prep, gym and diet, a focus timer, scroll control, and an assistant that can talk back.',
        style: Typo.body.copyWith(color: Dissolve.muted, height: 1.45),
      ),
      const Spacer(),
      Text('Everything stays on this phone.', style: Typo.caption),
    ],
  );

  Widget _erp() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Connect ERP', style: Typo.title),
      const SizedBox(height: 8),
      Text(
        'Your college login. Used only to pull attendance. Stored in the phone’s secure vault.',
        style: Typo.body.copyWith(color: Dissolve.muted),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: id,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(labelText: 'ERP ID / PRN'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: pw,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (_) => _connectErp(),
      ),
      if (erpError != null) ...[
        const SizedBox(height: 14),
        Text(erpError!, style: TextStyle(color: Dissolve.danger, fontSize: 13)),
      ],
      const Spacer(),
      TextButton(
        onPressed: busy ? null : () => setState(() => step = 2),
        child: const Text('Skip for now'),
      ),
    ],
  );

  Widget _goal() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Body goal', style: Typo.title),
        const SizedBox(height: 8),
        Text(
          'Set height, weight now and a target. Focus tracks BMI and suggests daily protein.',
          style: Typo.body.copyWith(color: Dissolve.muted),
        ),
        const SizedBox(height: 22),
        GoalForm(onChanged: (g) => setState(() => goal = g)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => step = 3),
          child: const Text('Skip for now'),
        ),
      ],
    ),
  );

  Widget _bubble() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Assistant anywhere', style: Typo.title),
      const SizedBox(height: 8),
      Text(
        'A floating orb over other apps. Tap it to open Focus and talk. Long-press the app icon for “Ask Focus”.',
        style: Typo.body.copyWith(color: Dissolve.muted),
      ),
      const SizedBox(height: 28),
      Panel(
        onTap: () => setState(() => bubbleOn = !bubbleOn),
        glow: bubbleOn ? Dissolve.accent : null,
        child: Row(
          children: [
            const ThinkingOrb(size: 44, dots: 90, dotSize: 2),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Floating bubble', style: Typo.heading),
                  Text(bubbleOn ? 'On — needs overlay permission' : 'Off', style: Typo.caption),
                ],
              ),
            ),
            Switch(value: bubbleOn, onChanged: (v) => setState(() => bubbleOn = v)),
          ],
        ),
      ),
      const Spacer(),
    ],
  );

  Widget _footer() {
    final label = switch (step) {
      0 => 'Get started',
      1 => busy ? 'Connecting…' : 'Connect ERP',
      2 => 'Save goal',
      _ => 'Enter Focus',
    };
    final enabled = switch (step) {
      1 => !busy,
      2 => goal != null,
      _ => true,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FilledButton(
        onPressed: !enabled
            ? null
            : () {
                HapticFeedback.selectionClick();
                switch (step) {
                  case 0:
                    setState(() => step = 1);
                  case 1:
                    _connectErp();
                  case 2:
                    _saveGoal();
                  default:
                    _finish();
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(label),
        ),
      ),
    );
  }
}
