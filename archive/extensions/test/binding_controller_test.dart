import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  test('controller changes update render configuration without device events',
      () {
    final binding =
        DesignSizeWidgetsFlutterBinding.ensureInitialized(const Size(200, 400));
    final controller = ScreenSizeUtils.instance.controller;
    controller.updateDeviceMetrics(
        const MediaQueryData(size: Size(400, 800), devicePixelRatio: 2));
    final renderView =
        RenderView(view: PlatformDispatcher.instance.implicitView!);
    binding.addRenderView(renderView);
    addTearDown(() => binding.removeRenderView(renderView));
    // Legacy writes must not override the snapshot used by rendering/input.
    ScreenSizeUtils.instance.data = const MediaQueryData(devicePixelRatio: 99);
    ScreenSizeUtils.instance.scale = 99;
    controller.setDesignSize(const Size(100, 200));
    // The render configuration consumes the same snapshot as the root scope.
    expect(renderView.configuration.devicePixelRatio, 8);
    final events = <PointerEvent>[];
    void record(PointerEvent event) => events.add(event);
    binding.pointerRouter.addGlobalRoute(record);
    addTearDown(() => binding.pointerRouter.removeGlobalRoute(record));
    PlatformDispatcher.instance.onPointerDataPacket!(PointerDataPacket(data: [
      PointerData(
          change: PointerChange.add,
          physicalX: 80,
          physicalY: 40,
          viewId: renderView.flutterView.viewId),
    ]));
    expect(events.single.position, const Offset(10, 5));
    controller.reset();
    expect(renderView.configuration.devicePixelRatio, 2);
  });
}
