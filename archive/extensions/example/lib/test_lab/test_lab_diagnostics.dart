import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

/// 统一输出 demo 诊断信息，便于 adb logcat 筛选。
class DemoDiagnostics {
  static void log(String scope, String message) {
    debugPrint('[demo:$scope] $message');
  }

  static String snapshot(BuildContext context) {
    final mq = MediaQuery.of(context);
    final utils = ScreenSizeUtils.instance;
    return 'design=${utils.designSize} adapted=${mq.size} '
        'scale=${utils.scale.toStringAsFixed(4)} '
        'dpr=${mq.devicePixelRatio.toStringAsFixed(3)} '
        'insets=${mq.viewInsets}';
  }
}
