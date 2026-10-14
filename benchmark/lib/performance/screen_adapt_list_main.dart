import 'package:flutter/material.dart';
import 'package:design_scale/design_scale.dart';

import 'complex_list_benchmark.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    type: ScreenAdaptType.width,
  );
  runApp(
    const ComplexListBenchmarkApp(
      engine: 'screen_adapt',
      scaleWidth: _identity,
      scaleHeight: _identity,
      scaleFont: _identity,
    ),
  );
}

double _identity(double value) => value;
