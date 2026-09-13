import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../test_lab/test_lab_shell.dart';
import '../../test_lab/test_lab_diagnostics.dart';

class KeyboardTestPage extends StatefulWidget {
  const KeyboardTestPage({super.key});
  @override
  State<KeyboardTestPage> createState() => _KeyboardTestPageState();
}

class _KeyboardTestPageState extends State<KeyboardTestPage> {
  final _fieldKey = GlobalKey();
  final _focus = FocusNode();
  final _text = TextEditingController();
  bool _scheduled = false;
  String _lastLog = '';
  String _result = 'WAIT：尚未测量';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_scheduleMeasurement);
  }

  @override
  void dispose() {
    _focus.removeListener(_scheduleMeasurement);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _scheduleMeasurement() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final mq = MediaQuery.of(context);
      final raw = MediaQueryData.fromView(View.of(context));
      final box = _fieldKey.currentContext!.findRenderObject()! as RenderBox;
      final rect = Rect.fromPoints(box.localToGlobal(Offset.zero),
          box.localToGlobal(box.size.bottomRight(Offset.zero)));
      final bottom = mq.size.height -
          math.max(mq.viewInsets.bottom, mq.viewPadding.bottom);
      final visible = rect.bottom <= bottom + 0.5 &&
          rect.top >= math.max(mq.viewInsets.top, mq.viewPadding.top) - 0.5 &&
          rect.left >=
              math.max(mq.viewInsets.left, mq.viewPadding.left) - 0.5 &&
          rect.right <=
              mq.size.width -
                  math.max(mq.viewInsets.right, mq.viewPadding.right) +
                  0.5;
      final insetMatches = (mq.viewInsets.bottom * mq.devicePixelRatio -
                  raw.viewInsets.bottom * raw.devicePixelRatio)
              .abs() <
          1;
      final state = mq.viewInsets.bottom > 0 ? '打开' : '收起';
      final result = '${visible ? "PASS" : "FAIL"} 输入框可见；'
          '${insetMatches ? "PASS" : "FAIL"} 底部 Insets 映射；键盘$state';
      final log = 'keyboard=$state focused=${_focus.hasFocus} '
          'originSize=${raw.size} originDpr=${raw.devicePixelRatio} '
          'adaptedSize=${mq.size} adaptedDpr=${mq.devicePixelRatio} '
          'originInsets=${raw.viewInsets} adaptedInsets=${mq.viewInsets} '
          'padding=${mq.padding} viewPadding=${mq.viewPadding} '
          'field=$rect safeBottom=$bottom visible=$visible insetMatches=$insetMatches';
      if (_lastLog != log) {
        _lastLog = log;
        DemoDiagnostics.log('keyboard', log);
      }
      if (_result != result) setState(() => _result = result);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    _scheduleMeasurement();
    return TestLabShell(
      title: '键盘与安全区',
      onReset: () {
        _focus.unfocus();
        _text.clear();
        _lastLog = '';
        _scheduleMeasurement();
      },
      onProfileChanged: () {
        _lastLog = '';
        _scheduleMeasurement();
      },
      bottomPanel: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            key: _fieldKey,
            focusNode: _focus,
            controller: _text,
            decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: '点击这里打开键盘'),
            onSubmitted: (_) => _focus.unfocus()),
        const SizedBox(height: 6),
        Container(height: 2, color: Colors.green),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 2, color: Colors.green),
        const Text('绿线位于安全区内。点击底部输入框，打开和收起键盘；切换设计尺寸后重复。'),
        const SizedBox(height: 12),
        Text(_result, key: const ValueKey('keyboard-result')),
        Text(
            'padding=${mq.padding}\nviewPadding=${mq.viewPadding}\nviewInsets=${mq.viewInsets}'),
        const Text('PASS 只检查输入框边界及底部 Insets 数值。键盘实际遮挡、安全区视觉效果仍需在设备上确认。'),
        Wrap(spacing: 8, children: [
          TextButton(
              onPressed: () => _focus.unfocus(), child: const Text('收起键盘')),
          TextButton(
              onPressed: () {
                _lastLog = '';
                _scheduleMeasurement();
              },
              child: const Text('重新测量')),
          for (final result in ['正常', '有遮挡'])
            TextButton(
                onPressed: () {
                  DemoDiagnostics.log('keyboard',
                      'manual=$result keyboardVisible=${mq.viewInsets.bottom > 0}');
                },
                child: Text(result)),
        ]),
      ]),
    );
  }
}
