import 'package:flutter/material.dart';

/// Opt-in horizontal two-finger navigation. Single-finger TalkBack gestures,
/// vertical scrolling, and the separately mounted Braille keyboard are left
/// to their normal owners.
class TwoFingerNavigationDetector extends StatefulWidget {
  final bool enabled;
  final ValueChanged<int> onSwipe;
  final Widget child;

  const TwoFingerNavigationDetector({
    super.key,
    required this.enabled,
    required this.onSwipe,
    required this.child,
  });

  @override
  State<TwoFingerNavigationDetector> createState() =>
      _TwoFingerNavigationDetectorState();
}

class _TwoFingerNavigationDetectorState
    extends State<TwoFingerNavigationDetector> {
  final Map<int, Offset> _starts = {};
  final Map<int, Offset> _positions = {};
  int _direction = 0;

  void _down(PointerDownEvent event) {
    if (!widget.enabled) return;
    _starts[event.pointer] = event.localPosition;
    _positions[event.pointer] = event.localPosition;
    if (_positions.length > 2) _reset();
  }

  void _move(PointerMoveEvent event) {
    if (!_positions.containsKey(event.pointer)) return;
    _positions[event.pointer] = event.localPosition;
    if (_positions.length != 2) return;
    final ids = _positions.keys.toList();
    final first = _positions[ids[0]]! - _starts[ids[0]]!;
    final second = _positions[ids[1]]! - _starts[ids[1]]!;
    if (first.dx.sign == second.dx.sign &&
        first.dy.abs() < 90 &&
        second.dy.abs() < 90 &&
        first.dx.abs() > 100 &&
        second.dx.abs() > 100) {
      _direction = first.dx < 0 ? 1 : -1;
    }
  }

  void _end(PointerEvent event) {
    _positions.remove(event.pointer);
    _starts.remove(event.pointer);
    if (_positions.isNotEmpty) return;
    final direction = _direction;
    _reset();
    if (widget.enabled && direction != 0) widget.onSwipe(direction);
  }

  void _reset() {
    _starts.clear();
    _positions.clear();
    _direction = 0;
  }

  @override
  void didUpdateWidget(TwoFingerNavigationDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _reset();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _end,
    onPointerCancel: _end,
    child: widget.child,
  );
}
