import 'package:flutter/material.dart';

typedef FeedScale = double Function(double);

/// Deterministic local content: no network, timers, random data or plugins.
class MixedFeedHeader extends StatelessWidget {
  const MixedFeedHeader({
    super.key,
    required this.scale,
    required this.font,
    required this.controller,
    required this.expanded,
    required this.onToggle,
  });

  final FeedScale scale;
  final FeedScale font;
  final ScrollController controller;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: scale(156),
        child: ListView.builder(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: 8,
          itemBuilder: (context, index) => SizedBox(
            width: scale(220),
            child: Padding(
              padding: EdgeInsets.all(scale(8)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(scale(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/feed.png', fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                    Positioned(
                      left: scale(12),
                      bottom: scale(12),
                      child: Text(
                        '精选专题 ${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: font(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      TextButton(
        onPressed: onToggle,
        child: Text(
          expanded ? '收起详情' : '展开详情',
          style: TextStyle(fontSize: font(14)),
        ),
      ),
    ],
  );
}

class MixedFeedCard extends StatelessWidget {
  const MixedFeedCard({
    super.key,
    required this.index,
    required this.scale,
    required this.font,
    required this.expanded,
  });

  final int index;
  final FeedScale scale;
  final FeedScale font;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final kind = index % 4;
    final accent = Colors.primaries[index % Colors.primaries.length];
    return Container(
      margin: EdgeInsets.symmetric(horizontal: scale(12), vertical: scale(8)),
      padding: EdgeInsets.all(scale(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(scale(16)),
        border: Border.all(color: accent.shade100, width: scale(1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: scale(8),
            offset: Offset(0, scale(3)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: scale(16),
                backgroundColor: accent.shade100,
                child: Icon(Icons.person_outline, size: scale(22)),
              ),
              SizedBox(width: scale(10)),
              Expanded(
                child: Text(
                  '动态 #$index · ${['图文', '商品', '数据', '讨论'][kind]}',
                  style: TextStyle(
                    fontSize: font(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.more_horiz, size: scale(22)),
            ],
          ),
          SizedBox(height: scale(10)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '混合内容与自适应布局。',
                  style: TextStyle(color: accent.shade700),
                ),
                TextSpan(
                  text: List.filled(
                    index % 3 + 1,
                    '不同长度的文字会自然换行，结合图片、标签和卡片展示完整信息。',
                  ).join(),
                ),
              ],
            ),
            style: TextStyle(fontSize: font(14), height: 1.4),
          ),
          SizedBox(height: scale(10)),
          if (kind == 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(scale(10)),
              child: Image.asset(
                'assets/feed.png',
                height: scale(140 + (index % 3) * 30),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (kind == 1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                3,
                (item) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(scale(3)),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(scale(8)),
                          child: Image.asset(
                            'assets/feed.png',
                            height: scale(80 + item * 12),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Text(
                          '商品 ${item + 1}\n¥${99 + item * 30}',
                          style: TextStyle(fontSize: font(12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (kind == 2)
            SizedBox(
              height: scale(100),
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(accent, index)),
            ),
          Wrap(
            spacing: scale(6),
            runSpacing: scale(4),
            children: List.generate(
              index % 4 + 2,
              (tag) => Container(
                padding: EdgeInsets.symmetric(
                  horizontal: scale(8),
                  vertical: scale(4),
                ),
                decoration: BoxDecoration(
                  color: accent.shade50,
                  borderRadius: BorderRadius.circular(scale(12)),
                ),
                child: Text('分类 $tag', style: TextStyle(fontSize: font(11))),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: double.infinity,
              child: expanded || kind == 3
                  ? Padding(
                      padding: EdgeInsets.only(top: scale(10)),
                      child: Text(
                        '评论：布局需同时处理多行文字、可变高度及展开后的重新排版。\n回复：这里使用固定本地数据，避免网络差异影响对照。',
                        style: TextStyle(fontSize: font(12), height: 1.5),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.color, this.seed);
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withAlpha(51);
    for (var i = 0; i < 12; i++) {
      final height = size.height * (0.2 + ((i * 7 + seed) % 11) / 15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * size.width / 12,
            size.height - height,
            size.width / 16,
            height,
          ),
          Radius.circular(size.width / 100),
        ),
        paint,
      );
    }
    final path = Path();
    for (var i = 0; i < 24; i++) {
      final x = i * size.width / 23;
      final y = size.height * (0.15 + ((i * 3 + seed) % 9) / 15);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width / 160,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      color != oldDelegate.color || seed != oldDelegate.seed;
}
