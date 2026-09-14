import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  test('已有其他 binding 时明确报错', () {
    WidgetsFlutterBinding.ensureInitialized();

    expect(
      () => DesignSizeWidgetsFlutterBinding.ensureInitialized(
        const Size(375, 812),
      ),
      throwsA(isA<FlutterError>()),
    );
  });
}
