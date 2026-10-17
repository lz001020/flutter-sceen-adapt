import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_scale/design_scale.dart';

class DeviceDispatcher extends TestPlatformDispatcher {
  DeviceDispatcher()
      : super(platformDispatcher: ui.PlatformDispatcher.instance);
  bool missing = false;
  @override
  TestFlutterView? get implicitView => missing ? null : super.implicitView;
}

class DeviceBinding extends WidgetsFlutterBinding with DesignSizeBindingMixin {
  static final device = DeviceDispatcher();
  @override
  DeviceDispatcher get platformDispatcher => device;
}

void main() {
  test(
    'binding reads metrics, font changes, invalid inputs and view removal',
    () async {
      DesignSizeBindingMixin.configure(designSize: const Size(200, 400));
      final binding = DeviceBinding();
      final dispatcher = DeviceBinding.device;
      final view = dispatcher.implicitView!;
      view.devicePixelRatio = 2;
      view.physicalSize = const Size(800, 1600);
      late AdaptController controller;
      late MediaQueryData observed;
      runApp(
        Builder(
          builder: (context) {
            controller = AdaptController.of(context);
            observed = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      );
      Future<void> frame() async {
        binding.scheduleWarmUpFrame();
        await binding.endOfFrame;
      }

      await frame();
      expect(controller.metrics!.scale, 2);
      final first = controller.metrics;
      var calls = 0;
      controller.addListener(() => calls++);
      binding.handleMetricsChanged();
      expect(controller.metrics, same(first));
      expect(calls, 0);

      view.viewInsets = const FakeViewPadding(bottom: 400);
      await frame();
      expect(observed.viewInsets.bottom, 100);
      expect(observed, controller.metrics!.adapted);
      expect(
        binding.renderViews.single.configuration.devicePixelRatio,
        observed.devicePixelRatio,
      );
      dispatcher.textScaleFactorTestValue = 1.6;
      await frame();
      expect(observed.textScaler.scale(20), closeTo(32, 0.001));

      controller.setEnabled(false);
      view.physicalSize = const Size(1600, 800);
      await frame();
      expect(observed.size, const Size(800, 400));
      expect(observed, controller.metrics!.origin);
      controller.setEnabled(true);
      await frame();
      expect(controller.metrics!.scale, 2);
      expect(observed.size, const Size(400, 200));

      final valid = controller.metrics;
      view.physicalSize = Size.zero;
      expect(controller.metrics, same(valid));
      view.physicalSize = const Size(1600, 800);
      view.devicePixelRatio = 0;
      expect(controller.metrics, same(valid));
      view.devicePixelRatio = 2;
      dispatcher.missing = true;
      binding.handleMetricsChanged();
      expect(controller.metrics, isNull);
      dispatcher.missing = false;
      binding.handleMetricsChanged();
      await frame();
      expect(controller.metrics!.scale, 2);
      expect(observed, controller.metrics!.adapted);
      runApp(const SizedBox());
      await frame();
    },
  );
}
