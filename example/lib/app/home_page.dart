import 'package:example/pages/adaptation/adaptation_gallery_page.dart';
import 'package:example/pages/graphics/physical_pixel_demo_page.dart';
import 'package:example/pages/input/keyboard_media_query_page.dart';
import 'package:example/pages/performance/benchmark_page.dart';
import 'package:example/pages/platform_view/platform_view_demo_page.dart';
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
            icon: Icons.space_dashboard_outlined,
            title: '基础布局与运行时尺寸',
            subtitle: '切换设计稿尺寸，观察 scale、MediaQuery 和布局结果。',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdaptationGalleryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          DemoNavCard(
            icon: Icons.layers_outlined,
            title: 'PlatformView 原生视图',
            subtitle: '比较原生视图尺寸、坐标和点击传递。',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PlatformViewDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DemoNavCard(
            icon: Icons.grid_3x3_outlined,
            title: 'PhysicalPixel 物理像素',
            subtitle: '验证逻辑像素与物理像素映射及 1px 绘制。',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PhysicalPixelDemoPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DemoNavCard(
            icon: Icons.keyboard_outlined,
            title: '键盘与 Insets',
            subtitle: '观察 viewInsets、padding、viewPadding 变化。',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const KeyboardMediaQueryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DemoNavCard(
            icon: Icons.speed_outlined,
            title: '性能基准',
            subtitle: '比较适配开销并输出可重复的基准数据。',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BenchmarkPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
