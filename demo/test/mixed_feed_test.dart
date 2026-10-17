import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_scale_demo/performance/mixed_feed_content.dart';

double identity(double value) => value;

void main() {
  testWidgets('四类卡片在不同视口布局且展开增加内容高度', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 375.0, 768.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      for (var index = 0; index < 4; index++) {
        Future<double> render(bool expanded) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MixedFeedCard(
                    key: const ValueKey('card'),
                    index: index,
                    scale: identity,
                    font: identity,
                    expanded: expanded,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          return tester.getSize(find.byKey(const ValueKey('card'))).height;
        }

        final collapsed = await render(false);
        final expanded = await render(true);
        if (index != 3) {
          expect(expanded, greaterThan(collapsed));
        } else {
          expect(expanded, collapsed);
        }
      }
    }
  });
}
