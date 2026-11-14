import 'package:flutter/material.dart';

/// Design tokens for AutoSense.
///
/// Brand: deep graphite surfaces with an "electric signal" blue accent —
/// automotive, calm and trustworthy. Urgency colours follow traffic-light
/// semantics so a driver can read the report at a glance.
abstract final class AppColors {
  // Brand
  static const brand = Color(0xFF2F5BFF);
  static const brandDark = Color(0xFF7C98FF);
  static const accent = Color(0xFF00C2A8);

  // Neutrals (light)
  static const ink = Color(0xFF0E1420);
  static const inkMuted = Color(0xFF5B6475);
  static const surfaceLight = Color(0xFFF6F7FB);
  static const cardLight = Color(0xFFFFFFFF);
  static const outlineLight = Color(0xFFE3E6EE);

  // Neutrals (dark)
  static const surfaceDark = Color(0xFF0A0E16);
  static const cardDark = Color(0xFF131925);
  static const outlineDark = Color(0xFF242C3B);
  static const textDark = Color(0xFFE8ECF4);
  static const textMutedDark = Color(0xFF98A2B5);

  // Urgency U0–U3
  static const u0 = Color(0xFF64748B); // info
  static const u1 = Color(0xFF16A34A); // next service
  static const u2 = Color(0xFFF59E0B); // within days
  static const u3 = Color(0xFFE5383B); // stop driving

  // Telltale colours (ISO 2575)
  static const telltaleRed = Color(0xFFE5383B);
  static const telltaleAmber = Color(0xFFF59E0B);
  static const telltaleGreen = Color(0xFF16A34A);
  static const telltaleBlue = Color(0xFF2563EB);
}
