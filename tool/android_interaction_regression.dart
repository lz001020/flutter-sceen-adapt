// Device-only regression entry point, hosted by demo in profile/release.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:design_scale/design_scale.dart';

const _run = String.fromEnvironment('REGRESSION_RUN');
const _iosNative = bool.fromEnvironment('IOS_NATIVE_REGRESSION');
final _nativeState = ValueNotifier<String>('waiting');
int _sequence = 0;
void emit(String type, Map<String, Object?> data) {
  final encoded = jsonEncode({
    'run': _run,
    'type': type,
    'timeMs': DateTime.now().millisecondsSinceEpoch,
    ...data,
  });
  debugPrintSynchronously('[screen_adapt:regression] $encoded');
  if (_iosNative && ['action', 'done', 'failure'].contains(type)) {
    _nativeState.value = encoded;
  }
}

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> waitFor(bool Function() condition, String description) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out: $description');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await Future<void>.delayed(const Duration(milliseconds: 350));
}

void request(String action, [Map<String, Object?> data = const {}]) =>
    emit('action', {
      'id': ++_sequence,
      'action': action,
      ...data,
      if (_iosNative)
        'physicalWidth':
            ui.PlatformDispatcher.instance.implicitView!.physicalSize.width,
      if (_iosNative)
        'physicalHeight':
            ui.PlatformDispatcher.instance.implicitView!.physicalSize.height,
    });

void main() {
  check(_run.isNotEmpty, 'REGRESSION_RUN must be supplied by the host script.');
  check(
    kProfileMode ||
        kReleaseMode ||
        (_iosNative && defaultTargetPlatform == TargetPlatform.iOS),
    'Use profile/release, or iOS native simulator regression.',
  );
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    type: ScreenAdaptType.width,
  );
  FlutterError.onError = (details) => emit('failure', {
        'error': details.exceptionAsString(),
        'stack': '${details.stack}',
      });
  runApp(
    const MaterialApp(home: PopScope(canPop: false, child: RegressionPage())),
  );
}

class RegressionPage extends StatefulWidget {
  const RegressionPage({super.key});
  @override
  State<RegressionPage> createState() => _RegressionPageState();
}

