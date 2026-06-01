import 'package:flutter/material.dart';

/// A subtle entrance animation: fades and slides its [child] up into place.
///
/// Use [delay] to stagger items in a list (e.g. `index * 60ms`) for a gentle
/// cascade effect.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.offsetY = 16,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offsetY),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Scales its [child] with a quick "pop" whenever [trigger] changes — handy for
/// confirming an auto-toggled state (e.g. a checkbox becoming checked).
class PopOnChange extends StatefulWidget {
  final Object? trigger;
  final Widget child;
  final double maxScale;

  const PopOnChange({
    super.key,
    required this.trigger,
    required this.child,
    this.maxScale = 1.35,
  });

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: widget.maxScale)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: widget.maxScale, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn)),
      weight: 1,
    ),
  ]).animate(_ctl);

  @override
  void didUpdateWidget(covariant PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _ctl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
