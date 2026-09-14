import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

import 'const_rebuild_benchmark.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    type: ScreenAdaptType.width,
  );
  runApp(const ConstRebuildBenchmarkApp(
    engine: 'screen_adapt_const',
    contentBuilder: buildConstScreenAdaptList,
  ));
}
