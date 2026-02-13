/// Created by @YuAn on 2026/2/13 10:26.
/// Copyright © 2026 Mountain.

/// 定义屏幕适配的基准。
enum ScreenAdaptType {
  /// 基于屏幕宽度进行适配。
  width,

  /// 基于屏幕高度进行适配。
  height,

  /// 基于屏幕宽度和高度中的最小值进行适配。
  min,
}