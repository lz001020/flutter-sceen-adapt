import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  test('real binding keeps root metrics, rendering and input aligned',
      () async {
    final binding = DesignSizeWidgetsFlutterBinding.ensureInitialized(
      const Size(375, 667),
      type: ScreenAdaptType.width,
    );
    final view = ui.PlatformDispatcher.instance.implicitView!;
    final origin = MediaQueryData.fromView(view);
    final controller = ScreenSizeUtils.instance.controller;
    controller.updateDeviceMetrics(origin);
    final targetKey = GlobalKey();
    final fullKey = GlobalKey();
    late DesignSizeWidgetState actions;
    late MediaQueryData observed;
    var taps = 0;
    var fullTaps = 0;
    final errors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    Future<void> drawFrame() async {
      binding.scheduleWarmUpFrame();
      await binding.endOfFrame;
    }

    runApp(Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(builder: (context) {
        actions = DesignSize.of(context);
        observed = MediaQuery.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => taps++,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(key: targetKey, width: 80, height: 48),
            ),
            const SizedBox(width: 40),
            UnscaledZone(
              mode: UnscaledZoneMode.full,
              child: GestureDetector(
                onTap: () => fullTaps++,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(key: fullKey, width: 80, height: 48),
              ),
            ),
          ]),
        );
      }),
    ));
    await drawFrame();

    var device = 0;
    void tapPhysical(Offset position) {
      device++;
      for (final change in [
        ui.PointerChange.add,
        ui.PointerChange.down,
        ui.PointerChange.up,
        ui.PointerChange.remove
      ]) {
        ui.PlatformDispatcher.instance.onPointerDataPacket!(
          ui.PointerDataPacket(data: [
            ui.PointerData(
              viewId: view.viewId,
              device: device,
              change: change,
              kind: ui.PointerDeviceKind.touch,
              physicalX: position.dx,
              physicalY: position.dy,
              buttons: change == ui.PointerChange.down ? 1 : 0,
            )
          ]),
        );
      }
    }

    for (final width in [320.0, 375.0, 768.0]) {
      // This API notifies rendering and the root scope without a fake device event.
      actions.setDesignSize(Size(width, 667));
      await drawFrame();
      final metrics = actions.metrics!;
      final renderView = binding.renderViews.single;
      expect(observed, metrics.adapted);
      expect(
          renderView.configuration.devicePixelRatio, observed.devicePixelRatio);
      final effectiveWidth = origin.size.shortestSide / width;
      expect(metrics.scale, closeTo(effectiveWidth, 0.000001));
      final box = targetKey.currentContext!.findRenderObject()! as RenderBox;
      final before = taps;
      tapPhysical(
          box.localToGlobal(const Offset(79, 47)) * observed.devicePixelRatio);
      expect(taps, before + 1);
      tapPhysical(
          box.localToGlobal(const Offset(81, 49)) * observed.devicePixelRatio);
      expect(taps, before + 1);
      final fullBox = fullKey.currentContext!.findRenderObject()! as RenderBox;
      final fullWidth = (fullBox.localToGlobal(const Offset(80, 0)) -
                  fullBox.localToGlobal(Offset.zero))
              .dx *
          observed.devicePixelRatio;
      expect(fullWidth, closeTo(80 * origin.devicePixelRatio, 0.000001));
      final fullBefore = fullTaps;
      tapPhysical(fullBox.localToGlobal(const Offset(79, 47)) *
          observed.devicePixelRatio);
      expect(fullTaps, fullBefore + 1);
      tapPhysical(fullBox.localToGlobal(const Offset(81, 49)) *
          observed.devicePixelRatio);
      expect(fullTaps, fullBefore + 1);
    }
    actions.reset();
    await drawFrame();
    expect(observed, origin);
    expect(binding.renderViews.single.configuration.devicePixelRatio,
        origin.devicePixelRatio);
    expect(errors, isEmpty,
        reason: errors.map((e) => e.exceptionAsString()).join('\n'));
    runApp(const SizedBox());
    await drawFrame();
  });
}
