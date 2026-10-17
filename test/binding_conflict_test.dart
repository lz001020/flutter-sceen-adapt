import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:design_scale/design_scale.dart';

void main() {
  test('已有其他 binding 时明确报错', () {
    final existing = WidgetsFlutterBinding.ensureInitialized();
    final pointerHandler = existing.platformDispatcher.onPointerDataPacket;

    expect(
      () => DesignSizeWidgetsFlutterBinding.ensureInitialized(
        const Size(375, 812),
      ),
      throwsA(isA<FlutterError>()),
    );
    expect(WidgetsBinding.instance, same(existing));
    expect(
      existing.platformDispatcher.onPointerDataPacket,
      same(pointerHandler),
    );
  });
}
