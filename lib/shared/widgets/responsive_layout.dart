import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveLayout {
  const ResponsiveLayout._();

  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  static bool isTablet(BuildContext context, {double breakpoint = 700}) {
    return screenWidth(context) >= breakpoint;
  }

  static bool isCompact(BuildContext context, {double breakpoint = 380}) {
    return screenWidth(context) < breakpoint;
  }

  static double pagePadding(
    BuildContext context, {
    double compact = 14,
    double regular = 18,
    double wide = 24,
  }) {
    final width = screenWidth(context);
    if (width >= 600) {
      return wide;
    }
    if (width < 360) {
      return compact;
    }
    return regular;
  }

  static EdgeInsets pageInsets(
    BuildContext context, {
    double top = 16,
    double bottom = 24,
    double compact = 14,
    double regular = 18,
    double wide = 24,
  }) {
    final horizontal = pagePadding(
      context,
      compact: compact,
      regular: regular,
      wide: wide,
    );
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  static double maxContentWidth(
    BuildContext context, {
    double phone = 460,
    double tablet = 760,
    double desktop = 1120,
  }) {
    final width = screenWidth(context);
    if (width >= 1200) {
      return desktop;
    }
    if (width >= 700) {
      return tablet;
    }
    return phone;
  }

  static double adaptiveSpace(
    BuildContext context, {
    double min = 8,
    double max = 24,
    double factor = 0.03,
  }) {
    return (screenWidth(context) * factor).clamp(min, max);
  }

  static double fontSize(
    BuildContext context,
    double base, {
    double minScale = 0.9,
    double maxScale = 1.18,
  }) {
    final scale = (screenWidth(context) / 390).clamp(minScale, maxScale);
    return base * scale;
  }

  static double bottomInset(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom;
  }

  static double dialogWidth(
    BuildContext context, {
    double maxWidth = 420,
    double horizontalMargin = 48,
    double minWidth = 280,
  }) {
    final availableWidth = math.max(
      minWidth,
      screenWidth(context) - horizontalMargin,
    );
    return math.min(maxWidth, availableWidth);
  }
}

class ResponsiveScrollBody extends StatelessWidget {
  const ResponsiveScrollBody({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding,
    this.safeArea = true,
    this.fillViewport = false,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;
  final bool fillViewport;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        (padding ?? ResponsiveLayout.pageInsets(context, top: 16, bottom: 24))
            .resolve(Directionality.of(context));

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final scrollPadding = resolvedPadding.add(
          EdgeInsets.only(bottom: ResponsiveLayout.bottomInset(context)),
        );
        Widget centeredChild = Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );

        if (fillViewport && constraints.hasBoundedHeight) {
          final minHeight =
              math.max(0.0, constraints.maxHeight - scrollPadding.vertical);

          centeredChild = ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: centeredChild,
          );
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: scrollPadding,
          child: centeredChild,
        );
      },
    );

    if (!safeArea) {
      return content;
    }

    return SafeArea(child: content);
  }
}

class ResponsiveSheetBody extends StatelessWidget {
  const ResponsiveSheetBody({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.maxHeightFactor = 0.9,
    this.padding,
    this.topSafeArea = false,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? padding;
  final bool topSafeArea;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = (padding ??
            ResponsiveLayout.pageInsets(
              context,
              top: 16,
              bottom: 24,
            ))
        .resolve(Directionality.of(context));

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: ResponsiveLayout.bottomInset(context)),
      child: SafeArea(
        top: topSafeArea,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight:
                  ResponsiveLayout.screenHeight(context) * maxHeightFactor,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: resolvedPadding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class ResponsiveConstrainedBox extends StatelessWidget {
  const ResponsiveConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth = 460,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class ResponsiveWrapGrid extends StatelessWidget {
  const ResponsiveWrapGrid({
    super.key,
    required this.children,
    required this.minChildWidth,
    this.maxColumns,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minChildWidth;
  final int? maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : ResponsiveLayout.screenWidth(context);
        final allowedColumns = math.max(1, maxColumns ?? children.length);
        var columns =
            ((maxWidth + spacing) / (minChildWidth + spacing)).floor();
        columns = columns.clamp(1, allowedColumns);

        final itemWidth = columns == 1
            ? maxWidth
            : (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
