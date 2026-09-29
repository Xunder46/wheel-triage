import 'package:flutter/material.dart';

/// D-4's token table — the one place any colour value is written down.
///
/// Nothing outside this file may name a colour (`grep -rn "Colors\.\|Color(0x"
/// lib/ --include='*.dart' | grep -v "lib/core/theme/"` must stay empty), and
/// every theme surface derives from these fields rather than from a framework
/// default that happens to look right in one theme.
///
/// Values are the design reference's, verbatim:
/// `docs/design/pro-ui-reference.html` (`--a-*` in the dark block, `.app-light`
/// for the light block). The dark set is the primary one (D-3), so a device in
/// dark mode sees the reference's palette.
/// The two muted values, hoisted out of [AppTokens] so a `const` expression
/// (the bucket extension's "No data" ink) can name them — Dart does not allow
/// reading an instance field of a `const` object in a `const` context.
const Color _darkMuted = Color(0xFF9CAFAF);
const Color _lightMuted = Color(0xFF526464);
const Color _darkPillEdge = Color(0x00000000);
const Color _lightPillEdge = Color(0x29192424);

@immutable
class AppTokens {
  const AppTokens({
    required this.background,
    required this.surface,
    required this.raised,
    required this.outline,
    required this.divider,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.caution,
    required this.cautionContainer,
    required this.onCautionContainer,
    required this.error,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.pillEdge,
  });

  /// Screen ground — `Scaffold` and `AppBar`.
  final Color background;

  /// Card surface — cards, sheets, the nav bar.
  final Color surface;

  /// Raised surface — carried fields, tracks, dialogs.
  final Color raised;

  /// Non-text borders.
  final Color outline;

  /// Hairline separators.
  final Color divider;

  /// Body text.
  final Color text;

  /// Secondary text.
  final Color muted;

  /// Accent (teal).
  final Color accent;

  /// Text/icons on [accent].
  final Color onAccent;

  /// Soft accent tint behind accent-coloured content.
  final Color accentContainer;

  /// Text/icons on [accentContainer].
  final Color onAccentContainer;

  /// Soft warn — debit rolls, the roll planner's informational notes.
  final Color caution;

  /// Tint behind caution content.
  final Color cautionContainer;

  /// Text/icons on [cautionContainer].
  final Color onCautionContainer;

  /// Hard reject — validation failures.
  final Color error;

  /// Tint behind error content (the screener's failed gate chip).
  final Color errorContainer;

  /// Text/icons on [errorContainer].
  final Color onErrorContainer;

  /// OC-10: the light theme's hairline pill edge. Transparent in the dark
  /// theme, which does not need one.
  final Color pillEdge;

  /// The design's primary palette (D-3).
  ///
  /// The `*Container` / `on*Container` pairs are **derived** (A-4): D-4's table
  /// names no container value, and M3's framework defaults would otherwise
  /// pick their own. Each container is `Color.lerp(surface, fill, 0.18)` and
  /// each ink is the same hue darkened until it clears 4.5:1 on that
  /// container — guarded by `test/core/theme/app_theme_contrast_test.dart`.
  static const dark = AppTokens(
    background: Color(0xFF101717),
    surface: Color(0xFF171F1F),
    raised: Color(0xFF1F2A2A),
    outline: Color(0xFF404E4E),
    divider: Color(0xFF243030),
    text: Color(0xFFE1EAE9),
    muted: _darkMuted,
    accent: Color(0xFF60D3C6),
    onAccent: Color(0xFF082D29),
    accentContainer: Color(0xFF1C3F3B),
    onAccentContainer: Color(0xFF60D3C6),
    caution: Color(0xFFFAA96A),
    cautionContainer: Color(0xFF40382C),
    onCautionContainer: Color(0xFFFAA96A),
    error: Color(0xFFF98C8B),
    errorContainer: Color(0xFF403332),
    onErrorContainer: Color(0xFFF98C8B),
    pillEdge: _darkPillEdge,
  );

  static const light = AppTokens(
    background: Color(0xFFF2F6F6),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFE4EDED),
    outline: Color(0xFFA3B4B4),
    divider: Color(0xFFDCE5E5),
    text: Color(0xFF192424),
    muted: _lightMuted,
    accent: Color(0xFF007C76),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFC3EAE4),
    onAccentContainer: Color(0xFF00665F),
    caution: Color(0xFFB0561D),
    cautionContainer: Color(0xFFF1E1D6),
    onCautionContainer: Color(0xFF8F4314),
    error: Color(0xFFBF3B3F),
    errorContainer: Color(0xFFF3DCDC),
    onErrorContainer: Color(0xFF9E2A2E),
    pillEdge: _lightPillEdge,
  );
}

