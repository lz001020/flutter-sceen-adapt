import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_scale/design_scale.dart';

void main() {
  test(
    'controller changes update render configuration without device events',
    () async {
      final binding = DesignSizeWidgetsFlutterBinding.ensureInitialized(
        const Size(200, 400),
      );
      late AdaptController controller;
      runApp(
        Builder(
          builder: (context) {
            controller = AdaptController.of(context);
            return const SizedBox();
          },
        ),
      );
      binding.scheduleWarmUpFrame();
      await binding.endOfFrame;
      final renderView = binding.renderViews.single;
      final originalController = controller;
      final pointerHandler = PlatformDispatcher.instance.onPointerDataPacket;
      final repeated = DesignSizeWidgetsFlutterBinding.ensureInitialized(
        const Size(150, 300),
        type: ScreenAdaptType.width,
        scaleText: false,
        supportSystemTextScale: false,
      );
      expect(repeated, same(binding));
      binding.scheduleWarmUpFrame();
      await binding.endOfFrame;
      expect(controller, same(originalController));
      expect(controller.config.designSize, const Size(150, 300));
      expect(controller.config.adaptType, ScreenAdaptType.width);
      expect(controller.config.scaleText, isFalse);
      expect(controller.config.supportSystemTextScale, isFalse);
      expect(
        PlatformDispatcher.instance.onPointerDataPacket,
        same(pointerHandler),
      );
      expect(
        renderView.configuration.devicePixelRatio,
        controller.metrics!.adapted.devicePixelRatio,
      );
      controller.setDesignSize(const Size(100, 200));
      final dpr = controller.metrics!.adapted.devicePixelRatio;
      expect(renderView.configuration.devicePixelRatio, dpr);
      final events = <PointerEvent>[];
      void record(PointerEvent event) => events.add(event);
      binding.pointerRouter.addGlobalRoute(record);
      addTearDown(() => binding.pointerRouter.removeGlobalRoute(record));
      PlatformDispatcher.instance.onPointerDataPacket!(
        PointerDataPacket(
          data: [
            PointerData(
              change: PointerChange.add,
              physicalX: 80,
              physicalY: 40,
              viewId: renderView.flutterView.viewId,
            ),
          ],
        ),
      );
      expect(events.single.position, Offset(80 / dpr, 40 / dpr));
      controller.setEnabled(false);
      expect(
        renderView.configuration.devicePixelRatio,
        controller.metrics!.origin.devicePixelRatio,
      );
      runApp(const SizedBox());
      binding.scheduleWarmUpFrame();
      await binding.endOfFrame;
    },
  );
}
