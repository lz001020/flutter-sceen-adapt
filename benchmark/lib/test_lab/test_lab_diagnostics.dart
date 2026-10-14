import 'package:flutter/foundation.dart';

class DemoDiagnostics {
  static void log(String scope, String message) {
    debugPrint('[demo:$scope] $message');
  }
}
