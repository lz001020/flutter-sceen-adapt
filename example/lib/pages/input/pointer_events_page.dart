import 'package:flutter/material.dart';
import '../../test_lab/test_lab_shell.dart';
import '../../test_lab/test_lab_diagnostics.dart';

class PointerTestPage extends StatefulWidget {
  const PointerTestPage({super.key});
  @override
  State<PointerTestPage> createState() => _PointerTestPageState();
}

class _PointerTestPageState extends State<PointerTestPage> {
  final _taps = [0, 0, 0];
  double _drag = 0;
  String _event = '尚未操作';
  String _visual = '待验证';
  void _reset() => setState(() {
        _taps.fillRange(0, 3, 0);
        _drag = 0;
        _event = '尚未操作';
        _visual = '待验证';
      });
  @override
  Widget build(BuildContext context) => TestLabShell(
        title: '指针与手势',
        onReset: _reset,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('依次点击 A / B / C，检查对应计数；在蓝色区域横向拖动。'),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 0; i < 3; i++)
              GestureDetector(
                key: ValueKey('target-$i'),
                onTapUp: (details) {
                  setState(() {
                    _taps[i]++;
                    _event =
                        '靶点 ${String.fromCharCode(65 + i)} local=${details.localPosition}';
                  });
                  DemoDiagnostics.log('pointer', '$_event taps=${_taps[i]}');
                },
                child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    color: Colors.orange.shade200,
                    child: Text('${String.fromCharCode(65 + i)}: ${_taps[i]}')),
              ),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('drag-area'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => setState(() => _drag = 0),
            onHorizontalDragUpdate: (details) =>
                setState(() => _drag += details.delta.dx),
            onHorizontalDragEnd: (_) =>
                DemoDiagnostics.log('pointer', 'dragEnd dx=$_drag'),
            onHorizontalDragCancel: () =>
                DemoDiagnostics.log('pointer', 'dragCancel'),
            child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.blue.shade50,
                alignment: Alignment.center,
                child: Text('横向拖动累计：${_drag.toStringAsFixed(1)}')),
          ),
          const SizedBox(height: 12),
          Text(_event),
          const Text('计数仅记录事件；是否点中预期靶点需要人工确认。'),
          Text('视觉与触点一致：$_visual'),
          Wrap(spacing: 8, children: [
            for (final result in ['一致', '存在偏移'])
              OutlinedButton(
                  onPressed: () {
                    setState(() => _visual = result);
                    DemoDiagnostics.log('pointer', 'manual=$result');
                  },
                  child: Text(result)),
          ]),
        ]),
      );
}
