import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/effects.dart';
import '../../ui/thinking_orb.dart';
import '../../ui/tokens.dart';
import 'llm.dart';

const _suggestions = [
  'I ate 2 eggs',
  'Move gym alarm to 6:30',
  'How many classes can I skip?',
  "What's my protein today?",
  'Remind me to study at 9pm',
];

/// Chat UI. Pops with `true` if the assistant changed any app data.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _c = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _history = <Map<String, dynamic>>[];
  final _shown = <(bool, String)>[];
  String? _status;
  OrbState _orb = OrbState.idle;
  bool _changed = false;
  bool _clearing = false;
  bool _hasText = false;
  bool _keyOpen = false;
  final _keyC = TextEditingController();

  @override
  void initState() {
    super.initState();
    AssistantKey.load().then((_) {
      if (mounted) setState(() => _keyOpen = !assistantConfigured);
    });
    _c.addListener(() {
      final has = _c.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _keyC.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  });

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _c.text).trim();
    if (text.isEmpty || _status != null) return;
    _c.clear();
    _shown.add((true, text));
    _history.add({'role': 'user', 'content': text});
    setState(() {
      _status = 'Thinking';
      _orb = OrbState.thinking;
    });
    _toBottom();
    var failed = false;
    try {
      final (reply, changed) = await askAssistant(_history, (s) {
        if (!mounted) return;
        setState(() {
          _status = s.replaceAll('…', '').replaceAll('_', ' ');
          _orb = OrbState.searching;
        });
      });
      _changed |= changed;
      _shown.add((false, reply));
    } catch (e) {
      failed = true;
      _shown.add((false, 'Error: $e'));
    }
    if (!mounted) return;
    setState(() {
      _status = null;
      _orb = failed ? OrbState.error : OrbState.done;
    });
    _toBottom();
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted && _status == null) setState(() => _orb = OrbState.idle);
  }

  void _clear() {
    if (_shown.isEmpty || _status != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _clearing = true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.pop(context, _changed);
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: Dissolve.bg,
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Dissolve.accent,
            selectionColor: Color(0x55A5B4FC),
          ),
        ),
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: _Backdrop()),
              SafeArea(
                child: Column(
                  children: [
                    _header(),
                    if (_keyOpen) _keyPanel(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _shown.isEmpty ? _empty() : _thread(),
                      ),
                    ),
                    _composer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    child: Row(
      children: [
        _IconPill(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context, _changed),
        ),
        const SizedBox(width: 12),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _shown.isEmpty ? 0 : 1,
          child: ThinkingOrb(state: _orb, size: 30, dots: 90, dotSize: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextScramble(
                'Focus Assistant',
                style: TextStyle(
                  color: Dissolve.fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.2,
                ),
              ),
              TextScramble(
                switch (_orb) {
                  OrbState.thinking => 'thinking',
                  OrbState.searching => 'using tools',
                  OrbState.done => 'done',
                  OrbState.error => 'something went wrong',
                  _ => 'online',
                },
                speed: 18,
                style: TextStyle(
                  color: switch (_orb) {
                    OrbState.done => Dissolve.success,
                    OrbState.error => Dissolve.danger,
                    _ => Dissolve.muted,
                  },
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        _IconPill(
          icon: assistantConfigured ? Icons.key_rounded : Icons.key_off_rounded,
          onTap: () => setState(() => _keyOpen = !_keyOpen),
        ),
        const SizedBox(width: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _shown.isEmpty ? 0 : 1,
          child: _IconPill(icon: Icons.blur_on_rounded, onTap: _clear),
        ),
      ],
    ),
  );

  Future<void> _saveKey() async {
    final k = _keyC.text.trim();
    if (k.isEmpty) return;
    await AssistantKey.save(k);
    _keyC.clear();
    if (mounted) setState(() => _keyOpen = false);
  }

  Future<void> _clearKey() async {
    await AssistantKey.clear();
    if (mounted) setState(() {});
  }

  Widget _keyPanel() {
    final ok = assistantConfigured;
    final tone = ok ? Dissolve.muted : Dissolve.danger;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
      decoration: BoxDecoration(
        color: Dissolve.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ok ? Dissolve.border : Dissolve.danger.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !ok
                ? 'Enter your DeepSeek API key to use the assistant.'
                : AssistantKey.custom
                ? 'Using your key ${AssistantKey.masked}'
                : 'Using the built-in key ${AssistantKey.masked}',
            style: TextStyle(color: tone, fontSize: 13),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyC,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _saveKey(),
                  style: TextStyle(color: Dissolve.fg, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'sk-…',
                    hintStyle: TextStyle(color: Dissolve.muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (AssistantKey.custom)
                TextButton(onPressed: _clearKey, child: const Text('Remove')),
              TextButton(onPressed: _saveKey, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() => LayoutBuilder(
    key: const ValueKey('empty'),
    builder: (_, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ThinkingOrb(
              state: _orb,
              size: 190,
              dots: 260,
              dotSize: 2.2,
              interactive: true,
            ),
            const SizedBox(height: 36),
            TextScramble(
              'How can I help?',
              speed: 40,
              style: TextStyle(
                color: Dissolve.fg,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I can read and change anything in the app.',
              style: TextStyle(color: Dissolve.muted, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 40,
              child: Marquee(
                children: [
                  for (final s in _suggestions)
                    _Chip(label: s, onTap: () => _send(s)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _thread() {
    Widget list = ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _shown.length + (_status != null ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _shown.length) {
          return _ThinkingRow(key: const ValueKey('status'), status: _status!, orb: _orb);
        }
        final (me, t) = _shown[i];
        return Grains(
          key: ValueKey(i),
          color: me ? Dissolve.accent : Dissolve.fg,
          child: me ? _UserBubble(t) : _AssistantMessage(t),
        );
      },
    );
    if (_clearing) {
      list = Grains(
        reverse: true,
        duration: const Duration(milliseconds: 900),
        onDone: () => setState(() {
          _shown.clear();
          _history.clear();
          _clearing = false;
          _orb = OrbState.idle;
        }),
        child: list,
      );
    }
    return KeyedSubtree(key: const ValueKey('thread'), child: list);
  }

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 4, 5, 4),
      decoration: BoxDecoration(
        color: Dissolve.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Dissolve.border),
        boxShadow: [
          BoxShadow(color: Dissolve.shadow, blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextField(
                controller: _c,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: TextStyle(color: Dissolve.fg, fontSize: 15.5, height: 1.35),
                decoration: InputDecoration(
                  hintText: 'Ask or tell me anything…',
                  hintStyle: TextStyle(color: Dissolve.muted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: GlossyButton(
              enabled: _hasText && _status == null,
              onPressed: _send,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: _status != null
                    ? SizedBox.square(
                        key: const ValueKey('busy'),
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: GlossyButton.ink,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, key: ValueKey('send')),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -.55),
        radius: 1.1,
        colors: [Dissolve.glow, Dissolve.bg],
        stops: [0, .7],
      ),
    ),
  );
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Dissolve.surface,
    shape: CircleBorder(side: BorderSide(color: Dissolve.border)),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 40,
        child: Icon(icon, size: 17, color: Dissolve.fg),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Material(
      color: Dissolve.surface,
      shape: StadiumBorder(side: BorderSide(color: Dissolve.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(color: Dissolve.fg, fontSize: 13.5),
          ),
        ),
      ),
    ),
  );
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(top: 14, bottom: 4, left: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Dissolve.accent.withValues(alpha: .18), Dissolve.accent.withValues(alpha: .10)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(6),
        ),
        border: Border.all(color: const Color(0x1FA5B4FC)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(color: Dissolve.fg, fontSize: 15, height: 1.4),
      ),
    ),
  );
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final error = text.startsWith('Error:');
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-.3, -.4),
                colors: error
                    ? [const Color(0xFFFCA5A5), const Color(0xFF7F1D1D)]
                    : Dissolve.light
                    ? [Color.lerp(Dissolve.accent, Colors.white, .55)!, Dissolve.accent]
                    : [Colors.white, const Color(0xFF4B4E6E)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  text,
                  style: TextStyle(
                    color: error ? Dissolve.danger : Dissolve.fg.withValues(alpha: .92),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(-6, 0),
                  child: CopyButton(text: text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow({super.key, required this.status, required this.orb});
  final String status;
  final OrbState orb;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Row(
      children: [
        ThinkingOrb(state: orb, size: 40, dots: 110, dotSize: 2),
        const SizedBox(width: 12),
        Flexible(
          child: TextScramble(
            status,
            style: TextStyle(
              color: Dissolve.muted,
              fontSize: 13.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        TypingDots(),
      ],
    ),
  );
}
