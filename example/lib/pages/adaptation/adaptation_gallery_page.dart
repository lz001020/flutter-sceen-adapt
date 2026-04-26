import 'package:example/widgets/demo_scaffold.dart';
import 'package:flutter/material.dart';

class AdaptationGalleryPage extends StatelessWidget {
  const AdaptationGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return DemoPageScaffold(
      title: 'Adaptation Gallery',
      subtitle: '这一页用于验证全局适配本身是否生效。切换设计稿后，观察固定尺寸组件、字体、栅格和 MediaQuery 数据的变化。',
      children: [
        const DemoCard(
          title: 'Fixed Design Units',
          subtitle: '以下卡片都使用写死的设计稿尺寸，切换设计稿后它们应该整体缩放。',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SizeBlock(width: 120, height: 72, color: Color(0xFFF4D35E), label: '120 x 72'),
              _SizeBlock(width: 180, height: 72, color: Color(0xFF9AD1D4), label: '180 x 72'),
              _SizeBlock(width: 220, height: 120, color: Color(0xFFF5B0CB), label: '220 x 120'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'Typography & Spacing',
          subtitle: '标题、段落和间距都直接使用设计稿单位，不依赖 .w/.h。',
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2E7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Design Driven Layout',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '所有尺寸均按设计稿语义直接书写，Binding 在底层完成全局映射，业务层无需额外换算。',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    _Badge(label: 'const friendly'),
                    SizedBox(width: 8),
                    _Badge(label: 'global scale'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'Responsive Grid',
          subtitle: '栅格列宽和间距使用固定设计稿尺寸，可直观看到全局适配是否一致。',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(6, (index) {
              return Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index.isEven ? const Color(0xFFDCE9F7) : const Color(0xFFFFE6D8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Card ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        DiagnosticsCard(
          title: 'Current MediaQuery',
          data: mediaQuery,
        ),
      ],
    );
  }
}

class _SizeBlock extends StatelessWidget {
  const _SizeBlock({
    required this.width,
    required this.height,
    required this.color,
    required this.label,
  });

  final double width;
  final double height;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF123458),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
