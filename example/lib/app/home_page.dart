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
            'Choose a demo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Focused pages for adaptation verification.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF666257),
                ),
          ),
          const SizedBox(height: 16),
          DemoNavCard(
            icon: Icons.space_dashboard_outlined,
            title: 'Adaptation Gallery',
            subtitle: 'Global adaptation and runtime design-size switch.',
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
            title: 'UnscaledZone',
            subtitle: 'Context / paint / layout layering and re-entry cases.',
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
            title: 'Pointer Events',
            subtitle: 'Pointer coordinates and hit-test validation.',
            onTap: () {
              Navigator.of(context).pushNamed('/pointer_demo');
            },
          ),
          const SizedBox(height: 12),
          DemoNavCard(
            icon: Icons.layers_outlined,
            title: 'PlatformView',
            subtitle: 'Native view size and click compensation.',
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
            title: 'Physical Pixels',
            subtitle: '1px drawing and physical pixel checks.',
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
            title: 'Keyboard & Insets',
            subtitle: 'viewInsets and keyboard layout behavior.',
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
            title: 'Benchmark',
            subtitle: 'const optimization: screen_adapt vs flutter_screenutil.',
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
