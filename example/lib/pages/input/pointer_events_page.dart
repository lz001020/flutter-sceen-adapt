import 'package:example/widgets/demo_scaffold.dart';
import 'package:flutter/material.dart';
import '../../test_lab/test_lab_diagnostics.dart';
import '../../test_lab/test_lab_shell.dart';

class PointerTestPage extends StatefulWidget {
  const PointerTestPage({super.key});

  @override
  State<PointerTestPage> createState() => _PointerTestPageState();
}

class _PointerTestPageState extends State<PointerTestPage> {
  Offset? _downLocation;
  Offset? _upLocation;
  Offset? _globalLocation;
  Offset? _delta;
  Size? _canvasSize;
  Offset? _canvasOrigin;
  final List<Offset> _points = [];
  int _leftTapCount = 0;
  int _rightTapCount = 0;

  @override
  Widget build(BuildContext context) {
    return TestLabShell(
      title: '指针与手势坐标',
      child: Column(
        children: [
          DemoCard(
            title: 'Pointer Canvas',
            subtitle: '拖动后对照全局坐标、局部坐标和 RenderBox 原点。',
            child: LayoutBuilder(builder: (context, constraints) {
              return Listener(
                onPointerDown: (event) {
                  final box = context.findRenderObject() as RenderBox?;
                  setState(() {
                    _downLocation = event.localPosition;
                    _globalLocation = event.position;
                    _delta = event.delta;
                    _canvasSize = box?.size;
                    _canvasOrigin = box?.localToGlobal(Offset.zero);
                    _points
                      ..clear()
                      ..add(event.localPosition);
                  });
                },
                onPointerMove: (event) {
                  setState(() {
                    _points.add(event.localPosition);
                    _globalLocation = event.position;
                    _delta = event.delta;
                  });
                  DemoDiagnostics.log('pointer',
                      'move global=${event.position} local=${event.localPosition} delta=${event.delta}');
                },
                onPointerUp: (event) {
                  setState(() {
                    _upLocation = event.localPosition;
                    _globalLocation = event.position;
                    _delta = event.delta;
                  });
                  DemoDiagnostics.log('pointer',
                      'up global=${event.position} local=${event.localPosition}');
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
                              onPressed: () =>
                                  setState(() => _leftTapCount += 1),
                              child: Text('Left $_leftTapCount'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  setState(() => _rightTapCount += 1),
                              child: Text('Right $_rightTapCount'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          DemoCard(
            title: '实时诊断',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('canvas size: ${_canvasSize ?? '-'}'),
              Text('canvas origin: ${_canvasOrigin ?? '-'}'),
              Text('global: ${_globalLocation ?? '-'}'),
              Text('local down: ${_downLocation ?? '-'}'),
              Text('local up: ${_upLocation ?? '-'}'),
              Text('delta: ${_delta ?? '-'}'),
              const SizedBox(height: 8),
              Text((_leftTapCount + _rightTapCount > 0)
                  ? 'PASS  按钮命中正常'
                  : 'WAIT  请点击按钮验证命中'),
            ]),
          ),
        ],
      ),
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
