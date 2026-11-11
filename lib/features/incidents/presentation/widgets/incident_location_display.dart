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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasGps = latitude != null && longitude != null;
    final hasNotes = manualLocationNotes != null && manualLocationNotes!.isNotEmpty;

    if (!hasGps && !hasNotes) {
      return Text(
        'No location coordinates recorded.',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasGps) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: AppColors.primaryLight),
                const SizedBox(width: 10),
                Text(
                  'GPS Coordinates:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatCoordinates(latitude!, longitude!),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (hasNotes) const SizedBox(height: 8),
        ],
        if (hasNotes) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_outlined, size: 18, color: AppColors.severityMedium),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Location Notes: $manualLocationNotes',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

