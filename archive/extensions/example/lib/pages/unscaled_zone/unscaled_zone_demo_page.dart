import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:screen_adapt/screen_adapt.dart';
import '../../test_lab/test_lab_shell.dart';
import '../../test_lab/test_lab_diagnostics.dart';

class UnscaledZoneDemoPage extends StatefulWidget {
  const UnscaledZoneDemoPage({super.key});
  @override
  State<UnscaledZoneDemoPage> createState() => _UnscaledZoneDemoPageState();
}

class _UnscaledZoneDemoPageState extends State<UnscaledZoneDemoPage> {
  int _revision = 0;
  @override
  Widget build(BuildContext context) {
    final scale = ScreenSizeUtils.instance.scale;
    return TestLabShell(
      title: 'UnscaledZone',
      onReset: () => setState(() => _revision++),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('矩形为 80×48，红线标记下一兄弟组件。点击矩形中心和边缘，比较计数与视觉位置。'),
        const Text('在灰色测试区内点击矩形或外部，都会记录日志。PASS 只验证几何；context 溢出占位的部分可能无法命中。'),
        for (final name in ['normal', 'context', 'full'])
          _ZoneCase(
              key: ValueKey('$name/$scale/$_revision'),
              name: name,
              scale: scale),
      ]),
    );
  }
}

class _ZoneCase extends StatefulWidget {
  const _ZoneCase({super.key, required this.name, required this.scale});
  final String name;
  final double scale;
  @override
  State<_ZoneCase> createState() => _ZoneCaseState();
}

class _ZoneCaseState extends State<_ZoneCase> {
  final _childKey = GlobalKey();
  final _markerKey = GlobalKey();
  String _geometry = 'WAIT：尚未测量';
  int _taps = 0;
  String _manual = '待验证';
  final _pointers = <int, _PointerProbe>{};
  int _sequence = 0;

  String _position(Offset global) {
    final box = _childKey.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    return 'global=$global local=$local inside=${(Offset.zero & box.size).contains(local)}';
  }

  void _down(PointerDownEvent event) {
    final probe = _PointerProbe(++_sequence, event.position, _taps);
    if (_pointers.isNotEmpty) {
      probe.moved = true;
      for (final active in _pointers.values) {
        active.moved = true;
      }
    }
    _pointers[event.pointer] = probe;
    DemoDiagnostics.log(
        'zone',
        'mode=${widget.name} probe=${probe.id} '
            'down ${_position(event.position)} taps=$_taps');
  }

  void _up(PointerUpEvent event) {
    final probe = _pointers.remove(event.pointer);
    if (probe == null) return;
    final position = _position(event.position);
    // 等本次事件的子组件手势回调完成，再读取计数；不参与手势竞争。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DemoDiagnostics.log(
          'zone',
          'mode=${widget.name} probe=${probe.id} '
              'up $position gesture=${probe.moved ? "drag-or-multi" : "tap-candidate"} '
              'tapsBefore=${probe.taps} tapsAfter=$_taps delta=${_taps - probe.taps}');
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final box = _childKey.currentContext!.findRenderObject()! as RenderBox;
    final marker = _markerKey.currentContext!.findRenderObject()! as RenderBox;
    final start = box.localToGlobal(Offset.zero);
    final width =
        (box.localToGlobal(Offset(box.size.width, 0)) - start).distance;
    final slot = marker.localToGlobal(Offset.zero).dx - start.dx;
    final expectedPaint = widget.name == 'normal' ? 80.0 : 80 / widget.scale;
    final expectedSlot = widget.name == 'full' ? expectedPaint : 80.0;
    final pass = (width - expectedPaint).abs() < 0.1 &&
        (slot - expectedSlot).abs() < 0.1 &&
        box.size == const Size(80, 48);
    setState(() => _geometry = '${pass ? "PASS" : "FAIL"} 几何\n'
        'child=${box.size} 测量时 origin=$start\n'
        'paint=${width.toStringAsFixed(1)} / 预期 ${expectedPaint.toStringAsFixed(1)}\n'
        'slot=${slot.toStringAsFixed(1)} / 预期 ${expectedSlot.toStringAsFixed(1)}');
    DemoDiagnostics.log('zone',
        'mode=${widget.name} scale=${widget.scale} ${_geometry.replaceAll("\n", " ")}');
  }

  @override
  Widget build(BuildContext context) {
    Widget target = GestureDetector(
      onTapUp: (details) {
        setState(() => _taps++);
        DemoDiagnostics.log('zone',
            'mode=${widget.name} taps=$_taps local=${details.localPosition}');
      },
      child: Container(
          key: _childKey,
          width: 80,
          height: 48,
          alignment: Alignment.center,
          color: Colors.lightBlue.shade100,
          child: Text('点击 $_taps')),
    );
    if (widget.name != 'normal') {
      target = UnscaledZone(
          mode: widget.name == 'full'
              ? UnscaledZoneMode.full
              : UnscaledZoneMode.contextFallback,
          child: target);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Listener(
            key: ValueKey('probe-${widget.name}'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: (event) {
              final probe = _pointers[event.pointer];
              if (probe != null &&
                  (event.position - probe.start).distance > kTouchSlop) {
                probe.moved = true;
              }
            },
            onPointerUp: _up,
            onPointerCancel: (event) {
              final probe = _pointers.remove(event.pointer);
              DemoDiagnostics.log(
                  'zone', 'mode=${widget.name} probe=${probe?.id} cancel');
            },
            child: ColoredBox(
                color: const Color(0xFFEDEDED),
                child: SizedBox(
                    width: double.infinity,
                    height: 48 * (widget.scale < 1 ? 1 / widget.scale : 1) + 32,
                    child: Align(
                        alignment: Alignment.topLeft,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              target,
                              IgnorePointer(
                                  child: Container(
                                      key: _markerKey,
                                      width: 2,
                                      height: 48,
                                      color: Colors.red)),
                            ]))))),
        Text(_geometry),
        TextButton(onPressed: _measure, child: const Text('重新测量')),
        Text('视觉与触点一致：$_manual'),
        Wrap(spacing: 8, children: [
          for (final result in ['一致', '存在偏移'])
            TextButton(
                onPressed: () {
                  setState(() => _manual = result);
                  DemoDiagnostics.log(
                      'zone', 'mode=${widget.name} manual=$result');
                },
                child: Text(result)),
        ]),
      ]),
    );
  }
}

class _PointerProbe {
  _PointerProbe(this.id, this.start, this.taps);
  final int id;
  final Offset start;
  final int taps;
  bool moved = false;
}
