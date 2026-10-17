import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  test('插件在 binding 初始化后覆盖回调会绕过适配 binding', () {
    DesignSizeWidgetsFlutterBinding.ensureInitialized(
      const Size(375, 812),
    );

    final adaptedCallback = PlatformDispatcher.instance.onPointerDataPacket;
    var pluginCalled = false;
    PlatformDispatcher.instance.onPointerDataPacket = (_) {
      pluginCalled = true;
    };

    PlatformDispatcher.instance.onPointerDataPacket?.call(
      const PointerDataPacket(data: <PointerData>[]),
    );

    expect(pluginCalled, isTrue);
    expect(
        identical(
            PlatformDispatcher.instance.onPointerDataPacket, adaptedCallback),
        isFalse);
  });
}
