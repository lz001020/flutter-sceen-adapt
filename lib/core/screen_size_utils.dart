import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:screen_adapt/core/strategy/adaptation_config.dart';
import 'package:screen_adapt/core/strategy/adaptation_strategy.dart';
import 'package:screen_adapt/core/strategy/expanded_strategy.dart';
import 'package:screen_adapt/core/strategy/mobile_strategy.dart';

class ScreenSizeUtils {
  static final ScreenSizeUtils instance = ScreenSizeUtils._internal();

  ScreenSizeUtils._internal();

  late Size designSize;
  final List<ScreenAdaptStrategy> _strategies = [];
  late ScreenAdaptStrategy _defaultStrategy;
  ScreenAdaptStrategy? _activeStrategy;

  final ValueNotifier<AdaptationConfig?> configVn = ValueNotifier(null);
  final ValueNotifier<Offset> dragOffsetVn = ValueNotifier(Offset.zero);

  /// 全局背景图配置
  String? foldBackgroundImage;

  // 提供一个更新方法
  void updateBackgroundImage(String path) {
    foldBackgroundImage = path;
    configVn.notifyListeners(); // 触发 UI 刷新
  }

  void init({
    required Size designSize,
    String? backgroundImage, // 初始化时传入背景图
    List<ScreenAdaptStrategy>? customStrategies,
  }) {
    this.designSize = designSize;
    this.foldBackgroundImage = backgroundImage;
    _defaultStrategy = MobileStrategy();
    _strategies.clear();
    if (customStrategies != null) _strategies.addAll(customStrategies);
    _strategies.add(ExpandedStrategy());
    setup();
  }

  void setup() {
    final view = PlatformDispatcher.instance.implicitView!;
    final physicalConstraints = view.physicalConstraints;
    final physicalSize =
        Size(physicalConstraints.maxWidth, physicalConstraints.maxHeight);
    final originDpr = view.devicePixelRatio;

    _activeStrategy = _strategies.firstWhere(
      (s) => s.match(physicalSize, originDpr),
      orElse: () => _defaultStrategy,
    );

    final newConfig = _activeStrategy!.compute(physicalSize, designSize);
    if (configVn.value?.isExpanded != newConfig.isExpanded) {
      dragOffsetVn.value = Offset.zero;
    }
    configVn.value = newConfig;
  }

  AdaptationConfig get currentConfig =>
      configVn.value ??
      const AdaptationConfig(
          dpr: 1.0, gestureOffset: Offset.zero, isExpanded: false);

  Offset get totalOffset => currentConfig.gestureOffset + dragOffsetVn.value;

  double get scale {
    final systemDpr =
        PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    return currentConfig.dpr / systemDpr;
  }

  void updateDrag(Offset delta) => dragOffsetVn.value += delta;

  ViewConfiguration createViewConfiguration(RenderView renderView) =>
      _activeStrategy!.createViewConfiguration(renderView, currentConfig);

  Widget wrapRootWidget(Widget rootWidget) =>
      _activeStrategy!.wrapRootWidget(rootWidget, currentConfig, this);
}
