import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PhotoErrorReason {
  networkOffline,
  localMissing,
  corrupted,
}

class AppPhotoPlaceholder extends StatelessWidget {
  final String photoPath;
  final bool isDark;
  final bool isFullScreen;
  final PhotoErrorReason? forcedReason;

  const AppPhotoPlaceholder({
    super.key,
    required this.photoPath,
    this.isDark = true,
    this.isFullScreen = false,
    this.forcedReason,
  });

  PhotoErrorReason get _reason {
    if (forcedReason != null) return forcedReason!;
    final clean = photoPath.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return PhotoErrorReason.networkOffline;
    }
    return PhotoErrorReason.localMissing;
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason;

    final IconData icon;
    final String title;
    final String subtitle;

    switch (reason) {
      case PhotoErrorReason.networkOffline:
        icon = Icons.cloud_off_outlined;
        title = 'Photo Unavailable';
        subtitle = 'Connect to the internet to download and view this photo.';
        break;
      case PhotoErrorReason.localMissing:
        icon = Icons.no_photography_outlined;
        title = 'Photo Unavailable Locally';
        subtitle = 'Original photo is not on this device storage or was cleared.';
        break;
      case PhotoErrorReason.corrupted:
        icon = Icons.broken_image_outlined;
        title = 'Unable to Load Photo';
        subtitle = 'The image file could not be decoded.';
        break;
    }

    if (isFullScreen) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.borderLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
