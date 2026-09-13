import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets(
      'probe records inside and outside taps without swallowing gestures',
      (tester) async {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('UnscaledZone'));
      await tester.pumpAndSettle();
      final probe = find.byKey(const ValueKey('probe-normal'));
      await tester.ensureVisible(probe);
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(probe);
      for (final point in [
        const Offset(20, 20),
        const Offset(100, 20),
        const Offset(20, 60)
      ]) {
        await tester.tapAt(origin + point);
        await tester.pump();
      }
      final up = logs
          .where(
              (line) => line.contains('mode=normal') && line.contains(' up '))
          .toList();
      expect(up, hasLength(3));
      expect(up[0], contains('inside=true'));
      expect(up[0], contains('delta=1'));
      for (final line in up.skip(1)) {
        expect(line, contains('inside=false'));
        expect(line, contains('delta=0'));
      }
      expect(find.text('点击 1'), findsOneWidget);
    } finally {
      debugPrint = previous;
    }
  });
  testWidgets('navigate, record independent targets, reset, and inspect zones',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('指针与手势'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('target-$i')));
      await tester.pump();
      expect(find.text('${String.fromCharCode(65 + i)}: 1'), findsOneWidget);
    }
    await tester.drag(
        find.byKey(const ValueKey('drag-area')), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(find.text('横向拖动累计：0.0'), findsNothing);
    await tester.tap(find.byTooltip('重置记录'));
    await tester.pump();
    expect(find.text('A: 0'), findsOneWidget);
    expect(find.text('横向拖动累计：0.0'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('UnscaledZone'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PASS 几何'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
