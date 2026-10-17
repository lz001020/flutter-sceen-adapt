import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:design_scale/design_scale.dart';

void main() {
  test('保留 binding 初始化前注册的指针回调', () {
    var called = false;
    PlatformDispatcher.instance.onPointerDataPacket = (_) {
      called = true;
    };

    DesignSizeWidgetsFlutterBinding.ensureInitialized(const Size(375, 812));

    PlatformDispatcher.instance.onPointerDataPacket?.call(
      const PointerDataPacket(data: <PointerData>[]),
    );

    expect(called, isTrue);
  });
}
