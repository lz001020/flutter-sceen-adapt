import 'package:flutter/widgets.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';

class UnscaledZone extends StatelessWidget {
  final Widget child;
  const UnscaledZone({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scale = ScreenSizeUtils.instance.scale;
    if (scale == 1.0) return child;

    return MediaQuery(
      data: MediaQueryData.fromView(View.of(context)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inv = 1.0 / scale;
          return ConstrainedBox(
            constraints: constraints.copyWith(
              minWidth: constraints.minWidth * inv,
              maxWidth: constraints.maxWidth * inv,
              minHeight: constraints.minHeight * inv,
              maxHeight: constraints.maxHeight * inv,
            ),
            child: child,
          );
        },
      ),
    );
  }
}