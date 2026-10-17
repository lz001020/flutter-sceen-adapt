// Simulator core checks with the real binding; pointer packets are injected.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:design_scale/design_scale.dart';

const runId = String.fromEnvironment('REGRESSION_RUN');
const conflict = bool.fromEnvironment('REGRESSION_CONFLICT');
void emit(String type, Map<String, Object?> data) => debugPrintSynchronously(
  '[screen_adapt:ios] ${jsonEncode({'run': runId, 'type': type, ...data})}',
);
void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  if (conflict) {
    final original = WidgetsFlutterBinding.ensureInitialized();
    final handler = ui.PlatformDispatcher.instance.onPointerDataPacket;
    try {
      var rejected = false;
      try {
        DesignSizeWidgetsFlutterBinding.ensureInitialized(const Size(375, 667));
      } on FlutterError {
        rejected = true;
      }
      check(rejected, 'Foreign binding was accepted');
      check(identical(original, WidgetsBinding.instance), 'Binding replaced');
      check(
        identical(handler, ui.PlatformDispatcher.instance.onPointerDataPacket),
        'Pointer handler replaced',
      );
      runApp(const MaterialApp(home: Scaffold(body: Text('Conflict PASS'))));
      emit('done', {
        'checks': ['foreign-binding-rejected'],
      });
    } catch (error, stack) {
      emit('failure', {'error': '$error', 'stack': '$stack'});
    }
    return;
  }
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    type: ScreenAdaptType.width,
  );
  FlutterError.onError = (details) => emit('failure', {
    'error': details.exceptionAsString(),
    'stack': '${details.stack}',
  });
  runApp(const MaterialApp(home: SimulatorChecks()));
}

class SimulatorChecks extends StatefulWidget {
  const SimulatorChecks({super.key});
  @override
  State<SimulatorChecks> createState() => _SimulatorChecksState();
}

class _SimulatorChecksState extends State<SimulatorChecks> {
  final target = GlobalKey();
  late AdaptController controller;
  late MediaQueryData observed;
  final checks = <String>[];
  int taps = 0;
  int device = 0;
  ui.FlutterView get view => ui.PlatformDispatcher.instance.implicitView!;
  void passed(String name) {
    checks.add(name);
    emit('check', {'name': name});
  }

  Future<void> settle() async {
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  void snapshot() {
    check(observed == controller.metrics!.adapted, 'Root metrics differ');
    final dpr = observed.devicePixelRatio;
    check(
      (observed.size.width * dpr - view.physicalSize.width).abs() < 1,
      'Physical width differs',
    );
    check(
      (observed.size.height * dpr - view.physicalSize.height).abs() < 1,
      'Physical height differs',
    );
    check(
      WidgetsBinding
              .instance
              .renderViews
              .single
              .configuration
              .devicePixelRatio ==
          dpr,
      'Rendering DPR differs',
    );
    final origin = MediaQueryData.fromView(view);
    check(
      (observed.padding.top * dpr -
                  origin.padding.top * origin.devicePixelRatio)
              .abs() <
          1,
      'Safe area mapping differs',
    );
    emit('metrics', {
      'physicalWidth': view.physicalSize.width,
      'physicalHeight': view.physicalSize.height,
      'logicalWidth': observed.size.width,
      'dpr': dpr,
      'topPadding': observed.padding.top,
    });
  }

  void tap(Offset logical) {
    final physical = logical * observed.devicePixelRatio;
    device++;
    for (final change in [
      ui.PointerChange.add,
      ui.PointerChange.down,
      ui.PointerChange.up,
      ui.PointerChange.remove,
    ]) {
      ui.PlatformDispatcher.instance.onPointerDataPacket!(
        ui.PointerDataPacket(
          data: [
            ui.PointerData(
              viewId: view.viewId,
              device: device,
              change: change,
              kind: ui.PointerDeviceKind.touch,
              physicalX: physical.dx,
              physicalY: physical.dy,
              buttons: change == ui.PointerChange.down ? 1 : 0,
            ),
          ],
        ),
      );
    }
  }

  Future<void> runChecks() async {
    try {
      final original = WidgetsBinding.instance;
      final originalController = controller;
      final handler = ui.PlatformDispatcher.instance.onPointerDataPacket;
      final repeated = DesignSizeWidgetsFlutterBinding.ensureInitialized(
        const Size(375, 667),
        type: ScreenAdaptType.width,
      );
      await settle();
      check(
        identical(original, repeated) &&
            identical(controller, originalController),
        'Repeated initialization replaced binding/controller',
      );
      check(
        identical(handler, ui.PlatformDispatcher.instance.onPointerDataPacket),
        'Repeated initialization replaced handler',
      );
      passed('repeat-initialization');
      for (final width in [320.0, 375.0, 768.0]) {
        controller.setDesignSize(Size(width, 667));
        await settle();
        snapshot();
        check(
          (observed.size.width - width).abs() < 0.1,
          'Design width differs',
        );
        passed('design-${width.toInt()}');
        final box = target.currentContext!.findRenderObject()! as RenderBox;
        final before = taps;
        tap(box.localToGlobal(const Offset(79, 47)));
        await settle();
        check(taps == before + 1, 'Inside edge tap missed');
        tap(box.localToGlobal(const Offset(84, 24)));
        await settle();
        check(taps == before + 1, 'Outside tap counted');
        passed('injected-pointer-${width.toInt()}');
      }
      controller.setEnabled(false);
      await settle();
      snapshot();
      check(
        observed == MediaQueryData.fromView(view),
        'Disable metrics differ',
      );
      passed('disabled');
      controller.setEnabled(true);
      await settle();
      snapshot();
      passed('enabled');
      controller.configure(
        controller.config.copyWith(supportSystemTextScale: false),
      );
      await settle();
      check(observed.textScaler.scale(16) == 16, 'Font ignore differs');
      passed('font-ignore');
      controller.configure(controller.config.copyWith(scaleText: false));
      await settle();
      check(
        (observed.textScaler.scale(16) * controller.metrics!.scale - 16).abs() <
            0.01,
        'Font compensation differs',
      );
      passed('font-compensation');
      emit('done', {'checks': checks});
    } catch (error, stack) {
      emit('failure', {'error': '$error', 'stack': '$stack', 'checks': checks});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => runChecks());
  }

  @override
  Widget build(BuildContext context) {
    controller = AdaptController.of(context);
    observed = MediaQuery.of(context);
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: () => taps++,
            child: Container(
              key: target,
              width: 80,
              height: 48,
              color: Colors.orange,
              child: const Text('iOS checks'),
            ),
          ),
        ),
      ),
    );
  }
}
