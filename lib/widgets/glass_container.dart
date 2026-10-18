import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

/// High-performance iOS frosted glass container matching Apple Music & BitChord.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 25.0,
    this.color,
    this.borderColor,
    this.borderWidth = 0.5,
    this.shadow,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(MusifiedStyle.radiusLg);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    
    final defaultBg = isDark
        ? const Color(0xB81C1C1E)
        : const Color(0xC8FFFFFF);
    final defaultBorder = isDark
        ? const Color(0x33FFFFFF)
        : const Color(0x1F000000);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? defaultBg,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor ?? defaultBorder,
          width: borderWidth,
        ),
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: content,
      );
    }

    if (shadow != null && shadow!.isNotEmpty) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: shadow,
        ),
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
