import 'package:flutter/material.dart';
import '../theme/ultra_modern_theme.dart';
import '../widgets/ultra_modern_widgets.dart';

enum MoonPayButtonSize { compact, full }

class MoonPayButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final MoonPayButtonSize size;
  final bool isLoading;
  final String? error;
  final bool disabled;

  const MoonPayButton({
    super.key,
    this.onPressed,
    this.size = MoonPayButtonSize.full,
    this.isLoading = false,
    this.error,
    this.disabled = false,
  });

  const MoonPayButton.compact({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.error,
    this.disabled = false,
  }) : size = MoonPayButtonSize.compact;

  @override
  State<MoonPayButton> createState() => _MoonPayButtonState();
}

class _MoonPayButtonState extends State<MoonPayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: UltraModernTheme.fastAnimation,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled || widget.isLoading || widget.onPressed == null) return;

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.isLoading;

    if (widget.size == MoonPayButtonSize.compact) {
      return _buildCompactButton(isDisabled);
    }

    return _buildFullButton(isDisabled);
  }

  Widget _buildFullButton(bool isDisabled) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: UltraModernWidgets.glassContainer(
            padding: EdgeInsets.zero,
            borderRadius: UltraModernTheme.radiusMd,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
              child: InkWell(
                onTap: isDisabled ? null : _handleTap,
                borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UltraModernTheme.spacingLg,
                    vertical: UltraModernTheme.spacingMd,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      UltraModernTheme.radiusMd,
                    ),
                    border: Border.all(
                      color: isDisabled
                          ? UltraModernTheme.textTertiary.withOpacity(0.3)
                          : UltraModernTheme.primaryGold.withOpacity(0.5),
                      width: 1.0,
                    ),
                    gradient: isDisabled
                        ? null
                        : LinearGradient(
                            colors: [
                              UltraModernTheme.primaryGold.withOpacity(0.1),
                              UltraModernTheme.accentGold.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading) ...[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              UltraModernTheme.primaryGold,
                            ),
                          ),
                        ),
                        const SizedBox(width: UltraModernTheme.spacingSm),
                      ] else ...[
                        Icon(
                          Icons.account_balance_wallet,
                          color: isDisabled
                              ? UltraModernTheme.textTertiary
                              : UltraModernTheme.primaryGold,
                          size: 20,
                        ),
                        const SizedBox(width: UltraModernTheme.spacingSm),
                      ],
                      Text(
                        widget.isLoading ? 'Processing...' : 'Buy with MoonPay',
                        style: UltraModernTheme.headline.copyWith(
                          color: isDisabled
                              ? UltraModernTheme.textTertiary
                              : UltraModernTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactButton(bool isDisabled) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
              gradient: isDisabled ? null : UltraModernTheme.primaryGradient,
              boxShadow: isDisabled ? null : UltraModernTheme.glowShadow,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
              child: InkWell(
                onTap: isDisabled ? null : _handleTap,
                borderRadius: BorderRadius.circular(UltraModernTheme.radiusMd),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              UltraModernTheme.textInverse,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.account_balance_wallet,
                          color: UltraModernTheme.textInverse,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MoonPayButtonWithError extends StatefulWidget {
  final VoidCallback? onPressed;
  final MoonPayButtonSize size;
  final bool isLoading;
  final String? error;
  final bool disabled;

  const MoonPayButtonWithError({
    super.key,
    this.onPressed,
    this.size = MoonPayButtonSize.full,
    this.isLoading = false,
    this.error,
    this.disabled = false,
  });

  @override
  State<MoonPayButtonWithError> createState() => _MoonPayButtonWithErrorState();
}

class _MoonPayButtonWithErrorState extends State<MoonPayButtonWithError>
    with SingleTickerProviderStateMixin {
  late AnimationController _errorAnimationController;
  late Animation<double> _errorShakeAnimation;

  @override
  void initState() {
    super.initState();
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _errorShakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _errorAnimationController,
        curve: Curves.elasticIn,
      ),
    );
  }

  @override
  void didUpdateWidget(MoonPayButtonWithError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error != null && oldWidget.error == null) {
      _errorAnimationController.forward().then((_) {
        _errorAnimationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _errorAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _errorShakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_errorShakeAnimation.value, 0),
              child: MoonPayButton(
                onPressed: widget.onPressed,
                size: widget.size,
                isLoading: widget.isLoading,
                disabled: widget.disabled,
              ),
            );
          },
        ),
        if (widget.error != null) ...[
          const SizedBox(height: UltraModernTheme.spacingXs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UltraModernTheme.spacingSm,
              vertical: UltraModernTheme.spacing2xs,
            ),
            decoration: BoxDecoration(
              color: UltraModernTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UltraModernTheme.radiusSm),
              border: Border.all(
                color: UltraModernTheme.errorRed.withOpacity(0.3),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: UltraModernTheme.errorRed,
                  size: 14,
                ),
                const SizedBox(width: UltraModernTheme.spacing2xs),
                Text(
                  widget.error!,
                  style: UltraModernTheme.caption1.copyWith(
                    color: UltraModernTheme.errorRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
