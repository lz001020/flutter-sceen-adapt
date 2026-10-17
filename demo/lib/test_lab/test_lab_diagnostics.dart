import 'package:flutter/material.dart';
import 'package:design_scale/design_scale.dart';

/// 统一输出 demo 诊断信息，便于 adb logcat 筛选。
class DemoDiagnostics {
  static void log(String scope, String message) {
    debugPrint('[demo:$scope] $message');
  }

  static String snapshot(BuildContext context) {
    final mq = MediaQuery.of(context);
    final controller = AdaptController.maybeOf(context);
    final scale = controller?.metrics?.scale ?? 1;
    return 'design=${controller?.config.designSize} adapted=${mq.size} '
        'scale=${scale.toStringAsFixed(4)} '
        'dpr=${mq.devicePixelRatio.toStringAsFixed(3)} '
        'insets=${mq.viewInsets}';
  }
}
