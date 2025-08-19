import 'package:flutter/material.dart';
import '../theme/marketplace_theme.dart';
import '../utils/responsive_layout.dart';

/// Enhanced image widget that handles both URLs and file paths with fallbacks
class EnhancedImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showLoadingIndicator;
  final Map<String, String>? headers;

  const EnhancedImageWidget({
    Key? key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.showLoadingIndicator = true,
    this.headers,
  }) : super(key: key);

  @override
  State<EnhancedImageWidget> createState() => _EnhancedImageWidgetState();
}

class _EnhancedImageWidgetState extends State<EnhancedImageWidget> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: _hasError ? _buildErrorWidget() : _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = widget.imageUrl!;
    
    // Handle different image sources
    if (_isNetworkUrl(imageUrl)) {
      return Image.network(
        imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: widget.headers,
        loadingBuilder: widget.showLoadingIndicator 
            ? (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return _buildLoadingIndicator(loadingProgress);
              }
            : null,
        errorBuilder: (context, error, stackTrace) {
          setState(() => _hasError = true);
          return _buildErrorWidget();
        },
      );
    } else {
      // Handle local file paths or asset images
      return Image.asset(
        imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          setState(() => _hasError = true);
          return _buildErrorWidget();
        },
      );
    }
  }

  Widget _buildLoadingIndicator(ImageChunkEvent? loadingProgress) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: loadingProgress?.expectedTotalBytes != null
                ? loadingProgress!.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(MarketplaceTheme.primaryBlue),
          ),
          if (ResponsiveLayout.isTabletOrDesktop(context)) ...[
            SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 8)),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: widget.borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: ResponsiveLayout.isMobile(context) ? 24 : 32,
            color: Colors.grey.shade400,
          ),
          if (ResponsiveLayout.isTabletOrDesktop(context)) ...[
            SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 4)),
            Text(
              'No Image',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: ResponsiveLayout.isMobile(context) ? 20 : 28,
            color: Colors.red.shade400,
          ),
          if (ResponsiveLayout.isTabletOrDesktop(context)) ...[
            SizedBox(height: ResponsiveLayout.getResponsiveSpacing(context, 4)),
            Text(
              'Failed to load',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  bool _isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }
}

/// Specialized product image widget with consistent styling
class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? size;
  final bool isGrid;

  const ProductImageWidget({
    Key? key,
    this.imageUrl,
    this.size,
    this.isGrid = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultSize = size ?? (isGrid 
        ? (ResponsiveLayout.isMobile(context) ? 120 : 150) 
        : (ResponsiveLayout.isMobile(context) ? 80 : 100));

    return EnhancedImageWidget(
      imageUrl: imageUrl,
      width: defaultSize,
      height: defaultSize,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(
        isGrid ? MarketplaceTheme.radiusLg : MarketplaceTheme.radiusMd,
      ),
      placeholder: Container(
        width: defaultSize,
        height: defaultSize,
        decoration: BoxDecoration(
          color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(
            isGrid ? MarketplaceTheme.radiusLg : MarketplaceTheme.radiusMd,
          ),
        ),
        child: Icon(
          Icons.inventory_2_outlined,
          size: defaultSize * 0.4,
          color: MarketplaceTheme.primaryBlue.withOpacity(0.5),
        ),
      ),
      errorWidget: Container(
        width: defaultSize,
        height: defaultSize,
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(
            isGrid ? MarketplaceTheme.radiusLg : MarketplaceTheme.radiusMd,
          ),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Icon(
          Icons.inventory_2_outlined,
          size: defaultSize * 0.4,
          color: Colors.orange.shade400,
        ),
      ),
    );
  }
}

/// Specialized service image widget with consistent styling
class ServiceImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? size;
  final bool isGrid;

  const ServiceImageWidget({
    Key? key,
    this.imageUrl,
    this.size,
    this.isGrid = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultSize = size ?? (isGrid 
        ? (ResponsiveLayout.isMobile(context) ? 120 : 150) 
        : (ResponsiveLayout.isMobile(context) ? 80 : 100));

    return EnhancedImageWidget(
      imageUrl: imageUrl,
      width: defaultSize,
      height: defaultSize,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(
        isGrid ? MarketplaceTheme.radiusLg : MarketplaceTheme.radiusMd,
      ),
      placeholder: Container(
        width: defaultSize,
        height: defaultSize,
        decoration: BoxDecoration(
          color: MarketplaceTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(
            isGrid ? MarketplaceTheme.radiusLg : MarketplaceTheme.radiusMd,
          ),
        ),
        child: Icon(
          Icons.work_outline,
          size: defaultSize * 0.4,
          color: MarketplaceTheme.primaryGreen.withOpacity(0.5),
        ),
      ),
      errorWidget: Container(
        width: defaultSize,
        height: defaultSize,
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(
            isGrid ? MarketplaceTheme.radiusLg : MarketplaceTheme.radiusMd,
          ),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Icon(
          Icons.work_outline,
          size: defaultSize * 0.4,
          color: Colors.purple.shade400,
        ),
      ),
    );
  }
}

/// Avatar image widget for user profiles
class AvatarImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackText;
  final double? size;

  const AvatarImageWidget({
    Key? key,
    this.imageUrl,
    this.fallbackText,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? (ResponsiveLayout.isMobile(context) ? 40 : 50);
    
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: EnhancedImageWidget(
          imageUrl: imageUrl,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          placeholder: Container(
            color: MarketplaceTheme.primaryBlue.withOpacity(0.1),
            child: Center(
              child: fallbackText != null && fallbackText!.isNotEmpty
                  ? Text(
                      fallbackText!.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: MarketplaceTheme.primaryBlue,
                        fontSize: avatarSize * 0.4,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Icon(
                      Icons.person_outline,
                      size: avatarSize * 0.5,
                      color: MarketplaceTheme.primaryBlue.withOpacity(0.7),
                    ),
            ),
          ),
          errorWidget: Container(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.person_outline,
              size: avatarSize * 0.5,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}
