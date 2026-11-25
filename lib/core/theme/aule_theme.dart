import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'aule_colors.dart';
import 'aule_text.dart';

/// Dark status bar icons on paper, as on the web. Light mode only in v0.
const SystemUiOverlayStyle auleSystemUi = SystemUiOverlayStyle(
  statusBarColor: AuleColors.paper,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AuleColors.paper,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// The app's only theme, built from the live web tokens (§5). The shared
/// widgets in `core/widgets` draw the buttons, fields, checkboxes and cards
/// themselves; this theme covers what Material draws on its own.
ThemeData auleTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AuleColors.ink,
    onPrimary: AuleColors.surface,
    secondary: AuleColors.copper,
    onSecondary: AuleColors.surface,
    tertiary: AuleColors.copper,
    onTertiary: AuleColors.surface,
    error: AuleColors.danger,
    onError: AuleColors.surface,
    surface: AuleColors.surface,
    onSurface: AuleColors.ink,
    onSurfaceVariant: AuleColors.muted,
    surfaceContainerLowest: AuleColors.surface,
    surfaceContainerLow: AuleColors.paper,
    surfaceContainer: AuleColors.paper,
    surfaceContainerHigh: AuleColors.picked,
    surfaceContainerHighest: AuleColors.picked,
    outline: AuleColors.ink,
    outlineVariant: AuleColors.line,
    inverseSurface: AuleColors.ink,
    onInverseSurface: AuleColors.surface,
    shadow: Color(0x00000000),
    scrim: Color(0x66141414),
    surfaceTint: Color(0x00000000),
  );
  final text = AuleText.textTheme();
  final small = text.bodySmall!;
  final radius = BorderRadius.circular(auleRadius);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AuleColors.paper,
    canvasColor: AuleColors.paper,
    fontFamily: AuleText.sansFamily,
    textTheme: text,
    primaryTextTheme: text,
    splashFactory: InkRipple.splashFactory,
    focusColor: AuleColors.copper.withValues(alpha: 0.12),
    hoverColor: AuleColors.ink.withValues(alpha: 0.04),
    highlightColor: AuleColors.ink.withValues(alpha: 0.06),
    splashColor: AuleColors.ink.withValues(alpha: 0.08),
    dividerTheme: const DividerThemeData(
      color: AuleColors.line,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: AuleColors.ink, size: 24),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AuleColors.ink,
      circularTrackColor: Color(0x00000000),
      refreshBackgroundColor: AuleColors.surface,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AuleColors.ink,
      selectionColor: AuleColors.copper.withValues(alpha: 0.25),
      selectionHandleColor: AuleColors.copper,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AuleColors.ink,
      contentTextStyle: text.bodyLarge!.copyWith(color: AuleColors.surface),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AuleColors.paper,
      modalBackgroundColor: AuleColors.paper,
      surfaceTintColor: const Color(0x00000000),
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(auleRadius)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AuleColors.paper,
      surfaceTintColor: const Color(0x00000000),
      shadowColor: const Color(0x00000000),
      elevation: 0,
      indicatorColor: AuleColors.picked,
      indicatorShape: RoundedRectangleBorder(borderRadius: radius),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? small.withWeight(600).copyWith(color: AuleColors.ink)
            : small.withWeight(500).copyWith(color: AuleColors.ink),
      ),
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: AuleColors.ink, size: 24),
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: AuleColors.copper,
      textColor: AuleColors.surface,
      textStyle: small.withWeight(600).copyWith(fontSize: 11, height: 1),
    ),
    // On or off must be clear at a glance (WCAG 1.4.11, 3:1): on is an ink
    // track with a surface thumb; off is a surface track with a 2 px muted
    // outline and a muted thumb (4.8:1 on paper). Disabled uses the line.
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return states.contains(WidgetState.selected)
              ? AuleColors.line
              : AuleColors.paper;
        }
        return states.contains(WidgetState.selected)
            ? AuleColors.ink
            : AuleColors.surface;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AuleColors.surface;
        return states.contains(WidgetState.disabled)
            ? AuleColors.line
            : AuleColors.muted;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0x00000000);
        }
        return states.contains(WidgetState.disabled)
            ? AuleColors.line
            : AuleColors.muted;
      }),
      trackOutlineWidth: const WidgetStatePropertyAll<double>(2),
      overlayColor: WidgetStatePropertyAll(
        AuleColors.copper.withValues(alpha: 0.12),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AuleColors.ink, borderRadius: radius),
      textStyle: small.copyWith(color: AuleColors.surface),
    ),
  );
}
