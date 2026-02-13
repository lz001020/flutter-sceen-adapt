/// base/extension.dart
///
/// Created by longzhi on 2024/7/29
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/core/screen_size_utils.dart'; // 用于 State, StatefulWidget, VoidCallback

/// 一个用于在挂载的窗口小部件上安全调用 setState 的 mixin。
import 'package:flutter/widgets.dart';

mixin StateAble<T extends StatefulWidget> on State<T> {
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
}


extension MediaQueryDataExtension on MediaQueryData {
  /// 基于当前策略适配 MediaQueryData
  MediaQueryData design() {
    final utils = ScreenSizeUtils.instance;
    final config = utils.currentConfig;

    // 1. 获取缩放比
    // 注意：这里的 devicePixelRatio 是系统原始的（来自 this）
    final double currentScale = config.dpr / devicePixelRatio;

    // 2. 如果缩放比为 1，无需处理
    if (currentScale == 1.0 && !config.isExpanded) {
      return this;
    }

    return copyWith(
      // 逻辑尺寸按比例缩小（例如：物理像素不变，DPR变大，则逻辑尺寸变小）
      size: size / currentScale,

      // 直接强制使用策略计算出的目标 DPR
      devicePixelRatio: config.dpr,

      // 所有的边距（Insets, Padding）都是逻辑像素，也需要同步缩放
      viewInsets: viewInsets / currentScale,
      viewPadding: viewPadding / currentScale,
      padding: padding / currentScale,
    );
  }
}