import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';
import '../../test_lab/test_lab_shell.dart';
import '../../test_lab/test_lab_diagnostics.dart';

class WindowMetricsTestPage extends StatefulWidget {
  const WindowMetricsTestPage({super.key});
  @override
  State<WindowMetricsTestPage> createState() => _WindowMetricsTestPageState();
}

class _WindowMetricsTestPageState extends State<WindowMetricsTestPage>
    with WidgetsBindingObserver {
  int _changes = 0;
  String _status = 'WAIT：等待窗口变化';
  String _last = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _record();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _changes++;
    _record();
  }

  void _record() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.of(context);
      final mq = MediaQuery.of(context);
      final utils = ScreenSizeUtils.instance;
      final valid = view.physicalSize.isFinite && !view.physicalSize.isEmpty &&
          view.devicePixelRatio > 0 && utils.scale.isFinite && utils.scale > 0;
      final current = 'physical=${view.physicalSize} logical=${mq.size} '
          'dpr=${view.devicePixelRatio} adaptedDpr=${mq.devicePixelRatio} '
          'scale=${utils.scale} orientation=${mq.orientation.name} valid=$valid';
      if (_last == current) return;
      _last = current;
      _status = valid ? 'PASS：窗口指标有效' : 'FAIL：窗口指标无效';
      DemoDiagnostics.log('window', 'changes=$_changes $current');
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final mq = MediaQuery.of(context);
    return TestLabShell(
      title: '窗口与横竖屏',
      onReset: () {
        _changes = 0;
        _last = '';
        _record();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_status, key: const ValueKey('window-status')),
        Text('变化次数：$_changes\n物理尺寸：${view.physicalSize}\n'
            '逻辑尺寸：${mq.size}\nDPR：${view.devicePixelRatio} → '
            '${mq.devicePixelRatio}\n方向：${mq.orientation.name}'),
        const SizedBox(height: 12),
        const Text('旋转设备或调整窗口，等待 PASS；恢复原方向后再切换设计尺寸。若出现 FAIL，保留日志。'),
        TextButton(onPressed: _record, child: const Text('重新测量')),
      ]),
    );
  }
}
