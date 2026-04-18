import 'package:flutter/widgets.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';

/// 针对 PlatformView（如 WebView, Map, Video）的视觉对齐包装器。
///
/// 在当前 Android 示例环境中，PlatformView 视觉表现会偏大，
/// 这里采用“先缩小原生布局尺寸，再放大回父布局槽”的方式进行对齐：
/// 1. 给原生视图传入 w/scale × h/scale 的布局尺寸
/// 2. 再通过 Transform.scale(scale) 放大到 w×h
///
/// 这样可在示例中实现与 Flutter 布局槽一致的视觉填充效果。
class AdaptedPlatformView extends StatelessWidget {
  const AdaptedPlatformView({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double scale = ScreenSizeUtils.instance.scale;

    if (scale == 1.0) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double scaledWidth = width / scale;
        final double scaledHeight = height / scale;

        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: scaledWidth,
                height: scaledHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