/// D-4's bucket fills — **one set for both themes**, stepped in lightness
/// (L* 88 / 75 / 61 / 45) so the badges still separate in greyscale.
///
/// Assign has its own fill and deliberately does **not** borrow the error role:
/// assignment is part of the strategy, not a failure. "No data" has no fill at
/// all (Feature Invariant 19) — see [BucketColors].
abstract final class BucketPalette {
  static const close = Color(0xFFA5EDB7);
  static const roll = Color(0xFFE8AF51);
  static const assign = Color(0xFF7D8FDD);
  static const leave = Color(0xFF5A6E72);

  /// Ink for Close / Roll / Assign (11.4:1, 7.9:1, 5.1:1).
  static const ink = Color(0xFF192626);

  /// Ink for Leave (5.0:1) — the only fill dark enough to need light ink.
  static const inkOnLeave = Color(0xFFF4F7F7);
}

/// The five bucket treatments, as a `ThemeExtension` so they travel with the
/// active theme instead of being a global (D-4).
///
/// [BucketBadge] is the only reader today. The label/reason contract lives in
/// the widget, not here: this extension carries colour only.
@immutable
class BucketColors extends ThemeExtension<BucketColors> {
  const BucketColors({
    required this.closeFill,
    required this.closeInk,
    required this.rollFill,
    required this.rollInk,
    required this.assignFill,
    required this.assignInk,
    required this.leaveFill,
    required this.leaveInk,
    required this.noDataInk,
    required this.noDataOutline,
    required this.pillEdge,
  });

  final Color closeFill;
  final Color closeInk;
  final Color rollFill;
  final Color rollInk;
  final Color assignFill;
  final Color assignInk;
  final Color leaveFill;
  final Color leaveInk;

  /// "No data" has no fill — only muted text and a dashed outline.
  final Color noDataInk;
  final Color noDataOutline;

  /// The light theme's hairline pill edge (OC-10); transparent in dark.
  final Color pillEdge;

  /// Reads the active theme's bucket treatment.
  ///
  /// Falls back to the light set when no [BucketColors] extension is installed
  /// — a widget rendered outside the app's own themes (a bare `MaterialApp` in
  /// a test, say) still gets the designed bucket colours rather than a crash.
  /// The fallback comes from the same token source, so it is not a second
  /// palette.
  static BucketColors of(BuildContext context) =>
      Theme.of(context).extension<BucketColors>() ?? AppTheme.lightBucketColors;

  @override
  BucketColors copyWith({
    Color? closeFill,
    Color? closeInk,
    Color? rollFill,
    Color? rollInk,
    Color? assignFill,
    Color? assignInk,
    Color? leaveFill,
    Color? leaveInk,
    Color? noDataInk,
    Color? noDataOutline,
    Color? pillEdge,
  }) => BucketColors(
    closeFill: closeFill ?? this.closeFill,
    closeInk: closeInk ?? this.closeInk,
    rollFill: rollFill ?? this.rollFill,
    rollInk: rollInk ?? this.rollInk,
    assignFill: assignFill ?? this.assignFill,
    assignInk: assignInk ?? this.assignInk,
    leaveFill: leaveFill ?? this.leaveFill,
    leaveInk: leaveInk ?? this.leaveInk,
    noDataInk: noDataInk ?? this.noDataInk,
    noDataOutline: noDataOutline ?? this.noDataOutline,
    pillEdge: pillEdge ?? this.pillEdge,
  );

  @override
  BucketColors lerp(covariant BucketColors? other, double t) {
    if (other == null) return this;
    return BucketColors(
      closeFill: Color.lerp(closeFill, other.closeFill, t)!,
      closeInk: Color.lerp(closeInk, other.closeInk, t)!,
      rollFill: Color.lerp(rollFill, other.rollFill, t)!,
      rollInk: Color.lerp(rollInk, other.rollInk, t)!,
      assignFill: Color.lerp(assignFill, other.assignFill, t)!,
      assignInk: Color.lerp(assignInk, other.assignInk, t)!,
      leaveFill: Color.lerp(leaveFill, other.leaveFill, t)!,
      leaveInk: Color.lerp(leaveInk, other.leaveInk, t)!,
      noDataInk: Color.lerp(noDataInk, other.noDataInk, t)!,
      noDataOutline: Color.lerp(noDataOutline, other.noDataOutline, t)!,
      pillEdge: Color.lerp(pillEdge, other.pillEdge, t)!,
    );
  }
}

