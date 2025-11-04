import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;
  final Color? backgroundColor;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isOutlined
        ? OutlinedButton.styleFrom(minimumSize: const Size(0, 56))
        : ElevatedButton.styleFrom(
            minimumSize: const Size(0, 56),
            backgroundColor: backgroundColor,
          );

    final child = isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.black,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          );

    Widget button;

    if (width != null) {
      // Fixed width button
      button = SizedBox(
        width: width,
        child: isOutlined
            ? OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                style: buttonStyle,
                child: child,
              )
            : ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: buttonStyle,
                child: child,
              ),
      );
    } else {
      // Auto-sized button
      button = isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: buttonStyle,
              child: child,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: buttonStyle,
              child: child,
            );
    }

    return button
        .animate(
          onPlay: (controller) =>
              isLoading ? controller.stop() : controller.repeat(),
        )
        .shimmer(
          duration: const Duration(seconds: 2),
          color: AppTheme.primaryGold.withOpacity(0.1),
        )
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.02, 1.02),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
        );
  }
}
