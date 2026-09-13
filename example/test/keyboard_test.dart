import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('keyboard opens, resizes, closes and restores bottom field',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('键盘与安全区'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    final closed = tester.getRect(field);
    expect(closed.bottom, lessThanOrEqualTo(788));
    await tester.tap(field);
    await tester.enterText(field, 'keyboard test');
    for (final height in [260.0, 320.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: height);
      tester.view.padding = const FakeViewPadding(top: 24);
      await tester.pumpAndSettle();
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(812 - height));
      expect(find.textContaining('PASS 输入框可见；PASS 底部 Insets 映射；键盘打开'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    await tester.pumpAndSettle();
    expect(tester.getRect(field), closed);
    await tester.tap(find.byTooltip('重置记录'));
    await tester.pumpAndSettle();
    expect(find.text('keyboard test'), findsNothing);
    expect(find.textContaining('键盘收起'), findsOneWidget);
    tester.view.physicalSize = const Size(812, 375);
    tester.view.viewPadding =
        const FakeViewPadding(left: 24, right: 24, bottom: 16);
    tester.view.padding =
        const FakeViewPadding(left: 24, right: 24, bottom: 16);
    tester.view.viewInsets = const FakeViewPadding(bottom: 150);
    await tester.pumpAndSettle();
    final landscape = tester.getRect(field);
    expect(landscape.left, greaterThanOrEqualTo(24));
    expect(landscape.right, lessThanOrEqualTo(788));
    expect(landscape.bottom, lessThanOrEqualTo(225));
    expect(tester.takeException(), isNull);
  });
}
