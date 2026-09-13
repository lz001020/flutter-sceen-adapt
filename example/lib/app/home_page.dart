import 'package:flutter/material.dart';
import '../pages/input/pointer_events_page.dart';
import '../pages/input/keyboard_test_page.dart';
import '../pages/unscaled_zone/unscaled_zone_demo_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Screen Adapt 测试实验室')),
        body: ListView(children: [
          ListTile(
              title: const Text('键盘与安全区'),
              subtitle: const Text('底部输入框、键盘遮挡与 Insets'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const KeyboardTestPage()))),
          ListTile(
              title: const Text('指针与手势'),
              subtitle: const Text('点击靶点、横向拖动'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PointerTestPage()))),
          ListTile(
              title: const Text('UnscaledZone'),
              subtitle: const Text('比较尺寸、占位和点击'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const UnscaledZoneDemoPage()))),
        ]),
      );
}