/// The app's two themes, built from [AppTokens] and nothing else.
///
/// The bucket fills are theme-independent (D-4), so the two [BucketColors]
/// instances differ only in [BucketColors.pillEdge]; they are kept separate
/// anyway so a future per-theme tweak has an obvious home.
abstract final class AppTheme {
  static const BucketColors darkBucketColors = BucketColors(
    closeFill: BucketPalette.close,
    closeInk: BucketPalette.ink,
    rollFill: BucketPalette.roll,
    rollInk: BucketPalette.ink,
    assignFill: BucketPalette.assign,
    assignInk: BucketPalette.ink,
    leaveFill: BucketPalette.leave,
    leaveInk: BucketPalette.inkOnLeave,
    noDataInk: _darkMuted,
    noDataOutline: _darkMuted,
    pillEdge: _darkPillEdge,
  );

  static const BucketColors lightBucketColors = BucketColors(
    closeFill: BucketPalette.close,
    closeInk: BucketPalette.ink,
    rollFill: BucketPalette.roll,
    rollInk: BucketPalette.ink,
    assignFill: BucketPalette.assign,
    assignInk: BucketPalette.ink,
    leaveFill: BucketPalette.leave,
    leaveInk: BucketPalette.inkOnLeave,
    noDataInk: _lightMuted,
    noDataOutline: _lightMuted,
    pillEdge: _lightPillEdge,
  );

  static const Color _transparent = Color(0x00000000);

  /// The light theme, and the app's `theme:`.
  static final ThemeData light = _build(AppTokens.light, Brightness.light, lightBucketColors);

  /// The dark theme — the design's primary palette (D-3), and the app's
  /// `darkTheme:`.
  static final ThemeData dark = _build(AppTokens.dark, Brightness.dark, darkBucketColors);

  static ThemeData _build(AppTokens t, Brightness brightness, BucketColors buckets) {
    // Seeded so every role the app does *not* name still comes out of a
    // coherent palette; the roles the app does read are then overwritten with
    // the exact token, so no screen sees a framework default where the design
    // specifies a value.
    final scheme = ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: brightness,
    ).copyWith(
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: t.accentContainer,
      onPrimaryContainer: t.onAccentContainer,
      secondary: t.muted,
      onSecondary: t.background,
      secondaryContainer: t.raised,
      onSecondaryContainer: t.text,
      tertiary: t.caution,
      onTertiary: t.background,
      tertiaryContainer: t.cautionContainer,
      onTertiaryContainer: t.onCautionContainer,
      error: t.error,
      onError: t.background,
      errorContainer: t.errorContainer,
      onErrorContainer: t.onErrorContainer,
      surface: t.surface,
      onSurface: t.text,
      surfaceContainerLowest: t.background,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.raised,
      surfaceContainerHighest: t.raised,
      onSurfaceVariant: t.muted,
      outline: t.outline,
      outlineVariant: t.divider,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      dividerColor: t.divider,
      dividerTheme: DividerThemeData(color: t.divider, thickness: 1, space: 32),
      // The screen's own title bar sits on the screen ground, not on a
      // separate chrome surface, and does not tint when content scrolls
      // under it.
      appBarTheme: AppBarThemeData(
        backgroundColor: t.background,
        foregroundColor: t.text,
        surfaceTintColor: _transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: _transparent,
        shadowColor: _transparent,
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.raised, surfaceTintColor: _transparent),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: _transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.raised,
        contentTextStyle: TextStyle(color: t.text),
      ),
      // A FAB on `primaryContainer` would be `onPrimaryContainer`-on-
      // `accentContainer`, which is 3.9:1 in the light theme — below the bar.
      // The accent pair clears it in both (A-4).
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
      ),
      extensions: [buckets],
    );
  }
}

/// The app's light theme (D-3/D-4). Wired into `MaterialApp.router` as
/// `theme:`.
final ThemeData lightTheme = AppTheme.light;

/// The app's dark theme — the design's primary palette (D-3/D-4). Wired into
/// `MaterialApp.router` as `darkTheme:`.
final ThemeData darkTheme = AppTheme.dark;
