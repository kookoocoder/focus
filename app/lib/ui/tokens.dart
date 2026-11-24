import 'package:flutter/material.dart';

/// Light, dark or follow the phone. Saved in [Store] under `theme_mode`.
enum Look { system, light, dark }

/// The `--dissolve-*` theme tokens. Values follow [Dissolve.light]; flip it
/// with [Dissolve.apply], which rebuilds every widget.
abstract final class Dissolve {
  static bool light = false;
  static Look look = Look.dark;

  static void apply(Look l, {bool rebuild = true}) {
    look = l;
    light = switch (l) {
      Look.light => true,
      Look.dark => false,
      Look.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light,
    };
    if (rebuild) WidgetsBinding.instance.reassembleApplication();
  }

  static Color _p(int dark, int lite) => Color(light ? lite : dark);

  static Color get bg => _p(0xFF07070A, 0xFFF5F5F8);
  static Color get surface => _p(0xFF111116, 0xFFFFFFFF);
  static Color get raised => _p(0xFF18181F, 0xFFEDEDF2);
  static Color get border => _p(0x14FFFFFF, 0x14000000);
  static Color get track => _p(0x1FFFFFFF, 0x1A000000);
  static Color get fg => _p(0xFFF4F4F6, 0xFF111118);
  static Color get muted => _p(0xFF8A8A96, 0xFF6B6B78);
  static Color get accent => _p(0xFFA5B4FC, 0xFF4F46E5);
  static Color get success => _p(0xFF4ADE80, 0xFF16A34A);
  static Color get warning => _p(0xFFFBBF24, 0xFFD97706);
  static Color get danger => _p(0xFFF87171, 0xFFDC2626);
  static Color get sky => _p(0xFF93C5FD, 0xFF2563EB);
  static Color get violet => _p(0xFFC4B5FD, 0xFF7C3AED);

  /// Text/icons drawn on top of a [fg] or hue fill.
  static Color get ink => _p(0xFF0B0B10, 0xFFFFFFFF);

  /// Hairline edge of glass surfaces.
  static Color get edge => _p(0x1AFFFFFF, 0x14000000);
  static Color get shadow => _p(0xAA000000, 0x22000000);

  /// Soft lift under flat capsules; only needed on the light background.
  static List<BoxShadow> get lift => light
      ? const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))]
      : const [];

  /// Tint of the corner glow behind every screen.
  static Color get glow => _p(0xFF101018, 0xFFE4E6F7);
}

/// One hue per section. Headers, rings, bars and the backdrop glow of a
/// section use its hue; green/amber/red are kept for good/warn/bad status.
abstract final class Hue {
  static Color get classes => Dissolve.sky;
  static Color get gate => Dissolve.accent;
  static Color get body => Dissolve.warning;
  static Color get focus => Dissolve.violet;
}

/// One timing scale for every animation so motion feels the same on every
/// screen: [fast] for taps and toggles, [base] for content, [slow] for
/// progress sweeps. Everything eases out with [curve].
abstract final class Motion {
  static const fast = Duration(milliseconds: 220);
  static const base = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 900);
  static const stagger = Duration(milliseconds: 45);
  static const curve = Curves.easeOutCubic;
}

/// Type scale. Use these instead of ad-hoc sizes so every screen has the same
/// hierarchy: display > title > heading > body > caption/label.
abstract final class Typo {
  static const display = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w600,
    letterSpacing: -2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static TextStyle get title => TextStyle(
    color: Dissolve.fg,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    height: 1.05,
  );
  static const metric = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static TextStyle get heading => TextStyle(
    color: Dissolve.fg,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -.3,
    height: 1.25,
  );
  static TextStyle get body => TextStyle(color: Dissolve.fg, fontSize: 15, height: 1.35);
  static TextStyle get caption => TextStyle(color: Dissolve.muted, fontSize: 13, height: 1.35);
  static TextStyle get label => TextStyle(
    color: Dissolve.muted,
    fontSize: 11.5,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w700,
  );
}
