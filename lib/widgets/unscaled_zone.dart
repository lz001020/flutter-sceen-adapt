/// widgets/unscaled_zone.dart
///
/// Created by longzhi on 2024/7/29
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart'; // 用于 Widget, BuildContext, InheritedWidget, LayoutBuilder, ConstrainedBox

import 'package:screen_adapt/core/screen_size_utils.dart'; // 用于 ScreenSizeUtils

/// `UnscaledZone` 的反适配模式。
enum UnscaledZoneMode {
  /// 仅回退子树上下文。
  ///
  /// 此模式会恢复子树的 `MediaQuery`，并给子树传递放大后的约束，
  /// 但 `UnscaledZone` 自身仍按父级当前的适配坐标系参与布局。
  contextFallback,

  /// 彻底反适配。
  ///
  /// 此模式除了恢复子树的 `MediaQuery` 外，还会在布局、绘制和命中测试
  /// 三个层面一起反向缩放，使子树的尺寸语义和 `UnscaledZone` 自身的占位
  /// 都回到原始坐标体系。
  full,
}

/// 一个标记 InheritedWidget，用于检测是否已存在祖先 UnscaledZone。
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

/// 局部回退到原生尺寸的隔离区
///
/// ## 功能与用途
/// 此小部件提供一个隔离区域，在该区域中，由 [DesignSizeWidget] 应用的全局屏幕适配缩放
/// 将被“撤销”，恢复为设备的原始像素尺寸。这对于展示那些不应被缩放的内容（如某些原生广告、
/// 地图插件或需要精确像素对齐的UI）非常有用。
///
/// ## 嵌套行为与覆盖原则
/// `UnscaledZone` 和 `DesignSizeWidget` 的交互遵循Flutter的组件覆盖原则，即内层组件的行为会“获胜”：
/// - **在 `DesignSizeWidget` 内部嵌套 `UnscaledZone`**：
///   `UnscaledZone` 会移除父级带来的缩放效果，其子组件将恢复原始尺寸。
/// - **在 `UnscaledZone` 内部嵌套 `DesignSizeWidget`**：
///   `DesignSizeWidget` 会重新应用缩放，覆盖父级 `UnscaledZone` 的“不缩放”效果。
///
/// ## 状态共享与性能
/// 为了正确处理复杂的嵌套场景（如 `DesignSizeWidget` -> `UnscaledZone` -> `DesignSizeWidget`），
/// `UnscaledZone` 内部实现了一个标记机制 (`_UnscaledZoneMarker`)。
///
/// 只有最外层的 `UnscaledZone` 会提供这个标记。任何嵌套在内的 `UnscaledZone`
/// 仅执行反缩放逻辑，但不再提供新的标记。这确保了组件树的干净，并与 `DesignSizeWidget`
/// 的单一状态源逻辑保持一致，避免了状态冲突。
///
/// **性能提示**：虽然功能上支持，但应避免在UI结构中频繁、交替地嵌套 `DesignSizeWidget` 和 `UnscaledZone`，
/// 因为每次切换都会涉及MediaQuery的重新计算，可能带来性能开销。
///
/// ## 无效用法
/// 将 `UnscaledZone` 放置在整个应用的最顶层（即其上层没有任何 `DesignSizeWidget`）是无害但无效的。
/// 因为没有已应用的缩放，`UnscaledZone` 的反缩放逻辑不会执行任何操作。
class UnscaledZone extends StatelessWidget {
  const UnscaledZone({
    super.key,
    required this.child,
    this.mode = UnscaledZoneMode.contextFallback,
  });

  final Widget child;
  final UnscaledZoneMode mode;

