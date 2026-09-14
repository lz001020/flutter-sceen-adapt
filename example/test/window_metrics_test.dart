import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('window metrics remain valid across rotation and restore',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('窗口与横竖屏'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PASS：窗口指标有效'), findsOneWidget);
    for (final size in [
      Size.zero,
      const Size(812, 375),
      const Size(375, 812),
      const Size(1024, 768),
      const Size(375, 812),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      if (size != Size.zero) {
        expect(find.textContaining('PASS：窗口指标有效'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
