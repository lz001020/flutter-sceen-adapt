import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  test('binding initializer does not read instance before creation', () {
    final binding = DesignSizeWidgetsFlutterBinding.ensureInitialized(
      const Size(375, 667),
    );
    expect(binding, isA<DesignSizeWidgetsFlutterBinding>());
  });
}
