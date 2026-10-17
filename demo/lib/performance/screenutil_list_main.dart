import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'complex_list_benchmark.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ScreenUtilInit(
      designSize: const Size(375, 667),
      builder: (context, child) => ComplexListBenchmarkApp(
        engine: 'flutter_screenutil',
        scaleWidth: (value) => value.w,
        scaleHeight: (value) => value.w,
        scaleFont: (value) => value.sp,
      ),
    ),
  );
}