class _RegressionPageState extends State<RegressionPage> {
  final targets = List.generate(3, (_) => GlobalKey());
  final dragKey = GlobalKey();
  final fieldKey = GlobalKey();
  final focus = FocusNode();
  final text = TextEditingController();
  final taps = [0, 0, 0];
  final checks = <String>[];
  late AdaptController controller;
  late MediaQueryData observed;
  Offset? pointerDown;
  final pointerTrace = <String>[];
  double drag = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(recordPointer);
    WidgetsBinding.instance.addPostFrameCallback((_) => runRegression());
  }

  void recordPointer(PointerEvent event) {
    if (event is PointerDownEvent) pointerDown = event.position;
    if (event is PointerDownEvent || event is PointerUpEvent) {
      pointerTrace.add(
        '${event is PointerDownEvent ? 'down' : 'up'} '
        'pointer=${event.pointer} x=${event.position.dx} y=${event.position.dy}',
      );
      emit('pointer', {'event': pointerTrace.last});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.pointerRouter.removeGlobalRoute(recordPointer);
    focus.dispose();
    text.dispose();
    super.dispose();
  }

  ui.FlutterView get view => ui.PlatformDispatcher.instance.implicitView!;
  MediaQueryData get origin => MediaQueryData.fromView(view);
  Rect rect(GlobalKey key) {
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void passed(String name) {
    checks.add(name);
    emit('check', {'name': name, 'result': 'pass'});
  }

  Future<void> settle() async {
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  void snapshot() {
    final metrics = controller.metrics!;
    final dpr = observed.devicePixelRatio;
    check(
      observed == metrics.adapted,
      'Root MediaQuery differs from snapshot.',
    );
    check(dpr.isFinite && dpr > 0, 'Invalid adapted DPR.');
    check(
      (observed.size.width * dpr - view.physicalSize.width).abs() < 1 &&
          (observed.size.height * dpr - view.physicalSize.height).abs() < 1,
      'Logical size does not map to the physical view.',
    );
    check(
      WidgetsBinding
              .instance.renderViews.single.configuration.devicePixelRatio ==
          dpr,
      'Rendering DPR differs from root MediaQuery.',
    );
    for (final inset in [
      [observed.viewInsets.bottom, origin.viewInsets.bottom],
      [observed.viewPadding.bottom, origin.viewPadding.bottom],
      [observed.padding.top, origin.padding.top],
    ]) {
      check(
        (inset[0] * dpr - inset[1] * origin.devicePixelRatio).abs() < 1,
        'Inset physical mapping differs.',
      );
    }
  }

  Future<void> tapAt(Offset logical, bool Function() done) async {
    pointerDown = null;
    pointerTrace.clear();
    final physical = logical * observed.devicePixelRatio;
    request('tap', {'x': physical.dx.round(), 'y': physical.dy.round()});
    await waitFor(
      () => pointerDown != null && done(),
      'physical tap x=${physical.dx} y=${physical.dy}',
    ).catchError((Object error) {
      throw StateError(
        '$error; dpr=${observed.devicePixelRatio} taps=$taps '
        'trace=$pointerTrace',
      );
    });
    check(
      (pointerDown! - logical).distance < 1.5,
      'Physical tap mapped to an unexpected logical position: '
      'expected=$logical actual=$pointerDown dpr=${observed.devicePixelRatio} trace=$pointerTrace.',
    );
  }

  Future<void> pointers(String label) async {
    for (var i = 0; i < 3; i++) {
      final before = List<int>.of(taps);
      await tapAt(rect(targets[i]).center, () => taps[i] == before[i] + 1);
      for (var j = 0; j < 3; j++) {
        check(taps[j] == before[j] + (i == j ? 1 : 0), 'Wrong target tapped.');
      }
    }
    var before = taps[0];
    final target = rect(targets[0]);
    await tapAt(
      Offset(target.right - 2, target.center.dy),
      () => taps[0] == before + 1,
    );
    before = taps[0];
    await tapAt(Offset(target.right + 4, target.center.dy), () => true);
    check(taps[0] == before, 'Tap outside target counted.');
    passed('pointers-$label');
  }

  Future<void> keyboard(String label) async {
    await tapAt(rect(fieldKey).center, () => focus.hasFocus);
    await waitFor(
      () => origin.viewInsets.bottom > 0 && observed.viewInsets.bottom > 0,
      'native keyboard opens',
    );
    await settleKeyboardMetrics();
    snapshot();
    final visibleBottom = observed.size.height - observed.viewInsets.bottom;
    check(
      rect(fieldKey).bottom <= visibleBottom + 1,
      'Keyboard covers the field.',
    );
    text.clear();
    request('text', {'text': 'regression'});
    await waitFor(
      () => text.text == 'regression',
      'native keyboard text input',
    );
    request('back');
    await waitFor(
      () => origin.viewInsets.bottom == 0 && observed.viewInsets.bottom == 0,
      'native keyboard closes',
    );
    focus.unfocus();
    await settle();
    snapshot();
    passed('keyboard-$label');
  }

  // Native IME animation may update the controller between a platform event
  // and the next widget frame. Assert the snapshot after insets stay stable
  // across rendered frames; a persistent mismatch still fails by timeout.
  Future<void> settleKeyboardMetrics() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    MediaQueryData? previous;
    var stableFrames = 0;
    while (DateTime.now().isBefore(deadline)) {
      WidgetsBinding.instance.ensureVisualUpdate();
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 20),
      );
      final current = origin;
      if (current == previous && observed == controller.metrics?.adapted) {
        stableFrames++;
        if (stableFrames >= 3) return;
      } else {
        stableFrames = 0;
      }
      previous = current;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('Keyboard metrics did not stabilize across frames.');
  }

  Future<void> runRegression() async {
    try {
      emit('ready', {'mode': kReleaseMode ? 'release' : 'profile'});
      await waitFor(
        () =>
            controller.metrics != null &&
            observed.size.height > observed.size.width,
        'portrait device metrics',
      );
      for (final width in [320.0, 375.0, 768.0]) {
        controller.setDesignSize(Size(width, 667));
        await settle();
        snapshot();
        check(
          (observed.size.width - width).abs() < 0.1,
          'Design width not applied.',
        );
        passed('design-${width.toInt()}');
        await pointers('design-${width.toInt()}');
      }
      controller.setEnabled(false);
      await settle();
      snapshot();
      check(observed == origin, 'Disable did not restore origin metrics.');
      passed('disabled');
      await pointers('disabled');
      controller.setEnabled(true);
      controller.setDesignSize(const Size(375, 667));
      await settle();
      snapshot();
      passed('enabled');

      final area = rect(dragKey);
      drag = 0;
      final start =
          Offset(area.left + 25, area.center.dy) * observed.devicePixelRatio;
      final end =
          Offset(area.right - 25, area.center.dy) * observed.devicePixelRatio;
      request('swipe', {
        'x1': start.dx.round(),
        'y1': start.dy.round(),
        'x2': end.dx.round(),
        'y2': end.dy.round(),
      });
      await waitFor(() => drag > 30, 'native drag gesture');
      passed('drag');
      await keyboard('portrait');

      request('rotation', {'value': 1});
      await waitFor(
        () =>
            origin.size.width > origin.size.height &&
            observed.size.width > observed.size.height,
        'landscape rotation',
      );
      if (_iosNative) {
        // UIKit metrics arrive before the scene rotation animation completes.
        await Future<void>.delayed(const Duration(seconds: 2));
        await settle();
      }
      snapshot();
      passed('landscape');
      await pointers('landscape');
      await keyboard('landscape');
      request('rotation', {'value': 0});
      await waitFor(
        () =>
            origin.size.height > origin.size.width &&
            observed.size.height > observed.size.width,
        'portrait rotation restore',
      );
      snapshot();
      passed('portrait-restored');

      if (!_iosNative) {
        request('font', {'value': 1.5});
        await waitFor(
          () =>
              origin.textScaler.scale(16) > 16.5 &&
              observed.textScaler.scale(16) > 16.5,
          'system font enlargement',
        );
        snapshot();
        check(
          (observed.textScaler.scale(16) - origin.textScaler.scale(16)).abs() <
              0.01,
          'System font scale not followed.',
        );
        passed('font-follow');
      }
      controller.configure(
        controller.config.copyWith(supportSystemTextScale: false),
      );
      await settle();
      check(
        observed.textScaler.scale(16) == 16,
        'System font scale not disabled.',
      );
      passed('font-ignore');
      controller.configure(controller.config.copyWith(scaleText: false));
      await settle();
      check(
        (observed.textScaler.scale(16) * controller.metrics!.scale - 16).abs() <
            0.01,
        'Physical font size not compensated.',
      );
      passed('font-compensation');
      controller.configure(
        controller.config.copyWith(
          scaleText: true,
          supportSystemTextScale: true,
        ),
      );
      if (!_iosNative) {
        request('font', {'value': 1.0});
        await waitFor(
          () =>
              origin.textScaler.scale(16) == 16 &&
              observed.textScaler.scale(16) == 16,
          'system font normal size',
        );
        snapshot();
        passed('font-normal');
      }
      emit('done', {'checks': checks});
    } catch (error, stack) {
      emit('failure', {'error': '$error', 'stack': '$stack', 'checks': checks});
    }
  }

  @override
  Widget build(BuildContext context) {
    controller = AdaptController.of(context);
    observed = MediaQuery.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            if (_iosNative)
              Positioned(
                top: 0,
                left: 0,
                child: ValueListenableBuilder<String>(
                  valueListenable: _nativeState,
                  builder: (context, value, child) => Semantics(
                    identifier: 'regression-state',
                    label: 'Regression state',
                    value: value,
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (i) => GestureDetector(
                    onTap: () => taps[i]++,
                    child: Container(
                      key: targets[i],
                      width: 56,
                      height: 48,
                      color: Colors.orange,
                      alignment: Alignment.center,
                      child: Text('ABC'[i]),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 75,
              left: 10,
              right: 10,
              child: GestureDetector(
                onHorizontalDragUpdate: (event) => drag += event.delta.dx,
                child: Container(key: dragKey, height: 55, color: Colors.blue),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: TextField(
                key: fieldKey,
                focusNode: focus,
                controller: text,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => focus.unfocus(),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
