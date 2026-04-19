import 'package:flutter/widgets.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';

/// 针对 PlatformView（如 WebView, Map, Video）的视觉对齐包装器。
///
/// 以“当前 Flutter DPR / 原始 DPR”的比值作为补偿因子，
/// 保证无论适配基准是 width/height/min，PlatformView 都与当前坐标体系一致。
class AdaptedPlatformView extends StatelessWidget {
  const AdaptedPlatformView({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final origin = ScreenSizeUtils.instance.originData;
    final adapted = MediaQuery.of(context);

    final originDpr = origin?.devicePixelRatio ?? adapted.devicePixelRatio;
    final adaptedDpr = adapted.devicePixelRatio;

    if (originDpr == 0) return child;

    final factor = adaptedDpr / originDpr;

    if (factor == 1.0) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final childWidth = width / factor;
        final childHeight = height / factor;

        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: Transform.scale(
              scale: factor,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: childWidth,
                height: childHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
