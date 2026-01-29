/// component/physical_pixel_zone.dart
///
/// Created by longzhi on 2024/7/29
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
    // 1. 获取当前上下文的MediaQueryData
    //    这里使用MediaQuery.of(context)而不是全局的原始数据，
    //    是为了让PhysicalPixelZone可以嵌套在UnscaledZone或适配区内都能正常工作。
    final mediaQueryData = MediaQuery.of(context);

    // 2. 获取设备像素比 (DPR)
    final dpr = mediaQueryData.devicePixelRatio;

    // 如果dpr为1，说明1个逻辑像素正好等于1个物理像素，无需缩放。
    if (dpr == 1.0) {
      return child;
    }

    // 3. 计算缩放比例，即DPR的倒数
    final double scale = 1.0 / dpr;

    return Transform.scale(
      // 4. 进行缩放
      //    我们将子节点的所有逻辑尺寸都缩小dpr倍。
      //    当渲染引擎将这些逻辑尺寸转换为物理像素时 (乘以dpr)，
      //    (逻辑尺寸 * scale) * dpr = (逻辑尺寸 / dpr) * dpr = 逻辑尺寸
      //    这就实现了 1个逻辑单位 = 1个物理像素 的效果。
      scale: scale,
      // 5. 保证对齐方式为左上角，防止布局偏移
      alignment: Alignment.topLeft,
      child: child,
    );
  }
}
