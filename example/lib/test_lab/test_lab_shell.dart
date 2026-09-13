import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';
import 'test_lab_diagnostics.dart';

class TestLabShell extends StatelessWidget {
  const TestLabShell(
      {super.key,
      required this.title,
      required this.child,
      required this.onReset});
  final String title;
  final Widget child;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final utils = ScreenSizeUtils.instance;
    final controller = DesignSize.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
            tooltip: '重置记录',
            onPressed: onReset,
            icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          for (final size in const [
            Size(320, 568),
            Size(375, 667),
            Size(768, 1024)
          ])
            ChoiceChip(
                label: Text('${size.width.toInt()}'),
                selected: utils.designSize == size,
                onSelected: controller == null
                    ? null
                    : (_) {
                        onReset();
                        controller.setDesignSize(size);
                        DemoDiagnostics.log('profile', 'design=$size');
                      }),
        ]),
        Text(
            'scale=${utils.scale.toStringAsFixed(3)}  DPR=${MediaQuery.devicePixelRatioOf(context).toStringAsFixed(3)}'),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}
