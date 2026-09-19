// Public design-size scope widget and inherited controller.
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:screen_adapt/src/core/adapt_scope.dart';
import 'package:screen_adapt/src/core/screen_metrics.dart';

/// 一个向其子级提供设计尺寸上下文的小部件。
///
/// 在应用程序的根部或重要的子树上使用它，为后代启用基于设计的缩放。
class DesignSizeWidget extends StatefulWidget {
  final Widget child;

  const DesignSizeWidget({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => DesignSizeWidgetState();
}

class DesignSizeWidgetState extends State<DesignSizeWidget> {
  late final AdaptController _controller;
  String? _lastDiagnostic;

  /// 当前窗口最新的不可变适配快照。
  AdaptMetrics? get metrics => _controller.metrics;

  /// 当前适配配置。
  AdaptConfig get config => _controller.config;
  @override
  void initState() {
    super.initState();
    _controller = ScreenSizeUtils.instance.controller;
    _controller.addListener(_onMetricsChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onMetricsChanged);
    super.dispose();
  }

  /// 设置屏幕适配的设计尺寸。
  /// 这将触发屏幕指标的重新计算。
  void setDesignSize(Size size) {
    _controller.setDesignSize(size);
  }

  /// 将屏幕适配重置为默认设备指标。
  /// 这将触发屏幕指标的重新计算。
  void reset() {
    _controller.reset();
  }

  void _onMetricsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final outerDesignSizeState = DesignSize.maybeOf(context);
    final inheritedAdaptScope = AdaptScope.maybeOf(context);

    final metrics = _controller.metrics;
    final origin = metrics?.origin ?? MediaQuery.of(context);
    final mediaQueryData = metrics?.adapted ?? origin;
    final adaptScopeState = AdaptScopeState(
      scale: metrics?.scale ?? 1,
      originMediaQuery: origin,
      adaptedMediaQuery: mediaQueryData,
      paintUnscaled: inheritedAdaptScope?.paintUnscaled ?? false,
      layoutUnscaled: inheritedAdaptScope?.layoutUnscaled ?? false,
    );
    final diagnostic = 'design=${_controller.config.designSize} '
        'origin=${adaptScopeState.originMediaQuery.size} '
        'adapted=${mediaQueryData.size} scale=${adaptScopeState.scale} '
        'paintUnscaled=${adaptScopeState.paintUnscaled} '
        'layoutUnscaled=${adaptScopeState.layoutUnscaled}';
    if (_lastDiagnostic != diagnostic) {
      _lastDiagnostic = diagnostic;
      debugPrint('[screen_adapt][scope] $diagnostic');
    }

    if (outerDesignSizeState == null) {
      return MediaQuery(
        data: mediaQueryData,
        child: AdaptScope(
          state: adaptScopeState,
          child: DesignSize(
            data: this,
            metrics: metrics,
            config: config,
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
  final AdaptMetrics? metrics;
  final AdaptConfig? config;

  const DesignSize({
    super.key,
    required this.data,
    this.metrics,
    this.config,
    required super.child,
  });

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
  bool updateShouldNotify(DesignSize oldWidget) =>
      data != oldWidget.data ||
      metrics != oldWidget.metrics ||
      config != oldWidget.config;
}
