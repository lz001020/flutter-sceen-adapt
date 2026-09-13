import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_adapt/screen_adapt.dart';
import 'package:screen_adapt/src/core/adapt_scope.dart';

void main() {
  testWidgets(
      'nested full zones survive runtime scale changes without double scaling',
      (tester) async {
    final key = GlobalKey();
    var taps = 0;
    for (final scale in [0.5, 2.0, 1.0, 0.5]) {
      const origin = MediaQueryData(size: Size(400, 800), devicePixelRatio: 2);
      final adapted = origin.copyWith(
          size: origin.size / scale, devicePixelRatio: 2 * scale);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: adapted,
        child: AdaptScope(
          state: AdaptScopeState(
              scale: scale,
              originMediaQuery: origin,
              adaptedMediaQuery: adapted),
          child: Align(
              alignment: Alignment.topLeft,
              child: UnscaledZone(
                  mode: UnscaledZoneMode.full,
                  child: UnscaledZone(
                      mode: UnscaledZoneMode.full,
                      child: GestureDetector(
                          onTap: () => taps++,
                          child: Container(
                              key: key,
                              width: 80,
                              height: 48,
                              color: Colors.blue))))),
        ),
      )));
      final box = key.currentContext!.findRenderObject()! as RenderBox;
      final width = (box.localToGlobal(const Offset(80, 0)) -
              box.localToGlobal(Offset.zero))
          .distance;
      expect(width * adapted.devicePixelRatio, closeTo(160, 0.01));
      final before = taps;
      await tester.tapAt(box.localToGlobal(const Offset(79, 47)));
      expect(taps, before + 1);
    }
  });
  for (final scale in [0.5, 1.0, 2.0]) {
    for (final mode in UnscaledZoneMode.values) {
      testWidgets('$mode scale=$scale preserves original visual size',
          (tester) async {
        final childKey = GlobalKey();
        final markerKey = GlobalKey();
        var taps = 0;
        const origin =
            MediaQueryData(size: Size(400, 800), devicePixelRatio: 2);
        final adapted = origin.copyWith(
            size: origin.size / scale, devicePixelRatio: 2 * scale);
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: adapted,
          child: AdaptScope(
            state: AdaptScopeState(
                scale: scale,
                originMediaQuery: origin,
                adaptedMediaQuery: adapted),
            child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UnscaledZone(
                          mode: mode,
                          child: GestureDetector(
                              onTap: () => taps++,
                              child: Container(
                                  key: childKey,
                                  width: 80,
                                  height: 48,
                                  color: Colors.blue))),
                      SizedBox(key: markerKey, width: 2, height: 48),
                    ])),
          ),
        )));
        final box = childKey.currentContext!.findRenderObject()! as RenderBox;
        final marker =
            markerKey.currentContext!.findRenderObject()! as RenderBox;
        final start = box.localToGlobal(Offset.zero);
        final width = (box.localToGlobal(const Offset(80, 0)) - start).dx;
        // Logical width × effective DPR must equal the original physical width.
        expect(width * adapted.devicePixelRatio,
            closeTo(80 * origin.devicePixelRatio, 0.01));
        expect(marker.localToGlobal(Offset.zero).dx - start.dx,
            closeTo(mode == UnscaledZoneMode.full ? 80 / scale : 80, 0.01));
        expect(MediaQuery.of(childKey.currentContext!).devicePixelRatio,
            origin.devicePixelRatio);
        for (final point in [
          const Offset(1, 1),
          const Offset(40, 24),
          const Offset(79, 47)
        ]) {
          final global = box.localToGlobal(point);
          // contextFallback intentionally retains the parent's unscaled hit bounds.
          final expectedHit = mode == UnscaledZoneMode.full ||
              (point.dx / scale < 80 && point.dy / scale < 48);
          final before = taps;
          await tester.tapAt(global);
          expect(taps, before + (expectedHit ? 1 : 0), reason: 'point=$point');
        }
        final before = taps;
        await tester.tapAt(box.localToGlobal(const Offset(81, 49)));
        expect(taps, before);
      });
    }
  }
}
