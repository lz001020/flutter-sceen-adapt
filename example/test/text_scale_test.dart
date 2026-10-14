import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_scale/design_scale.dart';
import 'package:design_scale/src/core/adapt_controller.dart'
    show updateAdaptDeviceMetrics;
import 'package:design_scale/src/scope/adapt_scope.dart';
import 'package:example/pages/text/text_scale_test_page.dart';

void main() {
  for (final followSystem in [false, true]) {
    testWidgets('font policy followSystem=$followSystem', (tester) async {
      final controller = AdaptController(
          config: AdaptConfig(
              designSize: const Size(750, 1000),
              supportSystemTextScale: followSystem));
      addTearDown(controller.dispose);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final factor in [1.0, 1.6]) {
        tester.platformDispatcher.textScaleFactorTestValue = factor;
        final raw = MediaQueryData.fromView(tester.view);
        updateAdaptDeviceMetrics(controller, raw);
        await tester.pumpWidget(AdaptRoot(
            controller: controller,
            child: const MaterialApp(home: TextScaleTestPage())));
        await tester.pumpAndSettle();
        final samples = tester.renderObjectList<RenderParagraph>(
            find.byWidgetPredicate((widget) =>
                widget is RichText &&
                widget.text.toPlainText().startsWith('屏幕适配测试')));
        expect(samples, hasLength(2));
        final list = samples.toList();
        expect(list[0].textScaler.scale(16),
            closeTo(16 * (followSystem ? factor : 1), 0.01));
        expect(list[1].textScaler.scale(28),
            closeTo(28 * (followSystem ? factor : 1), 0.01));
        expect(find.textContaining('PASS 字号映射'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
