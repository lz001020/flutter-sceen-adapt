import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_scale/design_scale.dart';

void main() {
  test('public entry contains only the supported core API', () {
    final entry = File('lib/design_scale.dart').readAsStringSync();
    expect(entry, isNot(contains('widgets/')));
    expect(entry, isNot(contains('screen_metrics.dart')));
    expect(
      Directory('lib')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .length,
      1,
    );
    final controller = AdaptController(
      config: const AdaptConfig(
        designSize: Size(375, 667),
        adaptType: ScreenAdaptType.width,
      ),
    );
    addTearDown(controller.dispose);
    AdaptMetrics? metrics = controller.metrics;
    expect(metrics, isNull);
    controller.setEnabled(false);
    controller.setDesignSize(const Size(320, 568));
    expect(controller.enabled, isTrue);
    expect(controller.config.designSize, const Size(320, 568));
    // Device injection was intentionally removed from the instance API.
    expect(
      () => (controller as dynamic).updateDeviceMetrics(null),
      throwsNoSuchMethodError,
    );
  });

  testWidgets('missing context reports a clear error', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(AdaptController.maybeOf(context), isNull);
          expect(AdaptController.read(context), isNull);
          expect(() => AdaptController.of(context), throwsFlutterError);
          return const SizedBox();
        },
      ),
    );
  });
}
