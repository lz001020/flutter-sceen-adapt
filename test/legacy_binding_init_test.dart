import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:design_scale/design_scale.dart';

void main() {
  test('binding initializer creates once and reuses the existing instance', () {
    final binding = DesignSizeWidgetsFlutterBinding.ensureInitialized(
      const Size(375, 667),
    );
    expect(binding, isA<DesignSizeWidgetsFlutterBinding>());
    final pointerHandler = PlatformDispatcher.instance.onPointerDataPacket;
    final repeated = DesignSizeWidgetsFlutterBinding.ensureInitialized(
      const Size(390, 844),
      type: ScreenAdaptType.width,
    );
    expect(repeated, same(binding));
    expect(WidgetsBinding.instance, same(binding));
    expect(
      PlatformDispatcher.instance.onPointerDataPacket,
      same(pointerHandler),
    );
  });
}
