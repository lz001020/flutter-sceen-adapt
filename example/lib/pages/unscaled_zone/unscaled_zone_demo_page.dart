import 'package:flutter/material.dart';
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
        const Text('PASS 只验证几何。context 溢出布局占位的部分可能无法命中。'),
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
        SizedBox(
            height: 48 * (widget.scale < 1 ? 1 / widget.scale : 1) + 8,
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
                    ]))),
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
