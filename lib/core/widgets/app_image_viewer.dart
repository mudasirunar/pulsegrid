import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../preferences/app_preferences_cubit.dart';

import '../utils/photo_file_resolver.dart';
import 'app_photo_placeholder.dart';

/// Full-screen high-performance image viewer overlay with:
/// - Horizontal swipe between multiple images
/// - Interactive pan & pinch-to-zoom (up to 4.5x)
/// - Double-tap to zoom in / reset to 1x
/// - Smooth swipe-down-to-dismiss gesture with real-time background fade
/// - Top counter badge (e.g. `1 / 3`)
/// - Bottom tactical close ("X") button
class AppImageViewer extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const AppImageViewer({
    super.key,
    required this.photoPaths,
    this.initialIndex = 0,
  });

  /// Displays the full-screen image viewer as a transparent overlay route.
  static Future<void> show(
    BuildContext context, {
    required List<String> photoPaths,
    int initialIndex = 0,
  }) {
    if (photoPaths.isEmpty) return Future.value();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: AppImageViewer(
              photoPaths: photoPaths,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
    );
  }

  @override
  State<AppImageViewer> createState() => _AppImageViewerState();
}

class _AppImageViewerState extends State<AppImageViewer>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late final PageController _pageController;

  // Swipe-down-to-dismiss state
  double _dragOffsetY = 0.0;
  late final AnimationController _resetDragController;
  late Animation<double> _dragAnimation;

  // Track if current page is zoomed in (disables PageView swipe and drag-to-dismiss)
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photoPaths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _resetDragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _dragOffsetY = _dragAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _resetDragController.dispose();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    _resetDragController.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _dragOffsetY += details.delta.dy;
      // Disallow dragging upward beyond top
      if (_dragOffsetY < 0) {
        _dragOffsetY = 0;
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.primaryVelocity ?? 0.0;

    // Dismiss threshold: dragged > 90px or fast flick downwards (> 600px/s)
    if (_dragOffsetY > 90 || velocity > 600) {
      _closeViewer();
    } else {
      // Snap back to original position
      _dragAnimation = Tween<double>(
        begin: _dragOffsetY,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _resetDragController,
          curve: Curves.easeOutCubic,
        ),
      );
      _resetDragController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _dragOffsetY = 0.0;
          });
        }
      });
    }
  }

  void _closeViewer() {
    var hapticsEnabled = true;
    try {
      hapticsEnabled = context.read<AppPreferencesCubit>().state.hapticEnabled;
    } catch (_) {}
    if (hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photoPaths;
    final total = photos.length;

    // Background opacity fades as the user drags down
    final double backdropOpacity = (1.0 - (_dragOffsetY / 350))
        .clamp(0.0, 1.0)
        .toDouble();

    // Subtle scale-down as image is dragged away
    final double imageScale = (1.0 - (_dragOffsetY / 1200))
        .clamp(0.75, 1.0)
        .toDouble();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Dynamic dimming black backdrop
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.95 * backdropOpacity),
            ),
          ),

          // 2. Gesture-controlled draggable image canvas
          GestureDetector(
            onVerticalDragStart: _isZoomed ? null : _onVerticalDragStart,
            onVerticalDragUpdate: _isZoomed ? null : _onVerticalDragUpdate,
            onVerticalDragEnd: _isZoomed ? null : _onVerticalDragEnd,
            behavior: HitTestBehavior.translucent,
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Transform.scale(
                scale: imageScale,
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: total,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _isZoomed = false;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _ZoomableImageView(
                      photoPath: photos[index],
                      onZoomChanged: (isZoomed) {
                        if (_isZoomed != isZoomed) {
                          setState(() {
                            _isZoomed = isZoomed;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // 3. Top Header Bar (Counter Badge & Drag Hint)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close shortcut tap
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: _closeViewer,
                      tooltip: 'Back',
                    ),

                    // Counter Pill (e.g. "1 / 3")
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Balance space for center alignment
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual zoomable image item with pan, pinch-to-zoom, and double-tap zoom
class _ZoomableImageView extends StatefulWidget {
  final String photoPath;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImageView({
    required this.photoPath,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableImageView> createState() => _ZoomableImageViewState();
}

class _ZoomableImageViewState extends State<_ZoomableImageView>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;

  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_handleTransformChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformController.removeListener(_handleTransformChanged);
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    widget.onZoomChanged(scale > 1.05);
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _onDoubleTap() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final matrix = _transformController.value;

    final Matrix4 endMatrix;
    if (currentScale > 1.05) {
      // Zoom out back to 1.0
      endMatrix = Matrix4.identity();
    } else {
      // Zoom in to 2.5x centered at double tap location
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 2.5;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);

      // ignore: deprecated_member_use
      endMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(x, y)
        // ignore: deprecated_member_use
        ..scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(
      begin: matrix,
      end: endMatrix,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final clean = widget.photoPath.trim();
    final isNetwork = clean.startsWith('http://') || clean.startsWith('https://');

    Widget imageContent;

    if (isNetwork) {
      imageContent = Image.network(
        clean,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => AppPhotoPlaceholder(
          photoPath: clean,
          isDark: true,
          isFullScreen: true,
          forcedReason: PhotoErrorReason.networkOffline,
        ),
      );
    } else {
      final resolved = PhotoFileResolver.resolveLocalFile(clean);
      if (resolved != null) {
        imageContent = Image.file(
          resolved,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => AppPhotoPlaceholder(
            photoPath: clean,
            isDark: true,
            isFullScreen: true,
            forcedReason: PhotoErrorReason.corrupted,
          ),
        );
      } else {
        imageContent = AppPhotoPlaceholder(
          photoPath: clean,
          isDark: true,
          isFullScreen: true,
          forcedReason: PhotoErrorReason.localMissing,
        );
      }
    }

    return GestureDetector(
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: _onDoubleTap,
      behavior: HitTestBehavior.translucent,
      child: InteractiveViewer(
        transformationController: _transformController,
        clipBehavior: Clip.none,
        minScale: 1.0,
        maxScale: 4.5,
        panAxis: PanAxis.free,
        child: Center(
          child: imageContent,
        ),
      ),
    );
  }
}
