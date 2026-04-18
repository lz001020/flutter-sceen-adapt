import 'package:flutter/material.dart';

class PointerTestPage extends StatefulWidget {
  const PointerTestPage({super.key});

  @override
  State<PointerTestPage> createState() => _PointerTestPageState();
}

class _PointerTestPageState extends State<PointerTestPage> {
  Offset? _downLocation;
  Offset? _upLocation;
  List<Offset> _points = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pointer Event Test')),
      body: Listener(
        onPointerDown: (event) {
          setState(() {
            _downLocation = event.localPosition;
            _points = [event.localPosition];
          });
          print("onPointerDown: ${event.localPosition}");
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
          print("onPointerUp: ${event.localPosition}");
        },
        child: Container(
          color: Colors.blue.withOpacity(0.1),
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _PointerPainter(_points),
              ),
              if (_downLocation != null)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Text(
                    'Down: ${_downLocation!.dx.toStringAsFixed(1)}, ${_downLocation!.dy.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              if (_upLocation != null)
                Positioned(
                  left: 10,
                  top: 30,
                  child: Text(
                    'Up: ${_upLocation!.dx.toStringAsFixed(1)}, ${_upLocation!.dy.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              // Add some interactive widgets to verify tap hits
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Button 1 Clicked')),
                        );
                      },
                      child: const Text('Button 1'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Button 2 Clicked')),
                        );
                      },
                      child: const Text('Button 2'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  final List<Offset> points;

  _PointerPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
         // Draw a circle at the start point
         canvas.drawCircle(points[i], 8.0, paint..color = Colors.green);
         paint.color = Colors.red;
      } else {
        canvas.drawLine(points[i - 1], points[i], paint);
      }
    }
    
    if (points.isNotEmpty && points.length > 1) {
       // Draw a circle at the end point
       canvas.drawCircle(points.last, 8.0, paint..color = Colors.blue);
    }
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
