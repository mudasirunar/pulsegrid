import 'package:flutter/material.dart';

/// Globally ensures that when any focused input field is covered by the
/// software keyboard (e.g. on screens using `resizeToAvoidBottomInset: false`),
/// its enclosing [Scrollable] scrolls immediately to keep the field cleanly
/// above the keyboard. Fields already visible above the keyboard are untouched.
class KeyboardFocusScrollHandler extends StatefulWidget {
  final Widget child;

  const KeyboardFocusScrollHandler({super.key, required this.child});

  @override
  State<KeyboardFocusScrollHandler> createState() =>
      _KeyboardFocusScrollHandlerState();
}

class _KeyboardFocusScrollHandlerState extends State<KeyboardFocusScrollHandler>
    with WidgetsBindingObserver {
  double _lastViewInsetBottom = 0.0;
  bool _postFrameScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFocusedVisible(animate: true);
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    if (bottomInset > _lastViewInsetBottom) {
      _lastViewInsetBottom = bottomInset;
      if (!_postFrameScheduled) {
        _postFrameScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _postFrameScheduled = false;
          // Track the rising keyboard frame-by-frame with zero debounce lag.
          _ensureFocusedVisible(animate: false);
        });
      }
    } else if (bottomInset < _lastViewInsetBottom) {
      _lastViewInsetBottom = bottomInset;
    }
  }

  void _ensureFocusedVisible({required bool animate}) {
    if (!mounted) return;

    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) return;

    final view = View.of(focusContext);
    final dpr = view.devicePixelRatio;
    final keyboardHeight = view.viewInsets.bottom / dpr;
    if (keyboardHeight <= 0) return;

    final screenHeight = view.physicalSize.height / dpr;
    final keyboardTop = screenHeight - keyboardHeight;

    final renderObject = focusContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final fieldBottom =
        renderObject.localToGlobal(Offset(0, renderObject.size.height)).dy;
    const breathingMargin = 24.0;
    final overlap = (fieldBottom + breathingMargin) - keyboardTop;

    if (overlap <= 0) return;

    final scrollable = Scrollable.maybeOf(focusContext);
    if (scrollable == null) return;

    final position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;

    final targetOffset = (position.pixels + overlap)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((targetOffset - position.pixels).abs() <= 0.5) return;

    if (animate) {
      position.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      position.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
