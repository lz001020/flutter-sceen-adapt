/// component/physical_pixel_zone.dart
///
/// Created by longzhi on 2024/7/29
library screen_adapt_physical_pixel_zone;

import 'package:flutter/cupertino.dart';

// ==========================================================
// 物理像素精准控制组件 (PhysicalPixelZone)
// ==========================================================

/// 一个特殊的Widget，其子节点的尺寸单位将直接对应屏幕的物理像素。
///
/// 在这个Widget内部:
/// 1. `Container(width: 1)` 将会渲染为1物理像素宽。
/// 2. 字体大小也会被相应缩放，`TextStyle(fontSize: 16)` 渲染出来的
///    文字高度大约是16个物理像素高。
///
/// 这对于绘制精确的1px边框线、显示不允许缩放的图片（如二维码）等场景非常有用。
class PhysicalPixelZone extends StatelessWidget {
  const PhysicalPixelZone({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;

    if (dpr == 1.0) {
      return child;
    }

    // 逻辑：
    // - 父级给出约束 w×h（适配后逻辑像素）
    // - OverflowBox 放大约束为 w*dpr × h*dpr，供子节点以"物理像素"为单位布局
    // - Transform.scale(1/dpr) 将视觉输出缩回 w×h，与父级布局槽匹配
    // - ClipRect 裁剪防止溢出
    return LayoutBuilder(
      builder: (context, constraints) {
        final double physicalWidth = constraints.maxWidth * dpr;
        final double physicalHeight = constraints.maxHeight * dpr;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: physicalWidth,
              maxHeight: physicalHeight,
              child: Transform.scale(
                scale: 1.0 / dpr,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: physicalWidth,
                  height: physicalHeight,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
