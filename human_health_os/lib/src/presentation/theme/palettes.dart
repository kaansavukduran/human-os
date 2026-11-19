/// Named palettes (U031) from the owner's YKSmania app: Matrix and Axolotl
/// (dark) and Trans (light). Each is a fixed set of tokens, in a normal and a
/// high-contrast version, mapped by buildHumanOsTheme onto the same
/// ColorScheme roles the standard theme uses. Value text stays onSurface
/// (ink); the accent (primary) is for actions and focus only; no colour
/// judges a health value.
library;

import 'package:flutter/material.dart';

import '../../domain/settings/appearance.dart';

@immutable
class PaletteTokens {
  const PaletteTokens({
    required this.brightness,
    required this.surface,
    required this.card,
    required this.containerHigh,
    required this.ink,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.fieldEdge,
    required this.hairline,
    this.error,
  });

  final Brightness brightness;

  /// Page background (ColorScheme.surface).
  final Color surface;

  /// Cards, sheets and fields (surfaceContainer).
  final Color card;

  /// Raised parts (surfaceContainerHigh).
  final Color containerHigh;

  /// Text, values included (onSurface).
  final Color ink;

  /// Muted text (outline), at least 4.5:1 on surface and card.
  final Color outline;

  /// Accent for actions and focus.
  final Color primary;
  final Color onPrimary;

  /// Input borders, at least 3:1 against the card.
  final Color fieldEdge;

  /// Card outlines and dividers (outlineVariant).
  final Color hairline;

  /// Error colour; null keeps the seeded one (Standard).
  final Color? error;

  bool get dark => brightness == Brightness.dark;

  PaletteTokens _strong({
    required Color ink,
    required Color outline,
    required Color hairline,
  }) => PaletteTokens(
    brightness: brightness,
    surface: surface,
    card: card,
    containerHigh: containerHigh,
    ink: ink,
    outline: outline,
    primary: primary,
    onPrimary: onPrimary,
    fieldEdge: fieldEdge,
    hairline: hairline,
    error: error,
  );
}

const _matrix = PaletteTokens(
  brightness: Brightness.dark,
  surface: Color(0xFF080D0B),
  card: Color(0xFF101A15),
  containerHigh: Color(0xFF19271F),
  ink: Color(0xFFE5EFE7),
  outline: Color(0xFFA7BAAC),
  primary: Color(0xFF88E8A2),
  onPrimary: Color(0xFF0B2011),
  fieldEdge: Color(0xFF64816D),
  hairline: Color(0xFF2A3B30),
  error: Color(0xFFFFAAA8),
);

const _axolotl = PaletteTokens(
  brightness: Brightness.dark,
  surface: Color(0xFF1B1219),
  card: Color(0xFF251922),
  containerHigh: Color(0xFF31202D),
  ink: Color(0xFFFBEEF5),
  outline: Color(0xFFD6B8C9),
  primary: Color(0xFFFF9FD0),
  onPrimary: Color(0xFF2B0D1E),
  fieldEdge: Color(0xFF94688A),
  hairline: Color(0xFF4A3044),
  error: Color(0xFFFFB3A8),
);

const _trans = PaletteTokens(
  brightness: Brightness.light,
  surface: Color(0xFFFDF6F9),
  card: Color(0xFFFFFFFF),
  containerHigh: Color(0xFFEAF7FE),
  ink: Color(0xFF1F2633),
  outline: Color(0xFF4D5869),
  primary: Color(0xFFB8245A),
  onPrimary: Color(0xFFFFFFFF),
  fieldEdge: Color(0xFF7D8EA0),
  hairline: Color(0xFFB7DCEE),
  error: Color(0xFFA82E35),
);

/// Normal and high-contrast tokens of every named palette.
final Map<PaletteChoice, (PaletteTokens, PaletteTokens)> paletteTokens = {
  PaletteChoice.matrix: (
    _matrix,
    _matrix._strong(
      ink: const Color(0xFFFFFFFF),
      outline: const Color(0xFFD3E3D7),
      hairline: const Color(0xFFB9D4C0),
    ),
  ),
  PaletteChoice.axolotl: (
    _axolotl,
    _axolotl._strong(
      ink: const Color(0xFFFFFFFF),
      outline: const Color(0xFFECD8E3),
      hairline: const Color(0xFFD9B3CC),
    ),
  ),
  PaletteChoice.trans: (
    _trans,
    _trans._strong(
      ink: const Color(0xFF000000),
      outline: const Color(0xFF2C3440),
      hairline: const Color(0xFF3E4F5E),
    ),
  ),
};

/// The tokens of [palette]; null for Standard (the accent-and-theme look).
PaletteTokens? tokensFor(PaletteChoice palette, {bool highContrast = false}) {
  final pair = paletteTokens[palette];
  if (pair == null) return null;
  return highContrast ? pair.$2 : pair.$1;
}

/// The brightness a named palette forces; null for Standard.
Brightness? paletteBrightness(PaletteChoice palette) =>
    paletteTokens[palette]?.$1.brightness;
