import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'const_rebuild_benchmark.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ScreenUtilInit(
    designSize: const Size(375, 667),
    builder: (context, child) => const ConstRebuildBenchmarkApp(
      engine: 'flutter_screenutil_inline',
      contentBuilder: buildInlineScreenUtilList,
    ),
  ));
}
