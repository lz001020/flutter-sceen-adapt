
import 'dart:ui';

/// adaptation_config.dart
///
/// Created by @YuAn on 2026/2/13 10:04.
/// Copyright © 2026 Mountain. All rights reserved.
class AdaptationConfig {
  /// 适配后的设备像素比 (DPR)
  final double dpr;

  /// 手势修正位移 (逻辑像素)
  /// 当内容被居中或拖拽时，需要此偏移量来修正点击坐标
  final Offset gestureOffset;

  /// 是否处于展开/宽屏模式
  /// true: 会触发 UI 层的居中容器包裹逻辑
  /// false: 全屏铺满逻辑
  final bool isExpanded;

  const AdaptationConfig({
    required this.dpr,
    required this.gestureOffset,
    required this.isExpanded,
  });
}