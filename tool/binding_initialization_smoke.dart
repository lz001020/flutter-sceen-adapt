// Run each scenario in a fresh process, using flutter_tester with assertions
// disabled or an Android/iOS profile/release build.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:design_scale/design_scale.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  const scenario = String.fromEnvironment(
    'SCREEN_ADAPT_BINDING_SMOKE_CASE',
    defaultValue: '',
  );
  final selectedScenario = scenario.isEmpty
      ? Platform.environment['SCREEN_ADAPT_BINDING_SMOKE_CASE'] ?? 'repeat'
      : scenario;
  const runId = String.fromEnvironment(
    'SCREEN_ADAPT_BINDING_SMOKE_RUN',
    defaultValue: 'local',
  );
  const mode = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';
  try {
    check(BindingBase.debugBindingType() == null, 'Expected a fresh process.');
    if (selectedScenario == 'conflict') {
      final existing = WidgetsFlutterBinding.ensureInitialized();
      check(
        BindingBase.debugBindingType() == null,
        'Run this smoke test with --disable-dart-asserts.',
      );
      final handler = PlatformDispatcher.instance.onPointerDataPacket;
      var rejected = false;
      try {
        DesignSizeWidgetsFlutterBinding.ensureInitialized(const Size(375, 667));
      } on FlutterError {
        rejected = true;
      }
      check(rejected, 'An existing foreign binding must be rejected.');
      check(identical(WidgetsBinding.instance, existing), 'Binding replaced.');
      check(
        identical(PlatformDispatcher.instance.onPointerDataPacket, handler),
        'Pointer handler replaced.',
      );
    } else if (selectedScenario == 'repeat') {
      final binding = DesignSizeWidgetsFlutterBinding.ensureInitialized(
        const Size(375, 667),
      );
      check(
        BindingBase.debugBindingType() == null,
        'Run this smoke test with --disable-dart-asserts.',
      );
      final handler = PlatformDispatcher.instance.onPointerDataPacket;
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
      final originalController = controller;
      final repeated = DesignSizeWidgetsFlutterBinding.ensureInitialized(
        const Size(390, 844),
        type: ScreenAdaptType.width,
        scaleText: false,
        supportSystemTextScale: false,
      );
      check(
        identical(repeated, binding),
        'Repeated initialization recreated binding.',
      );
      check(
        identical(PlatformDispatcher.instance.onPointerDataPacket, handler),
        'Repeated initialization replaced pointer handler.',
      );
      binding.scheduleWarmUpFrame();
      await binding.endOfFrame;
      check(identical(controller, originalController), 'Controller replaced.');
      check(
        controller.config.designSize == const Size(390, 844),
        'Design size not updated.',
      );
      check(
        controller.config.adaptType == ScreenAdaptType.width &&
            !controller.config.scaleText &&
            !controller.config.supportSystemTextScale,
        'Configuration not updated.',
      );
      check(controller.metrics != null, 'Device metrics not available.');
      check(
        binding.renderViews.single.configuration.devicePixelRatio ==
            controller.metrics!.adapted.devicePixelRatio,
        'Render configuration does not match updated controller metrics.',
      );
    } else {
      throw ArgumentError.value(selectedScenario, 'scenario');
    }
    debugPrintSynchronously(
      'PASS binding initialization: $selectedScenario mode=$mode run=$runId (assertions disabled)',
    );
    exit(0);
  } catch (error, stack) {
    debugPrintSynchronously(
      'FAIL binding initialization: $selectedScenario mode=$mode run=$runId\n$error\n$stack',
    );
    exit(1);
  }
}
