import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';
import '../widgets/demo_scaffold.dart';
import 'test_lab_diagnostics.dart';

/// 测试实验室页面壳层：统一展示环境、设计尺寸和实时诊断信息。
class TestLabShell extends StatelessWidget {
  const TestLabShell({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final utils = ScreenSizeUtils.instance;
    DemoDiagnostics.log('shell', '$title ${DemoDiagnostics.snapshot(context)}');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DemoCard(
            title: '测试环境',
            subtitle: '所有页面均以同一组环境指标判定结果。',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _pill('Design', formatSize(utils.designSize)),
              _pill('Scale', utils.scale.toStringAsFixed(3)),
              _pill('Logical', formatSize(mq.size)),
              _pill('DPR', mq.devicePixelRatio.toStringAsFixed(2)),
              _pill('Insets', formatInsets(mq.viewInsets)),
            ]),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _pill(String label, String value) =>
      Chip(label: Text('$label  $value'));
}
