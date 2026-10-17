import 'package:flutter/material.dart';
import 'package:design_scale/design_scale.dart';
import 'pages/performance/performance_test_page.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(const Size(375, 667));
  runApp(
    MaterialApp(
      home: const PerformanceTestPage(),
      routes: {'/performance_demo': (_) => const PerformanceTestPage()},
    ),
  );
}
