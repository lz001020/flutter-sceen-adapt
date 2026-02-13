import 'package:flutter/material.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';
import 'package:screen_adapt/core/strategy/adaptation_config.dart';
import 'package:screen_adapt/core/strategy/adaptation_strategy.dart';

class MobileStrategy extends ScreenAdaptStrategy {
  @override
  bool match(Size physicalSize, double originDpr) => true; // 兜底策略

  @override
  AdaptationConfig compute(Size physicalSize, Size designSize) {
    return AdaptationConfig(
      dpr: physicalSize.width / designSize.width,
      gestureOffset: Offset.zero,
      isExpanded: false,
    );
  }

  @override
  Widget wrapRootWidget(
      Widget rootWidget, AdaptationConfig config, ScreenSizeUtils utils) {
    return rootWidget; // 手机端直接返回，无需额外包装
  }
}
