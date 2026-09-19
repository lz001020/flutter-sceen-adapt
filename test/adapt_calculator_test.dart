import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  const origin = MediaQueryData(
    size: Size(412, 915),
    devicePixelRatio: 2.5,
    padding: EdgeInsets.only(top: 30, bottom: 20),
    viewPadding: EdgeInsets.only(top: 30, bottom: 20),
    viewInsets: EdgeInsets.only(bottom: 300),
    textScaler: TextScaler.linear(1.5),
  );

  test('calculates width, height, and min modes without global state', () {
    for (final expectation in <(ScreenAdaptType, double)>[
      (ScreenAdaptType.width, 412 / 375),
      (ScreenAdaptType.height, 915 / 667),
      (ScreenAdaptType.min, 412 / 375),
    ]) {
      final result = AdaptCalculator.calculate(
        config: AdaptConfig(
          designSize: const Size(375, 667),
          adaptType: expectation.$1,
        ),
        origin: origin,
        isLandscape: false,
      );

      expect(result.scale, closeTo(expectation.$2, 0.000001));
      expect(result.adapted.size, origin.size / result.scale);
      expect(
        result.adapted.devicePixelRatio,
        origin.devicePixelRatio * result.scale,
      );
      expect(result.adapted.viewInsets, origin.viewInsets / result.scale);
    }
  });

  test('mobile landscape calculation rotates the effective dimensions', () {
    final result = AdaptCalculator.calculate(
      config: const AdaptConfig(
        designSize: Size(375, 667),
        adaptType: ScreenAdaptType.width,
      ),
      origin: const MediaQueryData(size: Size(915, 412)),
      isLandscape: true,
    );

    expect(result.scale, closeTo(412 / 375, 0.000001));
  });

  test('font policy preserves system scaling and compensates UI scale', () {
    const config = AdaptConfig(
      designSize: Size(375, 667),
      scaleText: false,
      supportSystemTextScale: true,
    );
    final adapted = AdaptCalculator.adaptMediaQuery(
      origin: origin,
      scale: 2,
      config: config,
    );

    expect(adapted.textScaler.scale(16), closeTo(12, 0.001));
    expect(adapted.textScaler.scale(28), closeTo(21, 0.001));
  });

  test('calculation does not read or mutate ScreenSizeUtils', () {
    final utils = ScreenSizeUtils.instance;
    final previousScale = utils.scale;
    final previousDesignSize = utils.designSize;

    AdaptCalculator.calculate(
      config: const AdaptConfig(designSize: Size(320, 640)),
      origin: origin,
      isLandscape: false,
    );

    expect(utils.scale, previousScale);
    expect(utils.designSize, previousDesignSize);
  });
}
