// Public design-size scope widget and inherited controller.
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:screen_adapt/src/core/adapt_scope.dart';
import 'package:screen_adapt/src/core/screen_metrics.dart';
import 'package:screen_adapt/src/foundation/safe_state.dart';

/// 一个向其子级提供设计尺寸上下文的小部件。
///
/// 在应用程序的根部或重要的子树上使用它，为后代启用基于设计的缩放。
class DesignSizeWidget extends StatefulWidget {
  final Widget child;

  const DesignSizeWidget({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => DesignSizeWidgetState();
}

class DesignSizeWidgetState extends State<DesignSizeWidget>
    with StateAble, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 设置屏幕适配的设计尺寸。
  /// 这将触发屏幕指标的重新计算。
  void setDesignSize(Size size) {
    ScreenSizeUtils.instance.setDesignSize(size);
    _handleMetricsChanged();
  }

  /// 将屏幕适配重置为默认设备指标。
  /// 这将触发屏幕指标的重新计算。
  void reset() {
    ScreenSizeUtils.instance.reset();
    _handleMetricsChanged();
  }

  /// 强制重新构建依赖于屏幕指标的小部件。
  void _handleMetricsChanged() {
    WidgetsBinding.instance.handleMetricsChanged();
  }

  @override
  void didChangeMetrics() {
    ScreenSizeUtils.instance.setup();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final outerDesignSizeState = DesignSize.maybeOf(context);
    final inheritedAdaptScope = AdaptScope.maybeOf(context);

    final origin = ScreenSizeUtils.instance.originData;
    final mediaQueryData = (origin ?? MediaQuery.of(context)).design();
    final adaptScopeState = AdaptScopeState(
      scale: ScreenSizeUtils.instance.scale,
      originMediaQuery: origin ?? mediaQueryData,
      adaptedMediaQuery: mediaQueryData,
      paintUnscaled: inheritedAdaptScope?.paintUnscaled ?? false,
      layoutUnscaled: inheritedAdaptScope?.layoutUnscaled ?? false,
    );

    if (outerDesignSizeState == null) {
      return MediaQuery(
        data: mediaQueryData,
        child: AdaptScope(
          state: adaptScopeState,
          child: DesignSize(
            data: this,
            child: widget.child,
          ),
        ),
      );
    } else {
      return MediaQuery(
        data: mediaQueryData,
        child: AdaptScope(
          state: adaptScopeState,
          child: widget.child,
        ),
      );
    }
  }
}

/// 一个 [InheritedWidget]，用于向其后代提供 [DesignSizeWidgetState]。
class DesignSize extends InheritedWidget {
  final DesignSizeWidgetState data;

  const DesignSize({super.key, required this.data, required super.child});

  /// 从最近的 [DesignSize] 祖先返回 [DesignSizeWidgetState]。
  /// 如果找不到 [DesignSize] 祖先，则返回 `null`。
  static DesignSizeWidgetState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesignSize>()?.data;
  }

  /// 从最近的 [DesignSize] 祖先返回 [DesignSizeWidgetState]。
  /// 如果找不到 [DesignSize] 祖先，则会引发断言错误。
  static DesignSizeWidgetState of(BuildContext context) {
    final DesignSizeWidgetState? result = maybeOf(context);
    assert(result != null, 'No DesignSizeWidgetState found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(DesignSize oldWidget) => data != oldWidget.data;
}
