import 'package:example/widgets/demo_scaffold.dart';
import 'package:flutter/material.dart';

class PointerTestPage extends StatefulWidget {
  const PointerTestPage({super.key});

  @override
  State<PointerTestPage> createState() => _PointerTestPageState();
}

class _PointerTestPageState extends State<PointerTestPage> {
  Offset? _downLocation;
  Offset? _upLocation;
  final List<Offset> _points = [];
  int _leftTapCount = 0;
  int _rightTapCount = 0;

  @override
  Widget build(BuildContext context) {
    return DemoPageScaffold(
      title: 'Pointer Events',
      subtitle: '切换设计稿后在画布上点击、拖拽并点击按钮，验证全局改写 DPR 后的指针坐标和命中测试是否仍然准确。',
      children: [
        DemoCard(
          title: 'Pointer Canvas',
          subtitle: '绿色点为按下位置，蓝色点为抬起位置，红线为拖动轨迹。',
          child: Listener(
            onPointerDown: (event) {
              setState(() {
                _downLocation = event.localPosition;
                _points
                  ..clear()
                  ..add(event.localPosition);
              });
            },
            onPointerMove: (event) {
              setState(() {
                _points.add(event.localPosition);
              });
            },
            onPointerUp: (event) {
              setState(() {
                _upLocation = event.localPosition;
              });
            },
            child: Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F1FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PointerPainter(_points),
                    ),
                  ),
                  if (_downLocation != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Text(
                        'Down: ${_downLocation!.dx.toStringAsFixed(1)}, ${_downLocation!.dy.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (_upLocation != null)
                    Positioned(
                      left: 12,
                      top: 36,
                      child: Text(
                        'Up: ${_upLocation!.dx.toStringAsFixed(1)}, ${_upLocation!.dy.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  Align(
                    alignment: Alignment.center,
                    child: Wrap(
                      spacing: 16,
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() => _leftTapCount += 1),
                          child: Text('Left $_leftTapCount'),
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() => _rightTapCount += 1),
                          child: Text('Right $_rightTapCount'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        canvas.drawCircle(points[i], 8, paint..color = Colors.green);
        paint.color = Colors.red;
      } else {
        canvas.drawLine(points[i - 1], points[i], paint);
      }
    }

    if (points.length > 1) {
      canvas.drawCircle(points.last, 8, paint..color = Colors.blue);
    }
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
