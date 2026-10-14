import 'package:flutter/widgets.dart';
import '../core/adapt_controller.dart';

/// Internal root; borrows the binding-owned controller without disposing it.
class AdaptRoot extends StatelessWidget {
  const AdaptRoot({super.key, required this.controller, required this.child});
  final AdaptController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => AdaptControllerScope(
    controller: controller,
    child: Builder(
      builder: (context) {
        final current = AdaptController.of(context);
        final data =
            current.metrics?.adapted ??
            MediaQuery.maybeOf(context) ??
            const MediaQueryData();
        return MediaQuery(data: data, child: child);
      },
    ),
  );
}
