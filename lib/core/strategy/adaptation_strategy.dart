import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';
import 'package:screen_adapt/core/strategy/adaptation_config.dart';


/// adaptation_strategy.dart
///
/// Created by @YuAn on 2026/2/13 10:11.
/// Copyright © 2026 Mountain. All rights reserved.


abstract class ScreenAdaptStrategy {
  bool match(Size physicalSize, double originDpr);
  AdaptationConfig compute(Size physicalSize, Size designSize);

  /// 定义渲染视图配置
  ViewConfiguration createViewConfiguration(RenderView renderView, AdaptationConfig config) {
    final view = renderView.flutterView;
    final physicalConstraints = BoxConstraints.fromViewConstraints(view.physicalConstraints);
    return ViewConfiguration(
      physicalConstraints: physicalConstraints,
      logicalConstraints: physicalConstraints / config.dpr,
      devicePixelRatio: config.dpr,
    );
  }

  /// 定义UI包装结构
  Widget wrapRootWidget(Widget rootWidget, AdaptationConfig config, ScreenSizeUtils utils);
}
