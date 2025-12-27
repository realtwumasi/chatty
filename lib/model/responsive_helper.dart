import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Responsive {
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 900;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;

  // Smart Font Sizing:
  // Use .sp on mobile for perfect scaling.
  // Use standard logical pixels on desktop/tablet to prevent huge text.
  static double fontSize(BuildContext context, double size) {
    if (isDesktop(context)) {
      return size; // Return standard logical pixels
    }
    return size.sp; // Return scaled pixels
  }

  // Smart Radius:
  static double radius(BuildContext context, double size) {
    if (isDesktop(context)) return size;
    return size.r;
  }
}

// Wrapper for pages to prevent full-width stretching on Desktop
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 600
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    }
    return child;
  }
}