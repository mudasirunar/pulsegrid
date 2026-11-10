import 'package:flutter/material.dart';

/// Semantic color palette for Pulse Grid adhering to the Light Professional
/// enterprise specification and a complementary dark field mode.
abstract class AppColors {
  // Light Professional Palette
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color primaryNavyLight = Color(0xFF172554);
  static const Color primaryBlueLight = Color(0xFF2563EB);
  static const Color secondaryBlueLight = Color(0xFFDBEAFE);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Dark Professional Palette
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color primaryNavyDark = Color(0xFF1E3A8A);
  static const Color primaryBlueDark = Color(0xFF3B82F6);
  static const Color secondaryBlueDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Semantic Severity Colors
  static const Color severityCritical = Color(0xFFDC2626);
  static const Color severityCriticalContainerLight = Color(0xFFFEE2E2);
  static const Color severityCriticalContainerDark = Color(0xFF450A0A);

  static const Color severityHigh = Color(0xFFEA580C);
  static const Color severityHighContainerLight = Color(0xFFFFEDD5);
  static const Color severityHighContainerDark = Color(0xFF431407);

  static const Color severityMedium = Color(0xFFD97706);
  static const Color severityMediumContainerLight = Color(0xFFFEF3C7);
  static const Color severityMediumContainerDark = Color(0xFF451A03);

  static const Color severityLow = Color(0xFF2563EB);
  static const Color severityLowContainerLight = Color(0xFFDBEAFE);
  static const Color severityLowContainerDark = Color(0xFF172554);

  // Incident Lifecycle Status Colors
  static const Color statusNew = Color(0xFF6366F1);
  static const Color statusAssigned = Color(0xFF2563EB);
  static const Color statusInProgress = Color(0xFFD97706);
  static const Color statusResolved = Color(0xFF16A34A);
  static const Color statusClosed = Color(0xFF64748B);

  // Sync State Colors
  static const Color syncSynced = Color(0xFF16A34A);
  static const Color syncPending = Color(0xFFD97706);
  static const Color syncSyncing = Color(0xFF2563EB);
  static const Color syncFailed = Color(0xFFDC2626);
}

