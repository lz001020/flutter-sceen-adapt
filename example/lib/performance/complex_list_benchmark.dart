import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

typedef ScaleValue = double Function(double value);

class ComplexListBenchmarkApp extends StatelessWidget {
  const ComplexListBenchmarkApp({
    super.key,
    required this.engine,
    required this.scaleWidth,
    required this.scaleHeight,
    required this.scaleFont,
  });

  final String engine;
  final ScaleValue scaleWidth;
  final ScaleValue scaleHeight;
  final ScaleValue scaleFont;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: ComplexListBenchmarkPage(
        engine: engine,
        scaleWidth: scaleWidth,
        scaleHeight: scaleHeight,
        scaleFont: scaleFont,
      ),
    );
  }
}

class ComplexListBenchmarkPage extends StatefulWidget {
  const ComplexListBenchmarkPage({
    super.key,
    required this.engine,
    required this.scaleWidth,
    required this.scaleHeight,
    required this.scaleFont,
  });

  final String engine;
  final ScaleValue scaleWidth;
  final ScaleValue scaleHeight;
  final ScaleValue scaleFont;

  @override
  State<ComplexListBenchmarkPage> createState() =>
      _ComplexListBenchmarkPageState();
}

class _ComplexListBenchmarkPageState extends State<ComplexListBenchmarkPage> {
  static const _sampleSize = 120;
  final List<int> _frameTimes = <int>[];
  final List<int> _buildTimes = <int>[];
  final List<int> _rasterTimes = <int>[];
  int _scrolls = 0;
  int _nextReportAt = _sampleSize;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_recordFrameTimings);
    debugPrint('[demo:list_performance] engine=${widget.engine} ready');
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
    super.dispose();
  }

  int _percentile(List<int> sorted, int percentile) {
    final index = ((sorted.length - 1) * percentile / 100).round();
    return sorted[index];
  }

  void _recordFrameTimings(List<FrameTiming> timings) {
    _frameTimes.addAll(
      timings.map((timing) => timing.totalSpan.inMicroseconds),
    );
    _buildTimes.addAll(
      timings.map((timing) => timing.buildDuration.inMicroseconds),
    );
    _rasterTimes.addAll(
      timings.map((timing) => timing.rasterDuration.inMicroseconds),
    );
    if (_frameTimes.length < _nextReportAt) return;
    _nextReportAt += _sampleSize;

    final sorted = List<int>.of(_frameTimes)..sort();
    final buildSorted = List<int>.of(_buildTimes)..sort();
    final rasterSorted = List<int>.of(_rasterTimes)..sort();
    final janky = sorted.where((value) => value > 16667).length;
    debugPrint('[demo:list_performance] engine=${widget.engine} '
        'totalFrames=${sorted.length} '
        'p50=${_percentile(sorted, 50)}us '
        'p90=${_percentile(sorted, 90)}us '
        'p99=${_percentile(sorted, 99)}us '
        'buildP90=${_percentile(buildSorted, 90)}us '
        'rasterP90=${_percentile(rasterSorted, 90)}us '
        'janky16ms=$janky');
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    _scrolls++;
    debugPrint(
      '[demo:list_performance] engine=${widget.engine} scroll=$_scrolls',
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.scaleWidth;
    final h = widget.scaleHeight;
    final sp = widget.scaleFont;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Complex List - ${widget.engine}',
          style: TextStyle(fontSize: sp(18)),
        ),
      ),
      body: NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: ListView.builder(
          key: const ValueKey('complex-list'),
          itemCount: 1000,
          cacheExtent: h(600),
          itemBuilder: (context, index) {
            final accent = Colors.primaries[index % Colors.primaries.length];
            return SizedBox(
              height: h(116),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: w(16),
                  vertical: h(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: w(72),
                      height: h(72),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.shade100,
                        borderRadius: BorderRadius.circular(w(6)),
                      ),
                      child: Icon(
                        Icons.layers_outlined,
                        size: w(30),
                        color: accent.shade800,
                      ),
                    ),
                    SizedBox(width: w(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '复杂列表项目 #$index',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: sp(16),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: h(4)),
                          Text(
                            '包含图标、文本、颜色、圆角和多个状态标签',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: sp(12),
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: h(6)),
                          Row(
                            children: [
                              for (final label in const [
                                'ACTIVE',
                                'SYNC',
                                'LOCAL'
                              ])
                                Container(
                                  margin: EdgeInsets.only(right: w(6)),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: w(6),
                                    vertical: h(2),
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: accent.shade300),
                                    borderRadius: BorderRadius.circular(w(3)),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(fontSize: sp(9)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: w(24)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
