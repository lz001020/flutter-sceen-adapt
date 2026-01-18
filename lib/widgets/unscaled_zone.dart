import 'package:flutter/widgets.dart'; // For Widget, BuildContext, InheritedWidget, LayoutBuilder, ConstrainedBox

import 'package:screen_adapt/core/screen_size_utils.dart'; // For ScreenSizeUtils

/// A marker InheritedWidget to detect if an ancestor UnscaledZone already exists.
class _UnscaledZoneMarker extends InheritedWidget {
  const _UnscaledZoneMarker({
    required super.child,
  });

  static bool contains(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UnscaledZoneMarker>() != null;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// 核心修正：局部回退到原生尺寸的隔离区
///
/// **简化方案：** 使用 LayoutBuilder 和 ConstrainedBox 修正布局约束，
/// 避免使用复杂的自定义 RenderObject。
///
/// This widget provides a zone where scaling is reverted to the original
/// device pixel ratio, useful for displaying content that should not be
/// affected by global screen adaptation.
class UnscaledZone extends StatelessWidget {
  const UnscaledZone({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Check if an ancestor UnscaledZone already exists via the marker.
    if (_UnscaledZoneMarker.contains(context)) {
      // If an ancestor exists, this UnscaledZone becomes a no-op to prevent double scaling.
      return child;
    }

    final originalMediaQueryData = ScreenSizeUtils.instance.originData;
    final scale = ScreenSizeUtils.instance.scale;

    // Wrap the entire UnscaledZone logic with the marker, so descendants can detect it.
    return _UnscaledZoneMarker(
      child: Builder( // Use Builder to ensure we have a new context to check originalMediaQueryData
        builder: (innerContext) {
          // Check if scaling is actually needed.
          // This check is duplicated, but important for performance if no scaling is applied.
          if (originalMediaQueryData == null || scale == ScreenSizeUtils.defaultScale) {
            return child;
          }

          // 1. 注入原始的 MediaQueryData。
          // 这将修正 MediaQuery.of(context).size, viewInsets, padding 等数据为原生DP值。
          return MediaQuery(
            data: originalMediaQueryData,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 2. 修正布局约束 (Layout Constraints)。
                // 全局渲染层 (ViewConfiguration) 将子 Widget 隐式地放大了 scale 倍。
                // 我们需要将布局约束缩小 1/scale 倍，来抵消 ViewConfiguration 带来的放大效果。
                final double inverseScale = 1.0 / scale;

                final BoxConstraints correctedConstraints = constraints.copyWith(
                  minWidth: constraints.minWidth * inverseScale,
                  maxWidth: constraints.maxWidth * inverseScale,
                  minHeight: constraints.minHeight * inverseScale,
                  maxHeight: constraints.maxHeight * inverseScale,
                );

                // 3. 使用 ConstrainedBox 传递修正后的约束给子 Widget
                return ConstrainedBox(
                  constraints: correctedConstraints,
                  child: child,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
