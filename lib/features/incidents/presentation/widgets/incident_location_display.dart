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

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final notesColor = hasGps ? secondaryTextColor : textColor;

    if (!hasGps && !hasNotes) {
      return Row(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 15,
            color: secondaryTextColor,
          ),
          const SizedBox(width: 8),
          Text(
            'No location recorded.',
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasGps)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.my_location_rounded,
                size: 15,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatCoordinates(latitude!, longitude!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        if (hasGps && hasNotes) const SizedBox(height: 6),
        if (hasNotes)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 15,
                  color: notesColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  manualLocationNotes!.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: notesColor,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

