import 'package:example/pages/unscaled_zone/unscaled_zone_demo_page.dart';
import 'package:example/widgets/demo_scaffold.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('screen_adapt demos'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text(
            'Screen Adapt 测试实验室',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '按场景验证布局、指针、Insets、原生视图与物理像素。每个页面都提供实时诊断信息。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF666257),
                ),
          ),
          const SizedBox(height: 16),
          DemoNavCard(
            icon: Icons.crop_free_outlined,
            title: 'UnscaledZone 局部反适配',
            subtitle: '对比 normal、contextFallback、full 三种模式及命中区域。',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UnscaledZoneDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DemoNavCard(
            icon: Icons.gesture_outlined,
            title: '指针与手势坐标',
            subtitle: '记录 position、localPosition、delta 并验证边界命中。',
            onTap: () {
              Navigator.of(context).pushNamed('/pointer_demo');
            },
          ),
        ],
      ),
    );
  }
}
