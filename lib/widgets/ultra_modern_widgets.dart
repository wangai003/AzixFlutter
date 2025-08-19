import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../theme/ultra_modern_theme.dart';

/// Collection of ultra-modern UI components inspired by world-class fintech apps
class UltraModernWidgets {
  
  /// Glassmorphism container with backdrop blur (inspired by iOS and premium apps)
  static Widget glassContainer({
    required Widget child,
    double borderRadius = UltraModernTheme.radiusLg,
    Color? color,
    EdgeInsets? padding,
    double? width,
    double? height,
    bool hasBorder = true,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: UltraModernTheme.glassCard(
        color: color,
        borderRadius: borderRadius,
        hasBorder: hasBorder,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(UltraModernTheme.spacingLg),
            child: child,
          ),
        ),
      ),
    );
  }
  
  /// Neon glow card with animated borders
  static Widget neonCard({
    required Widget child,
    Color glowColor = UltraModernTheme.primaryGold,
    double borderRadius = UltraModernTheme.radiusLg,
    EdgeInsets? padding,
    bool animated = true,
  }) {
    final card = Container(
      decoration: BoxDecoration(
        color: UltraModernTheme.glassBlack,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: glowColor.withOpacity(0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding ?? const EdgeInsets.all(UltraModernTheme.spacingLg),
          child: child,
        ),
      ),
    );
    
    if (animated) {
      return card.animate(
        onPlay: (controller) => controller.repeat(),
      ).shimmer(
        duration: const Duration(seconds: 3),
        color: glowColor.withOpacity(0.1),
      );
    }
    
    return card;
  }
  
  /// Animated number counter with smooth transitions
  static Widget animatedCounter({
    required double value,
    required String suffix,
    TextStyle? textStyle,
    Duration duration = UltraModernTheme.mediumAnimation,
    int decimalPlaces = 6,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween<double>(end: value),
      curve: UltraModernTheme.easeOut,
      builder: (context, animatedValue, child) {
        return Text(
          '${animatedValue.toStringAsFixed(decimalPlaces)} $suffix',
          style: textStyle ?? UltraModernTheme.monoLarge,
        );
      },
    );
  }
  
  /// Circular progress indicator with gradient and glow
  static Widget gradientCircularProgress({
    required double progress,
    double size = 120,
    double strokeWidth = 8,
    List<Color> colors = const [
      UltraModernTheme.primaryGold,
      UltraModernTheme.accentGold,
    ],
    Color backgroundColor = UltraModernTheme.steel,
    Widget? child,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              color: backgroundColor,
            ),
          ),
          // Gradient progress circle
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: GradientCircularProgressPainter(
                progress: progress,
                strokeWidth: strokeWidth,
                colors: colors,
              ),
            ),
          ),
          // Center content
          if (child != null) child,
        ],
      ),
    );
  }
  
  /// Floating action button with modern design
  static Widget modernFAB({
    required VoidCallback onPressed,
    required IconData icon,
    String? heroTag,
    Color backgroundColor = UltraModernTheme.primaryGold,
    Color foregroundColor = UltraModernTheme.textInverse,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: UltraModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: UltraModernTheme.glowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(size / 2),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Icon(
            icon,
            color: foregroundColor,
            size: size * 0.4,
          ),
        ),
      ),
    ).animate().scale(
      duration: UltraModernTheme.fastAnimation,
      curve: UltraModernTheme.elasticOut,
    );
  }
  
  /// Data visualization card with animated entry
  static Widget dataCard({
    required String title,
    required String value,
    required String subtitle,
    IconData? icon,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    return glassContainer(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UltraModernTheme.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: UltraModernTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: UltraModernTheme.spacingSm),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: UltraModernTheme.footnote,
                  ),
                ),
              ],
            ),
            const SizedBox(height: UltraModernTheme.spacingSm),
            Text(
              value,
              style: UltraModernTheme.title2.copyWith(
                color: valueColor ?? UltraModernTheme.primaryGold,
              ),
            ),
            const SizedBox(height: UltraModernTheme.spacing2xs),
            Text(
              subtitle,
              style: UltraModernTheme.caption1,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      duration: UltraModernTheme.mediumAnimation,
    ).slideY(
      begin: 0.3,
      duration: UltraModernTheme.mediumAnimation,
      curve: UltraModernTheme.easeOut,
    );
  }
  
  /// Modern toggle switch
  static Widget modernToggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    Color activeColor = UltraModernTheme.primaryGold,
    Color inactiveColor = UltraModernTheme.steel,
    double width = 60,
    double height = 32,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: UltraModernTheme.fastAnimation,
        curve: UltraModernTheme.easeInOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: value ? UltraModernTheme.glowShadow : UltraModernTheme.softShadow,
        ),
        child: AnimatedAlign(
          duration: UltraModernTheme.fastAnimation,
          curve: UltraModernTheme.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 4,
            height: height - 4,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular((height - 4) / 2),
              boxShadow: UltraModernTheme.softShadow,
            ),
          ),
        ),
      ),
    );
  }
  
  /// Segmented control inspired by iOS
  static Widget segmentedControl<T>({
    required List<T> segments,
    required T selected,
    required ValueChanged<T> onChanged,
    required String Function(T) labelBuilder,
    Color backgroundColor = UltraModernTheme.charcoal,
    Color selectedColor = UltraModernTheme.primaryGold,
    Color unselectedColor = UltraModernTheme.textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: segments.map((segment) {
            final isSelected = segment == selected;
            return Flexible(
              child: GestureDetector(
                onTap: () => onChanged(segment),
                child: AnimatedContainer(
                  duration: UltraModernTheme.fastAnimation,
                  curve: UltraModernTheme.easeInOut,
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(
                    vertical: UltraModernTheme.spacingSm,
                    horizontal: UltraModernTheme.spacingMd,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
                  ),
                  child: Text(
                    labelBuilder(segment),
                    textAlign: TextAlign.center,
                    style: UltraModernTheme.callout.copyWith(
                      color: isSelected ? UltraModernTheme.textInverse : unselectedColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  /// Particle animation background
  static Widget particleBackground({
    required Widget child,
    int particleCount = 50,
    Color particleColor = UltraModernTheme.primaryGold,
  }) {
    return Stack(
      children: [
        // Particle layer
        Positioned.fill(
          child: CustomPaint(
            painter: ParticleBackgroundPainter(
              particleCount: particleCount,
              particleColor: particleColor,
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
  
  /// Modern input field
  static Widget modernTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: UltraModernTheme.caption1.copyWith(
            color: UltraModernTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: UltraModernTheme.spacingXs),
        glassContainer(
          padding: EdgeInsets.zero,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: UltraModernTheme.body,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: UltraModernTheme.body.copyWith(
                color: UltraModernTheme.textTertiary,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: UltraModernTheme.textSecondary)
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(UltraModernTheme.spacingMd),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for gradient circular progress
class GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final List<Color> colors;

  GradientCircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      colors: colors,
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * math.pi * progress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for particle background animation
class ParticleBackgroundPainter extends CustomPainter {
  final int particleCount;
  final Color particleColor;

  ParticleBackgroundPainter({
    required this.particleCount,
    required this.particleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = particleColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
