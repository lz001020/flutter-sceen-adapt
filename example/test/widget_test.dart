import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customize an order and confirm the selected values',
      (tester) async {
    await tester.pumpWidget(const CoffeeApp());
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
            .onPressed,
        isNull);
    await tester.tap(find.text('冰饮'));
    await tester.tap(find.byTooltip('增加数量'));
    await tester.enterText(find.byType(TextField), '少冰');
    final confirm = find.text('确认订单 · ¥56');
    await tester.scrollUntilVisible(confirm, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('燕麦拿铁 · 冰饮 × 2\n合计 ¥56\n备注：少冰'), findsOneWidget);
    await tester.tap(find.text('返回菜单'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form remains reachable with large text and keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const CoffeeApp());
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), '带走');
    final confirm = find.text('确认订单 · ¥28');
    await tester.scrollUntilVisible(confirm, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
