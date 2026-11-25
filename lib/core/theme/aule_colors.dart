import 'package:material_ui/material_ui.dart';

abstract final class AuleColors {
  static const paper = Color(0xFFF5F2EA); // --bg, the page
  static const surface = Color(0xFFFBFAF6); // --surface, cards and button text
  static const ink = Color(0xFF141414); // --ink, text, borders, primary buttons
  static const muted = Color(0xFF6B6B6B); // --muted, help text and labels
  static const line = Color(0xFFC9C3B4); // --line, dividers and disabled
  static const copper = Color(0xFF9A5B2E); // --copper, accent, steps, focus
  static const picked = Color(0xFFEBE4D3); // --picked, a selected option
  static const danger = Color(0xFF8F1D14); // --danger, errors and deletion
}

abstract final class AuleSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

const double auleRadius = 10;
