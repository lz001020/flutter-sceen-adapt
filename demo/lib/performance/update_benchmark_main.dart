import 'package:design_scale/design_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'update_benchmark.dart';

void main() {
  const variantName = String.fromEnvironment('PERF_VARIANT');
  const scenarioName = String.fromEnvironment('PERF_SCENARIO');
  final variant = UpdateVariant.values.byName(variantName);
  final scenario = UpdateScenario.values.byName(scenarioName);
  if (variant.usesScreenUtil) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      ScreenUtilInit(
        designSize: const Size(375, 667),
        builder: (context, child) =>
            UpdateBenchmarkApp(variant: variant, scenario: scenario),
      ),
    );
  } else {
    DesignSizeWidgetsFlutterBinding.ensureInitialized(
      const Size(375, 667),
      type: ScreenAdaptType.width,
    );
    runApp(UpdateBenchmarkApp(variant: variant, scenario: scenario));
  }
}
