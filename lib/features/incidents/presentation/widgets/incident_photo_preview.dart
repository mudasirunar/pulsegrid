import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/photo_file_resolver.dart';
import '../../../../core/widgets/app_image_viewer.dart';
import '../../../../core/widgets/app_photo_placeholder.dart';

class IncidentPhotoPreview extends StatefulWidget {
  final List<String> photoPaths;

  IncidentPhotoPreview({
    super.key,
    List<String>? photoPaths,
    String? photoPath,
  }) : photoPaths = photoPaths ?? (photoPath != null ? [photoPath] : const []);

  @override
  State<IncidentPhotoPreview> createState() => _IncidentPhotoPreviewState();
}

class _IncidentPhotoPreviewState extends State<IncidentPhotoPreview> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openImageViewer(int index) {
    AppImageViewer.show(
      context,
      photoPaths: widget.photoPaths,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photos = widget.photoPaths;

    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }

    if (photos.length == 1) {
      return GestureDetector(
        onTap: () => _openImageViewer(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              _buildSingleImage(photos.first, isDark),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: photos.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _openImageViewer(index),
                      child: _buildSingleImage(photos[index], isDark),
                    );
                  },
                ),
              ),
              // Index counter pill + Fullscreen icon
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => _openImageViewer(_currentIndex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_currentIndex + 1} / ${photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(photos.length, (index) {
            final isSelected = index == _currentIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLight
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSingleImage(String path, bool isDark) {
    final clean = path.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => AppPhotoPlaceholder(
          photoPath: clean,
          isDark: isDark,
          isFullScreen: false,
          forcedReason: PhotoErrorReason.networkOffline,
        ),
      );
    }

    final resolvedFile = PhotoFileResolver.resolveLocalFile(clean);
    if (resolvedFile != null) {
      return Image.file(
        resolvedFile,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => AppPhotoPlaceholder(
          photoPath: clean,
          isDark: isDark,
          isFullScreen: false,
          forcedReason: PhotoErrorReason.corrupted,
        ),
      );
    }

    return AppPhotoPlaceholder(
      photoPath: clean,
      isDark: isDark,
      isFullScreen: false,
      forcedReason: PhotoErrorReason.localMissing,
    );
  }
}
