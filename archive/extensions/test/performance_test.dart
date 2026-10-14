import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  test('MediaQuery 适配微基准保持有限结果', () {
    final utils = ScreenSizeUtils.instance;
    utils.scale = 0.535714;
    utils.scaleText = true;
    utils.supportSystemTextScale = true;

    const input = MediaQueryData(
      size: Size(411.4, 915.0),
      devicePixelRatio: 2.625,
      padding: EdgeInsets.only(top: 24, bottom: 16),
      viewPadding: EdgeInsets.only(top: 24, bottom: 16),
      viewInsets: EdgeInsets.only(bottom: 320),
    );
    const iterations = 10000;
    final stopwatch = Stopwatch()..start();
    var checksum = 0.0;
    for (var i = 0; i < iterations; i++) {
      final output = input.design();
      checksum += output.size.width + output.devicePixelRatio;
    }
    stopwatch.stop();

    expect(checksum.isFinite, isTrue);
    expect(stopwatch.elapsedMicroseconds, greaterThan(0));
    final microsPerCall = stopwatch.elapsedMicroseconds / iterations;
    // 输出基线供本机和 CI 对比，不设置硬性耗时阈值，避免机器差异造成误报。
    // ignore: avoid_print
    print('[benchmark][media_query_design] iterations=$iterations '
        'elapsed=${stopwatch.elapsedMicroseconds}us '
        'perCall=${microsPerCall.toStringAsFixed(3)}us');
  });
}
