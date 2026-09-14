import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:screen_adapt/screen_adapt.dart';

import '../../test_lab/test_lab_diagnostics.dart';

class PerformanceTestPage extends StatefulWidget {
  const PerformanceTestPage({super.key});

  @override
  State<PerformanceTestPage> createState() => _PerformanceTestPageState();
}

class _PerformanceTestPageState extends State<PerformanceTestPage> {
  static const _profiles = <Size>[
    Size(320, 568),
    Size(375, 667),
    Size(768, 1024),
  ];
  static const _sampleSize = 60;

  final List<int> _frameTimes = <int>[];
  final List<int> _allFrameTimes = <int>[];
  double _drag = 0;
  int _gestures = 0;
  int _profileIndex = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_recordFrameTimings);
    DemoDiagnostics.log('performance', 'ready profile=375');
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
    super.dispose();
  }

  void _recordFrameTimings(List<FrameTiming> timings) {
    final values =
        timings.map((timing) => timing.totalSpan.inMicroseconds).toList();
    _frameTimes.addAll(values);
    _allFrameTimes.addAll(values);
    while (_frameTimes.length >= _sampleSize) {
      final sample = _frameTimes.sublist(0, _sampleSize)..sort();
      _frameTimes.removeRange(0, _sampleSize);
      final janky = sample.where((value) => value > 16667).length;
      final allFrames = List<int>.of(_allFrameTimes)..sort();
      final totalJanky = allFrames.where((value) => value > 16667).length;
      DemoDiagnostics.log(
        'performance',
        'frames=$_sampleSize p50=${_percentile(sample, 50)}us '
            'p90=${_percentile(sample, 90)}us '
            'p99=${_percentile(sample, 99)}us janky16ms=$janky '
            'totalFrames=${allFrames.length} '
            'totalP90=${_percentile(allFrames, 90)}us '
            'totalP99=${_percentile(allFrames, 99)}us '
            'totalJanky16ms=$totalJanky',
      );
    }
  }

  int _percentile(List<int> sorted, int percentile) {
    final index = ((sorted.length - 1) * percentile / 100).round();
    return sorted[index];
  }

  void _finishGesture(DragEndDetails details) {
    _gestures++;
    _profileIndex = (_profileIndex + 1) % _profiles.length;
    final size = _profiles[_profileIndex];
    final utils = ScreenSizeUtils.instance;
    utils.setDesignSize(
      size,
      type: utils.adaptType,
      scaleText: utils.scaleText,
      supportSystemTextScale: utils.supportSystemTextScale,
    );
    WidgetsBinding.instance.handleMetricsChanged();
    DemoDiagnostics.log(
      'performance',
      'gesture=$_gestures drag=${_drag.toStringAsFixed(1)} profile=${size.width.toInt()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Automation')),
      body: SafeArea(
        child: GestureDetector(
          key: const ValueKey('performance-drag-area'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => _drag = 0),
          onHorizontalDragUpdate: (details) =>
              setState(() => _drag += details.delta.dx),
          onHorizontalDragEnd: _finishGesture,
          child: SizedBox.expand(
            child: ColoredBox(
              color: const Color(0xFFE8F1F8),
              child: Center(
                child: Text(
                  'gestures=$_gestures\n'
                  'drag=${_drag.toStringAsFixed(1)}\n'
                  'design=${ScreenSizeUtils.instance.designSize.width.toInt()}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
