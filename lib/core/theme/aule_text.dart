import 'package:material_ui/material_ui.dart';

import 'aule_colors.dart';

/// The two bundled families and the text roles of the live web (§5).
///
/// Both fonts are variable TTFs, so every style sets the weight twice: as a
/// `wght` axis value, which the variable font uses, and as [FontWeight], which
/// the platform font uses if the bundled one is ever missing.
abstract final class AuleText {
  static const serifFamily = 'Source Serif 4';
  static const sansFamily = 'Inter';

  /// Headings and the wordmark.
  static TextStyle serif(
    double size,
    double lineHeight,
    int weight, {
    Color color = AuleColors.ink,
  }) => _style(serifFamily, size, lineHeight, weight, color);

  /// Everything else.
  static TextStyle sans(
    double size,
    double? lineHeight,
    int weight, {
    Color color = AuleColors.ink,
  }) => _style(sansFamily, size, lineHeight, weight, color);

  /// The "Aule" wordmark in header rows.
  static final TextStyle wordmark = serif(18, 24, 600);

  /// The text typed into line fields.
  static final TextStyle field = sans(22, 30, 400);

  /// The characters in code boxes.
  static final TextStyle code = sans(24, 30, 600);

  /// The theme's text roles.
  static TextTheme textTheme() => TextTheme(
    headlineMedium: serif(28, 34, 500),
    titleLarge: serif(20, 26, 500),
    titleMedium: sans(16, 22, 600),
    bodyLarge: sans(16, 24, 400),
    bodyMedium: sans(15, 22, 400, color: AuleColors.muted),
    bodySmall: sans(14, 20, 400, color: AuleColors.muted),
    labelLarge: sans(16, 22, 600),
    labelMedium: sans(14, 20, 500, color: AuleColors.copper),
    labelSmall: sans(14, 20, 500, color: AuleColors.muted),
  );

  static TextStyle _style(
    String family,
    double size,
    double? lineHeight,
    int weight,
    Color color,
  ) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight == null ? null : lineHeight / size,
    fontWeight: _weight(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
    color: color,
    letterSpacing: 0,
  );

  static FontWeight _weight(int weight) => switch (weight) {
    <= 100 => FontWeight.w100,
    <= 200 => FontWeight.w200,
    <= 300 => FontWeight.w300,
    <= 400 => FontWeight.w400,
    <= 500 => FontWeight.w500,
    <= 600 => FontWeight.w600,
    <= 700 => FontWeight.w700,
    <= 800 => FontWeight.w800,
    _ => FontWeight.w900,
  };
}

extension AuleTextStyle on TextStyle {
  /// The same style at another weight, keeping the variable font's `wght`
  /// axis and [FontWeight] in step. Use it instead of `copyWith(fontWeight:)`.
  TextStyle withWeight(int weight) => copyWith(
    fontWeight: AuleText._weight(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
  );
}
