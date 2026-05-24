import 'package:flutter/material.dart';

/// A small status dot widget that pulses in opacity over 2 seconds.
class StatusDot extends StatefulWidget {
  final Color color;
  final double size;

  const StatusDot({
    super.key,
    required this.color,
    this.size = 10.0,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha(128),
              blurRadius: widget.size / 2.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
      ),
    );
  }
}