  @override
  Widget build(BuildContext context) {
    // 检查是否已经存在 UnscaledZone 祖先。
    final bool isNested = _UnscaledZoneMarker.contains(context);

    // 定义核心的“非缩放”逻辑，它应该始终运行，
    // 以确保能够覆盖任何父级的 DesignSizeWidget。
    final Widget unscaledCore = Builder(
      builder: (innerContext) {
        final originalMediaQueryData = ScreenSizeUtils.instance.originData;
        final scale = ScreenSizeUtils.instance.scale;

        // 如果没有应用缩放，则无需执行任何操作。
        if (originalMediaQueryData == null ||
            scale == ScreenSizeUtils.defaultScale) {
          return child;
        }

        // 1. 注入原始的 MediaQueryData。
        return MediaQuery(
          data: originalMediaQueryData,
          child: switch (mode) {
            UnscaledZoneMode.contextFallback => LayoutBuilder(
                builder: (context, constraints) {
                  // constraints 已经是压缩后的适配逻辑像素（÷ scale），
                  // 恢复到原始逻辑像素可用空间需要 × scale。
                  final BoxConstraints correctedConstraints = constraints.copyWith(
                    minWidth: constraints.minWidth * scale,
                    maxWidth: constraints.maxWidth * scale,
                    minHeight: constraints.minHeight * scale,
                    maxHeight: constraints.maxHeight * scale,
                  );

                  return ConstrainedBox(
                    constraints: correctedConstraints,
                    child: child,
                  );
                },
              ),
            UnscaledZoneMode.full => _FullyUnscaledLayout(
                scale: scale,
                child: child,
              ),
          },
        );
      },
    );

    // 如果是嵌套的 UnscaledZone，我们只应用核心逻辑，不提供新的标记。
    // 如果是顶层的 UnscaledZone，我们应用核心逻辑并提供标记，
    // 以便后代可以检测到它。
    if (isNested) {
      return unscaledCore;
    } else {
      return _UnscaledZoneMarker(
        child: unscaledCore,
      );
    }
  }
}

class _FullyUnscaledLayout extends SingleChildRenderObjectWidget {
  const _FullyUnscaledLayout({
    required this.scale,
    required super.child,
  });

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderFullyUnscaledLayout(scale);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderFullyUnscaledLayout renderObject) {
    renderObject.scale = scale;
  }
}

class _RenderFullyUnscaledLayout extends RenderProxyBox {
  _RenderFullyUnscaledLayout(this._scale);

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  BoxConstraints _scaledConstraints(BoxConstraints constraints) {
    double scaleValue(double value) => value.isFinite ? value * scale : value;

    return BoxConstraints(
      minWidth: scaleValue(constraints.minWidth),
      maxWidth: scaleValue(constraints.maxWidth),
      minHeight: scaleValue(constraints.minHeight),
      maxHeight: scaleValue(constraints.maxHeight),
    );
  }

  Size _unscaledSize(Size childSize) {
    return Size(childSize.width / scale, childSize.height / scale);
  }

  Matrix4 get _paintTransform =>
      Matrix4.diagonal3Values(1.0 / scale, 1.0 / scale, 1.0);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.constrain(Size.zero);
    }

    final Size childSize = child.getDryLayout(_scaledConstraints(constraints));
    return constraints.constrain(_unscaledSize(childSize));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    child.layout(_scaledConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(_unscaledSize(child.size));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;

    return result.addWithPaintTransform(
      transform: _paintTransform,
      position: position,
      hitTest: (result, transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    context.pushClipRect(
      needsCompositing,
      offset,
      offset & size,
      (context, offset) {
        final Matrix4 transform = Matrix4.identity()
          ..translateByDouble(offset.dx, offset.dy, 0.0, 1.0)
          ..scaleByDouble(1.0 / scale, 1.0 / scale, 1.0, 1.0);
        context.pushTransform(
          needsCompositing,
          Offset.zero,
          transform,
          (context, offset) {
            context.paintChild(child, Offset.zero);
          },
        );
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.scaleByDouble(1.0 / scale, 1.0 / scale, 1.0, 1.0);
  }
}
