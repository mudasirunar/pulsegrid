import 'package:flutter/material.dart';

/// Semantic color palette for Pulse Grid:
/// Light: Pale Desert Sand & Deep Military Olive with Solar Gold accents
/// Dark: Gunmetal Armor & Dark Olive Slate with Solar Tactical Yellow
abstract class AppColors {
  // Light Mode (Pale Desert Sand & Deep Military Olive)
  static const Color backgroundLight = Color(0xFFF5F3EF); // Pale Desert Sand
  static const Color surfaceLight = Color(0xFFFFFFFF); // Crisp Ivory White
  static const Color primaryLight = Color(0xFF374134); // Deep Military Olive
  static const Color primaryContainerLight = Color(0xFFE8ECE7); // Muted Olive Tint
  static const Color accentLight = Color(0xFFCA8A04); // Solar Gold Accent
  static const Color borderLight = Color(0xFFE6E4DF); // Warm Sand Border
  static const Color textPrimaryLight = Color(0xFF1C1F1A); // Deep Woodland Bronze
  static const Color textSecondaryLight = Color(0xFF636A5E); // Muted Earth Sage

  // Dark Mode (Gunmetal Armor & Solar Tactical Gold)
  static const Color backgroundDark = Color(0xFF121413); // Gunmetal Armor
  static const Color surfaceDark = Color(0xFF1A1E1A); // Dark Olive Slate
  static const Color primaryDark = Color(0xFFCA8A04); // Richer/Darker Tactical Gold (#CA8A04)
  static const Color primaryContainerDark = Color(0xFF261E05); // Muted Solar Gold Glow
  static const Color accentDark = Color(0xFFCA8A04); // Richer/Darker Tactical Gold Accent
  static const Color borderDark = Color(0xFF2A302A); // Gunmetal Border
  static const Color textPrimaryDark = Color(0xFFF4F5F0); // Crisp Bone White
  static const Color textSecondaryDark = Color(0xFFA1A89E); // Muted Bone Sage

  // Semantic Severity Colors
  static const Color severityCritical = Color(0xFFEF4444);
  static const Color severityCriticalContainerLight = Color(0xFFFEE2E2);
  static const Color severityCriticalContainerDark = Color(0xFF450A0A);

  static const Color severityHigh = Color(0xFFF97316);
  static const Color severityHighContainerLight = Color(0xFFFFEDD5);
  static const Color severityHighContainerDark = Color(0xFF431407);

  static const Color severityMedium = Color(0xFFEAB308);
  static const Color severityMediumContainerLight = Color(0xFFFEF9C3);
  static const Color severityMediumContainerDark = Color(0xFF422006);

  static const Color severityLow = Color(0xFF65A30D);
  static const Color severityLowContainerLight = Color(0xFFECFCCB);
  static const Color severityLowContainerDark = Color(0xFF1A2E05);

  // Incident Lifecycle Status Colors
  static const Color statusNew = Color(0xFF38BDF8);
  static const Color statusAssigned = Color(0xFFA855F7);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusResolved = Color(0xFF22C55E);
  static const Color statusClosed = Color(0xFF71717A);

  // Sync State Colors
  static const Color syncSynced = Color(0xFF22C55E);
  static const Color syncPending = Color(0xFFF59E0B);
  static const Color syncSyncing = Color(0xFF38BDF8);
  static const Color syncFailed = Color(0xFFEF4444);
}

