import 'package:flutter/material.dart';

/// Haven Design System — Color Tokens
/// Every color maps to a STATE, not aesthetics.
/// Red = danger | Amber = warning | Green = safe | Blue = system | Gray = passive
/// Rose/Plum = brand identity
abstract final class AppColors {
  // ── Brand (Rose / Plum) ───────────────────────────────────────────────────
  /// Primary brand rose — used for CTAs, highlights, active states
  static const Color rosePrimary = Color(0xFFDB2777);

  /// Deeper press/hover state
  static const Color roseDeep = Color(0xFFBE185D);

  /// Lighter accent — tagline, subtle tints, shimmer highlight
  static const Color roseLight = Color(0xFFF472B6);

  /// Very light rose tint — backgrounds in light mode
  static const Color roseTint = Color(0xFFFDF2F8);

  // ── Emergency (Red) ───────────────────────────────────────────────────────
  static const Color redPrimary = Color(0xFFD32F2F);
  static const Color redPressed = Color(0xFFB71C1C);
  static const Color redTint = Color(0xFFFFEBEE);

  // Dark mode red
  static const Color redDark = Color(0xFFEF5350);
  static const Color redDarkPressed = Color(0xFFC62828);
  static const Color redDarkBg = Color(0xFF2A0F0F);

  // ── System / Navigation (Blue) ────────────────────────────────────────────
  static const Color bluePrimary = Color(0xFF1E3A8A);
  static const Color blueLight = Color(0xFFE3F2FD);

  // Dark mode blue
  static const Color blueDark = Color(0xFF60A5FA);
  static const Color blueDarkBg = Color(0xFF0B1E3A);

  // ── Safe State (Green) ────────────────────────────────────────────────────
  static const Color greenPrimary = Color(0xFF2E7D32);
  static const Color greenLight = Color(0xFFE8F5E9);

  // Dark mode green
  static const Color greenDark = Color(0xFF4CAF50);
  static const Color greenDarkBg = Color(0xFF0E1F14);

  // ── Warning (Amber) ───────────────────────────────────────────────────────
  static const Color amberPrimary = Color(0xFFF9A825);
  static const Color amberLight = Color(0xFFFFF8E1);

  // Dark mode amber
  static const Color amberDark = Color(0xFFFBC02D);
  static const Color amberDarkBg = Color(0xFF2A220A);

  // ── Neutrals (Light) ──────────────────────────────────────────────────────
  static const Color background = Color(0xFFF9F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8D8E2);

  // ── Text (Light) ──────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A0A14);
  static const Color textSecondary = Color(0xFF5C3D4E);
  static const Color textInverse = Color(0xFFFFFFFF);

  // ── Neutrals (Dark) ───────────────────────────────────────────────────────
  /// Main splash / app background — deep plum-black
  static const Color backgroundDark = Color(0xFF100615);

  /// Slightly lighter surface for cards
  static const Color surfaceDark = Color(0xFF1A0D1E);

  /// Elevated surface — modals, sheets
  static const Color surfaceElevatedDark = Color(0xFF2A1230);

  /// Subtle divider on dark backgrounds
  static const Color dividerDark = Color(0xFF3B1F36);

  // ── Text (Dark) ───────────────────────────────────────────────────────────
  /// Warm white — slightly rose-tinted so it pairs with the brand
  static const Color textPrimaryDark = Color(0xFFFDF2F8);
  static const Color textSecondaryDark = Color(0xFFC084A0);
  static const Color textDisabledDark = Color(0xFF7C4D6A);

  // ── Icon defaults ─────────────────────────────────────────────────────────
  static const Color iconDefault = Color(0xFFF3D0E0);
  static const Color iconMuted = Color(0xFFB07090);
}