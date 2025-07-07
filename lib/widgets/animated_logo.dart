import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedLogo extends StatelessWidget {
  final double size;

  const AnimatedLogo({
    Key? key,
    this.size = 150,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .fadeIn(
          duration: const Duration(seconds: 1),
          curve: Curves.easeIn,
        )
        .scale(
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
        )
        .then()
        .shimmer(
          duration: const Duration(seconds: 2),
          delay: const Duration(seconds: 1),
        )
        .then()
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
          delay: const Duration(seconds: 3),
        )
        .scale(
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          begin: const Offset(1, 1),
          end: const Offset(1.05, 1.05),
        );
  }
}