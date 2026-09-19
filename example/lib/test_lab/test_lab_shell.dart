import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';
import 'test_lab_diagnostics.dart';

class TestLabShell extends StatelessWidget {
  const TestLabShell(
      {super.key,
      required this.title,
      required this.child,
      required this.onReset,
      this.onProfileChanged,
      this.bottomPanel});
  final String title;
  final Widget child;
  final VoidCallback onReset;
  final VoidCallback? onProfileChanged;
  final Widget? bottomPanel;
  @override
  Widget build(BuildContext context) {
    final controller = DesignSize.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
            tooltip: '重置记录',
            onPressed: onReset,
            icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, children: [
            for (final size in const [
              Size(320, 568),
              Size(375, 667),
              Size(768, 1024)
            ])
              ChoiceChip(
                  label: Text('${size.width.toInt()}'),
                  selected: controller?.config.designSize == size,
                  onSelected: controller == null
                      ? null
                      : (_) {
                          (onProfileChanged ?? onReset)();
                          // 切换设计尺寸时保留本次启动的字体策略。
                          controller.setDesignSize(size);
                          DemoDiagnostics.log('profile', 'design=$size');
                        }),
          ]),
          Text(
              'scale=${(controller?.metrics?.scale ?? 1).toStringAsFixed(3)}  DPR=${MediaQuery.devicePixelRatioOf(context).toStringAsFixed(3)}'),
          const SizedBox(height: 16),
          child,
        ])),
        if (bottomPanel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: bottomPanel!,
          ),
      ])),
    );
  }
}
