// Public UnscaledZone widget and internal render helpers.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:screen_adapt/src/core/adapt_scope.dart';
import 'package:screen_adapt/src/core/screen_metrics.dart';

/// `UnscaledZone` 的反适配模式。
enum UnscaledZoneMode {
  /// 回退子树的原始坐标语义，同时保留父布局槽位。
  ///
  /// 此模式会恢复子树的 `MediaQuery`，并在绘制和命中测试阶段同步反缩放，
  /// 让普通 widget 看起来回到原始尺寸；但 `UnscaledZone` 自身仍按父级当前
  /// 的适配坐标系参与布局。
  contextFallback,

  /// 彻底反适配。
  ///
  /// 此模式除了恢复子树的 `MediaQuery` 外，还会在布局、绘制和命中测试
  /// 三个层面一起反向缩放，使子树的尺寸语义和 `UnscaledZone` 自身的占位
  /// 都回到原始坐标体系。
  full,
}

/// 局部回退到原生尺寸的隔离区。
///
/// 在当前架构下，全局适配是由 binding + `MediaQuery` 共同完成的；
/// 因此局部反适配也要拆成三层：
///
/// - 恢复 `MediaQuery`
/// - 恢复绘制/命中测试坐标
/// - 可选地恢复布局占位
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
    final scope = _resolveAdaptScope(context);
    if (scope == null || scope.scale == ScreenSizeUtils.defaultScale) {
      return child;
    }

    final currentMediaQuery = MediaQuery.maybeOf(context);
    final needsContextRestore =
        currentMediaQuery == null || currentMediaQuery != scope.originMediaQuery;
    final needsPaintUnscale = !scope.paintUnscaled;
    final needsLayoutUnscale =
        mode == UnscaledZoneMode.full && !scope.layoutUnscaled;

    Widget result = child;

    if (needsLayoutUnscale) {
      result = _LayoutUnscale(
        scale: scope.scale,
        child: result,
      );
    }

    if (needsPaintUnscale) {
      result = _PaintUnscale(
        scale: scope.scale,
        child: result,
      );
    }

    if (needsContextRestore) {
      result = MediaQuery(
        data: scope.originMediaQuery,
        child: result,
      );
    }

    final nextScope = scope.copyWith(
      paintUnscaled: scope.paintUnscaled || needsPaintUnscale,
      layoutUnscaled: scope.layoutUnscaled || needsLayoutUnscale,
    );
    if (nextScope != scope) {
      result = AdaptScope(
        state: nextScope,
        child: result,
      );
    }

    return result;
  }
}

AdaptScopeState? _resolveAdaptScope(BuildContext context) {
  final inherited = AdaptScope.maybeOf(context);
  if (inherited != null) {
    return inherited;
  }

  final utils = ScreenSizeUtils.instance;
  final origin = utils.originData;
  if (origin == null) {
    return null;
  }

  final adapted = utils.data == const MediaQueryData() ? origin.design() : utils.data;
  return AdaptScopeState(
    scale: utils.scale,
    originMediaQuery: origin,
    adaptedMediaQuery: adapted,
  );
}

class _PaintUnscale extends SingleChildRenderObjectWidget {
  const _PaintUnscale({
    required this.scale,
    required super.child,
  });

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPaintUnscale(scale: scale);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderPaintUnscale renderObject,
  ) {
    renderObject.scale = scale;
  }
}

class _RenderPaintUnscale extends RenderProxyBox {
  _RenderPaintUnscale({
    required double scale,
  }) : _scale = scale;

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Matrix4 get _paintTransform =>
      Matrix4.diagonal3Values(1.0 / scale, 1.0 / scale, 1.0);

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

    layer = context.pushTransform(
      needsCompositing,
      offset,
      _paintTransform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.scaleByDouble(1.0 / scale, 1.0 / scale, 1.0, 1.0);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final child = this.child;
    if (child == null) return super.computeDistanceToActualBaseline(baseline);

    final childBaseline = child.getDistanceToActualBaseline(baseline);
    if (childBaseline == null) return null;
    return childBaseline / scale;
  }
}

class _LayoutUnscale extends SingleChildRenderObjectWidget {
  const _LayoutUnscale({
    required this.scale,
    required super.child,
  });

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLayoutUnscale(scale: scale);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderLayoutUnscale renderObject,
  ) {
    renderObject.scale = scale;
  }
}

class _RenderLayoutUnscale extends RenderProxyBox {
  _RenderLayoutUnscale({
    required double scale,
  }) : _scale = scale;

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsLayout();
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

  Size _reportedSize(BoxConstraints constraints, Size childSize) {
    final unscaledSize = Size(
      childSize.width / scale,
      childSize.height / scale,
    );
    return constraints.constrain(unscaledSize);
  }

  double _scaledIntrinsicInput(double value) {
    return value.isFinite ? value * scale : value;
  }

  double _reportedIntrinsic(double value) => value / scale;

  @override
  double computeMinIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    return _reportedIntrinsic(
      child.getMinIntrinsicWidth(_scaledIntrinsicInput(height)),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final child = this.child;
    if (child == null) return 0;
    return _reportedIntrinsic(
      child.getMaxIntrinsicWidth(_scaledIntrinsicInput(height)),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    return _reportedIntrinsic(
      child.getMinIntrinsicHeight(_scaledIntrinsicInput(width)),
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0;
    return _reportedIntrinsic(
      child.getMaxIntrinsicHeight(_scaledIntrinsicInput(width)),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.constrain(Size.zero);
    }

    final childSize = child.getDryLayout(_scaledConstraints(constraints));
    return _reportedSize(constraints, childSize);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    child.layout(_scaledConstraints(constraints), parentUsesSize: true);
    size = _reportedSize(constraints, child.size);
  }
}
