import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'asset_illustrations.dart';

/// A premium mascot widget representing a friendly Nepali crop advisor/farmer
/// using the high-quality local image asset.
class FarmerMascot extends StatelessWidget {
  final double size;
  final bool animate;

  const FarmerMascot({
    super.key,
    this.size = 120,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.5),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDeep.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          AppAssets.farmerPortrait,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Safe fallback if asset is missing or failing
            return Container(
              color: AppColors.greenLime,
              child: const Icon(
                Icons.person,
                color: AppColors.green,
                size: 40,
              ),
            );
          },
        ),
      ),
    );

    if (animate) {
      return _AnimatedFloatingMascot(child: child);
    }

    return child;
  }
}

class _AnimatedFloatingMascot extends StatefulWidget {
  final Widget child;

  const _AnimatedFloatingMascot({required this.child});

  @override
  State<_AnimatedFloatingMascot> createState() =>
      _AnimatedFloatingMascotState();
}

class _AnimatedFloatingMascotState extends State<_AnimatedFloatingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: -6).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: widget.child,
        );
      },
    );
  }
}
