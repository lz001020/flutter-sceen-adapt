import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_adapt/screen_adapt.dart';
import 'package:screen_adapt/src/core/adapt_scope.dart';
import 'package:example/pages/text/text_scale_test_page.dart';

void main() {
  for (final followSystem in [false, true]) {
    testWidgets('font policy followSystem=$followSystem and full restoration',
        (tester) async {
      final utils = ScreenSizeUtils.instance;
      final oldFollow = utils.supportSystemTextScale;
      final oldScaleText = utils.scaleText;
      final oldScale = utils.scale;
      addTearDown(() {
        utils.supportSystemTextScale = oldFollow;
        utils.scaleText = oldScaleText;
        utils.scale = oldScale;
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      utils.supportSystemTextScale = followSystem;
      utils.scaleText = true;
      utils.scale = 0.8;
      for (final factor in [1.0, 1.6]) {
        tester.platformDispatcher.textScaleFactorTestValue = factor;
        final raw = MediaQueryData.fromView(tester.view);
        final adapted = raw.design();
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: adapted,
                child: AdaptScope(
                    state: AdaptScopeState(
                        scale: utils.scale,
                        originMediaQuery: raw,
                        adaptedMediaQuery: adapted),
                    child: const TextScaleTestPage()))));
        await tester.pumpAndSettle();
        final samples = tester.renderObjectList<RenderParagraph>(
            find.byWidgetPredicate((widget) =>
                widget is RichText &&
                widget.text.toPlainText().startsWith('屏幕适配测试')));
        expect(samples, hasLength(4));
        final list = samples.toList();
        expect(list[0].textScaler.scale(16),
            closeTo(16 * (followSystem ? factor : 1), 0.01));
        expect(list[1].textScaler.scale(28),
            closeTo(28 * (followSystem ? factor : 1), 0.01));
        expect(list[2].textScaler.scale(16), closeTo(16 * factor, 0.01));
        expect(list[3].textScaler.scale(28), closeTo(28 * factor, 0.01));
        expect(find.textContaining('PASS 字号映射'), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      }
    });
  }
}
