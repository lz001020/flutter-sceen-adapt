import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

typedef BenchmarkContentBuilder = Widget Function();

class ConstRebuildBenchmarkApp extends StatelessWidget {
  const ConstRebuildBenchmarkApp({
    super.key,
    required this.engine,
    required this.contentBuilder,
  });

  final String engine;
  final BenchmarkContentBuilder contentBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _RebuildBenchmarkPage(
          engine: engine,
          contentBuilder: contentBuilder,
        ),
      );
}

class _RebuildBenchmarkPage extends StatefulWidget {
  const _RebuildBenchmarkPage({
    required this.engine,
    required this.contentBuilder,
  });

  final String engine;
  final BenchmarkContentBuilder contentBuilder;

  @override
  State<_RebuildBenchmarkPage> createState() => _RebuildBenchmarkPageState();
}

class _RebuildBenchmarkPageState extends State<_RebuildBenchmarkPage>
    with SingleTickerProviderStateMixin {
  static const _sampleSize = 120;
  final List<int> _totalTimes = <int>[];
  final List<int> _buildTimes = <int>[];
  final List<int> _rasterTimes = <int>[];
  late final AnimationController _controller;
  int _nextReportAt = _sampleSize;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_recordFrameTimings);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(_rebuild)
      ..repeat();
    debugPrint('[demo:rebuild_performance] engine=${widget.engine} ready');
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
    _controller.dispose();
    super.dispose();
  }

  int _percentile(List<int> sorted, int percentile) {
    final index = ((sorted.length - 1) * percentile / 100).round();
    return sorted[index];
  }

  void _recordFrameTimings(List<FrameTiming> timings) {
    _totalTimes.addAll(
      timings.map((timing) => timing.totalSpan.inMicroseconds),
    );
    _buildTimes.addAll(
      timings.map((timing) => timing.buildDuration.inMicroseconds),
    );
    _rasterTimes.addAll(
      timings.map((timing) => timing.rasterDuration.inMicroseconds),
    );
    if (_totalTimes.length < _nextReportAt) return;
    _nextReportAt += _sampleSize;

    final total = List<int>.of(_totalTimes)..sort();
    final build = List<int>.of(_buildTimes)..sort();
    final raster = List<int>.of(_rasterTimes)..sort();
    final janky = total.where((value) => value > 16667).length;
    debugPrint('[demo:rebuild_performance] engine=${widget.engine} '
        'totalFrames=${total.length} '
        'p90=${_percentile(total, 90)}us '
        'p99=${_percentile(total, 99)}us '
        'buildP90=${_percentile(build, 90)}us '
        'rasterP90=${_percentile(raster, 90)}us janky16ms=$janky');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Rebuild - ${widget.engine}')),
        body: Stack(
          children: [
            widget.contentBuilder(),
            IgnorePointer(
              child: Align(
                alignment: Alignment(
                  -1 + _controller.value * 2,
                  -0.98,
                ),
                child: const SizedBox(
                  width: 48,
                  height: 8,
                  child: ColoredBox(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      );
}

Widget buildConstScreenAdaptList() => const _ConstComplexList();

Widget buildInlineScreenUtilList() => _InlineScreenUtilList();

class _ConstComplexList extends StatelessWidget {
  const _ConstComplexList();

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 1000,
        cacheExtent: 600,
        itemBuilder: (context, index) => const _ConstComplexRow(),
      );
}

class _ConstComplexRow extends StatelessWidget {
  const _ConstComplexRow();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 116,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _LeadingBox(size: 72, iconSize: 30),
              SizedBox(width: 12),
              Expanded(child: _ConstLabels()),
              Icon(Icons.chevron_right, size: 24),
            ],
          ),
        ),
      );
}

class _InlineScreenUtilList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: 1000,
        cacheExtent: 600.w,
        itemBuilder: (context, index) => SizedBox(
          height: 116.w,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
            child: Row(
              children: [
                _LeadingBox(size: 72.w, iconSize: 30.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: _DynamicLabels(
                    titleSize: 16.sp,
                    bodySize: 12.sp,
                    badgeSize: 9.sp,
                    gap4: 4.w,
                    gap6: 6.w,
                    badgeHorizontal: 6.w,
                    badgeVertical: 2.w,
                    badgeRadius: 3.w,
                  ),
                ),
                Icon(Icons.chevron_right, size: 24.w),
              ],
            ),
          ),
        ),
      );
}

class _LeadingBox extends StatelessWidget {
  const _LeadingBox({required this.size, required this.iconSize});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFBBDEFB),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        child: Icon(Icons.layers_outlined, size: iconSize),
      );
}

class _ConstLabels extends StatelessWidget {
  const _ConstLabels();

  @override
  Widget build(BuildContext context) => const _DynamicLabels(
        titleSize: 16,
        bodySize: 12,
        badgeSize: 9,
        gap4: 4,
        gap6: 6,
        badgeHorizontal: 6,
        badgeVertical: 2,
        badgeRadius: 3,
      );
}

class _DynamicLabels extends StatelessWidget {
  const _DynamicLabels({
    required this.titleSize,
    required this.bodySize,
    required this.badgeSize,
    required this.gap4,
    required this.gap6,
    required this.badgeHorizontal,
    required this.badgeVertical,
    required this.badgeRadius,
  });

  final double titleSize;
  final double bodySize;
  final double badgeSize;
  final double gap4;
  final double gap6;
  final double badgeHorizontal;
  final double badgeVertical;
  final double badgeRadius;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '复杂列表项目',
            style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: gap4),
          Text(
            '包含图标、文本、颜色、圆角和多个状态标签',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: bodySize, color: Colors.black54),
          ),
          SizedBox(height: gap6),
          Row(
            children: [
              for (final label in const ['ACTIVE', 'SYNC', 'LOCAL'])
                Container(
                  margin: EdgeInsets.only(right: gap6),
                  padding: EdgeInsets.symmetric(
                    horizontal: badgeHorizontal,
                    vertical: badgeVertical,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF64B5F6)),
                    borderRadius: BorderRadius.circular(badgeRadius),
                  ),
                  child: Text(label, style: TextStyle(fontSize: badgeSize)),
                ),
            ],
          ),
        ],
      );
}
