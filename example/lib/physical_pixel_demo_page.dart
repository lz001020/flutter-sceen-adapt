import 'package:example/shared/demo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

class PhysicalPixelDemoPage extends StatelessWidget {
  const PhysicalPixelDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return DemoPageScaffold(
      title: 'PhysicalPixelZone',
      subtitle: '这一页用于验证像素级绘制。左侧是普通逻辑像素内容，右侧通过 PhysicalPixelZone 将内部尺寸语义切到物理像素。',
      children: [
        const DemoCard(
          title: 'Comparison',
          subtitle: '观察细线、点阵和标签的边缘清晰度；尤其在高 DPR 设备上效果更明显。',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PixelSample(label: 'Normal', usePhysicalPixels: false),
              _PixelSample(label: 'PhysicalPixelZone', usePhysicalPixels: true),
            ],
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

class _PixelSample extends StatelessWidget {
  const _PixelSample({
    required this.label,
    required this.usePhysicalPixels,
  });

  final String label;
  final bool usePhysicalPixels;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 160,
      height: 120,
      color: const Color(0xFFF5F2EB),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PixelGridPainter(),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              width: 1,
              height: 36,
              color: const Color(0xFF123458),
            ),
          ),
          Positioned(
            left: 24,
            top: 12,
            child: Container(
              width: 60,
              height: 1,
              color: const Color(0xFFE85D04),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: Text(
              '1px lines',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    return DemoCard(
      title: label,
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              height: 120,
              child: usePhysicalPixels
                  ? PhysicalPixelZone(child: content)
                  : content,
            ),
            const SizedBox(height: 10),
            Text(
              usePhysicalPixels
                  ? '内部 width:1 表示 1 个物理像素'
                  : '内部 width:1 仍表示 1 个逻辑像素',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1A123458)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
