import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:screen_adapt/screen_adapt.dart';
import '../../test_lab/test_lab_shell.dart';
import '../../test_lab/test_lab_diagnostics.dart';

class TextScaleTestPage extends StatefulWidget {
  const TextScaleTestPage({super.key});
  @override
  State<TextScaleTestPage> createState() => _TextScaleTestPageState();
}

class _TextScaleTestPageState extends State<TextScaleTestPage>
    with WidgetsBindingObserver {
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeTextScaleFactor() => setState(() {});

  @override
  void didChangeMetrics() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final utils = ScreenSizeUtils.instance;
    final origin = MediaQueryData.fromView(View.of(context));
    return TestLabShell(
      title: '字体与系统缩放',
      onReset: () => setState(() => _revision++),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '跟随系统字体：${utils.supportSystemTextScale}；字体随设计稿缩放：${utils.scaleText}'),
        Text('系统实际字号：16 → ${origin.textScaler.scale(16).toStringAsFixed(2)}；'
            '28 → ${origin.textScaler.scale(28).toStringAsFixed(2)}'),
        const Text('到系统设置调整字体大小后返回。两组使用相同文字，最多显示两行；观察是否出现省略号、裁切或重叠。'),
        const Text(
            'full 恢复原始 MediaQuery，因此也恢复系统文字缩放；即使普通区域禁用系统字体缩放，full 仍可能变化。'),
        for (final mode in ['normal', 'full']) ...[
          const SizedBox(height: 16),
          Text(mode, style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final font in [16.0, 28.0])
            if (mode == 'full')
              UnscaledZone(
                  mode: UnscaledZoneMode.full,
                  child: _TextProbe(
                      key: ValueKey('$mode/$font/$_revision'),
                      mode: mode,
                      font: font))
            else
              _TextProbe(
                  key: ValueKey('$mode/$font/$_revision'),
                  mode: mode,
                  font: font),
        ],
      ]),
    );
  }
}

class _TextProbe extends StatefulWidget {
  const _TextProbe({super.key, required this.mode, required this.font});
  final String mode;
  final double font;
  @override
  State<_TextProbe> createState() => _TextProbeState();
}

class _TextProbeState extends State<_TextProbe> {
  final _key = GlobalKey();
  bool _scheduled = false;
  String _last = '';
  String _result = 'WAIT';

  void _measure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final paragraph =
          _key.currentContext!.findRenderObject()! as RenderParagraph;
      final mq = MediaQuery.of(context);
      final raw = MediaQueryData.fromView(View.of(context));
      final utils = ScreenSizeUtils.instance;
      final actual = mq.textScaler.scale(widget.font);
      final expected = widget.mode == 'full'
          ? raw.textScaler.scale(widget.font)
          : (utils.supportSystemTextScale
                  ? raw.textScaler.scale(widget.font)
                  : widget.font) /
              (utils.scaleText ? 1 : utils.scale);
      final pass = (actual - expected).abs() < 0.01;
      final rect = Rect.fromPoints(paragraph.localToGlobal(Offset.zero),
          paragraph.localToGlobal(paragraph.size.bottomRight(Offset.zero)));
      final result = '${pass ? "PASS" : "FAIL"} 字号映射 '
          '${actual.toStringAsFixed(2)} / 预期 ${expected.toStringAsFixed(2)}\n'
          '逻辑尺寸=${paragraph.size}；超过两行=${paragraph.didExceedMaxLines}';
      final log =
          'mode=${widget.mode} font=${widget.font} scale=${utils.scale} '
          'followSystem=${utils.supportSystemTextScale} scaleText=${utils.scaleText} '
          'system=${raw.textScaler.scale(widget.font)} actual=$actual expected=$expected '
          'mapping=$pass size=${paragraph.size} paint=$rect '
          'ellipsis=${paragraph.didExceedMaxLines}';
      if (_last != log) {
        _last = log;
        DemoDiagnostics.log('text', log);
      }
      if (_result != result) setState(() => _result = result);
    });
  }

  @override
  Widget build(BuildContext context) {
    MediaQuery.of(context);
    _measure();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ColoredBox(
            color: const Color(0xFFE3F2FD),
            child: RichText(
                key: _key,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(
                    text: '屏幕适配测试 Screen Adapt 0123456789。文字应清晰可读，注意两行限制。',
                    style: TextStyle(
                        fontSize: widget.font, color: Colors.black)))),
        Text(_result),
        Wrap(spacing: 8, children: [
          for (final result in ['正常', '裁切或重叠'])
            TextButton(
                onPressed: () => DemoDiagnostics.log('text',
                    'mode=${widget.mode} font=${widget.font} manual=$result'),
                child: Text(result)),
        ]),
      ]),
    );
  }
}
