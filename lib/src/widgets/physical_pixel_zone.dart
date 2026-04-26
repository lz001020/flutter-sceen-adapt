/// PhysicalPixelZone keeps its child in physical-pixel semantics.
library screen_adapt_physical_pixel_zone;

import 'package:flutter/cupertino.dart';

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
