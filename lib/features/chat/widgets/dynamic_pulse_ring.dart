import 'package:flutter/material.dart';

class DynamicPulseRing extends StatefulWidget {
  final Widget child;
  final String status; // 'Available', 'Deep Work', 'Offline'

  const DynamicPulseRing({
    super.key,
    required this.child,
    required this.status,
  });

  @override
  State<DynamicPulseRing> createState() => _DynamicPulseRingState();
}

class _DynamicPulseRingState extends State<DynamicPulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(DynamicPulseRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _controller.stop();
    if (widget.status == 'Offline') return;

    if (widget.status == 'Typing') {
      _controller.duration = const Duration(milliseconds: 500); // highly accelerated
      _controller.repeat();
    } else if (widget.status == 'Recording Voice') {
      _controller.duration = const Duration(milliseconds: 800); // dynamic fluctuating
      _controller.repeat(reverse: true);
    } else if (widget.status == 'On Call') {
      _controller.duration = const Duration(seconds: 1); // continuous ripple
      _controller.repeat();
    } else if (widget.status == 'Online') {
      _controller.duration = const Duration(seconds: 2); // slow breathing
      _controller.repeat(reverse: true);
    } else if (widget.status == 'Busy / Deep Work') {
      _controller.duration = const Duration(seconds: 3); // low frequency steady
      _controller.repeat(reverse: true);
    } else {
      _controller.duration = const Duration(seconds: 2);
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == 'Offline') {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1.5),
        ),
        child: widget.child,
      );
    }

    Color pulseColor;
    if (widget.status == 'Typing') pulseColor = Colors.greenAccent; // neon green
    else if (widget.status == 'Recording Voice') pulseColor = Colors.orangeAccent; // vivid orange
    else if (widget.status == 'On Call') pulseColor = Colors.cyan; // deep cyan-blue
    else if (widget.status == 'Busy / Deep Work') pulseColor = Colors.redAccent; // crimson red
    else pulseColor = Colors.green; // emerald green for Online

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double scale = 1.0;
            double alpha = 1.0;

            if (widget.status == 'Typing' || widget.status == 'On Call') {
              // Ripple effect
              scale = 1.0 + (_controller.value * 0.2);
              alpha = 1.0 - _controller.value;
            } else {
              // Breathing effect
              scale = 1.0 + (_controller.value * 0.1);
              alpha = 0.5 + (_controller.value * 0.5);
            }

            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: pulseColor.withValues(alpha: alpha),
                    width: widget.status == 'Typing' ? 3 : 2,
                  ),
                ),
                child: widget.child,
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}
