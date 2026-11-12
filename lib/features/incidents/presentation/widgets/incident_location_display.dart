import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class IncidentLocationDisplay extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final String? manualLocationNotes;

  const IncidentLocationDisplay({
    super.key,
    this.latitude,
    this.longitude,
    this.manualLocationNotes,
  });

  String _formatCoordinates(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}° $latDir, ${lng.abs().toStringAsFixed(5)}° $lngDir';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasGps = latitude != null && longitude != null;
    final hasNotes = manualLocationNotes != null && manualLocationNotes!.trim().isNotEmpty;

    if (!hasGps && !hasNotes) {
      return Text(
        'No location recorded.',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      );
    }

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasGps)
          Text(
            _formatCoordinates(latitude!, longitude!),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        if (hasGps && hasNotes) const SizedBox(height: 4),
        if (hasNotes)
          Text(
            manualLocationNotes!.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: hasGps ? secondaryTextColor : textColor,
            ),
          ),
      ],
    );
  }
}

