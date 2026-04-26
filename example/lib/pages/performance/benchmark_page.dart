// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_adapt/screen_adapt.dart';

class BenchmarkPage extends StatelessWidget {
  const BenchmarkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Benchmark: eager rebuild pressure'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'screen_adapt'),
              Tab(text: 'flutter_screenutil'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BenchmarkTab(useScreenUtil: false),
            _ScreenUtilWrapper(
              child: _BenchmarkTab(useScreenUtil: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// 用真实屏幕尺寸初始化 flutter_screenutil，
/// 因为 screen_adapt 已在 binding 层将 MediaQuery 替换为设计尺寸。
class _ScreenUtilWrapper extends StatelessWidget {
  const _ScreenUtilWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final realMq = ScreenSizeUtils.instance.originData ?? MediaQuery.of(context);
    return MediaQuery(
      data: realMq,
      child: ScreenUtilInit(
        designSize: const Size(375, 667),
        builder: (_, __) => child,
      ),
    );
  }
}

class _SeriesStats {
  const _SeriesStats({
    required this.avg,
    required this.min,
    required this.p50,
    required this.p95,
    required this.p99,
    required this.max,
  });

  static const zero = _SeriesStats(
    avg: 0,
    min: 0,
    p50: 0,
    p95: 0,
    p99: 0,
    max: 0,
  );

  final int avg;
  final int min;
  final int p50;
  final int p95;
  final int p99;
  final int max;

  static _SeriesStats from(List<int> values) {
    if (values.isEmpty) {
      return zero;
    }
    final sorted = List<int>.of(values)..sort();
    final avg = values.reduce((a, b) => a + b) ~/ values.length;

    int percentile(double p) {
      final rank = (sorted.length * p).ceil().clamp(1, sorted.length);
      return sorted[rank - 1];
    }

    return _SeriesStats(
      avg: avg,
      min: sorted.first,
      p50: percentile(0.50),
      p95: percentile(0.95),
      p99: percentile(0.99),
      max: sorted.last,
    );
  }
}

class _BenchmarkSnapshot {
  const _BenchmarkSnapshot({
    required this.modeLabel,
    required this.runs,
    required this.ui,
    required this.raster,
    required this.total,
    required this.vsync,
    required this.buildHits,
  });

  final String modeLabel;
  final int runs;
  final _SeriesStats ui;
  final _SeriesStats raster;
  final _SeriesStats total;
  final _SeriesStats vsync;
  final _SeriesStats buildHits;
}

class _BenchmarkHistory extends ChangeNotifier {
  _BenchmarkSnapshot? screenAdapt;
  _BenchmarkSnapshot? flutterScreenUtil;

  void store({
    required bool useScreenUtil,
    required _BenchmarkSnapshot snapshot,
  }) {
    if (useScreenUtil) {
      flutterScreenUtil = snapshot;
    } else {
      screenAdapt = snapshot;
    }
    notifyListeners();
  }
}

final _benchmarkHistory = _BenchmarkHistory();

class _BenchmarkTab extends StatefulWidget {
  const _BenchmarkTab({required this.useScreenUtil});

  final bool useScreenUtil;

  @override
  State<_BenchmarkTab> createState() => _BenchmarkTabState();
}

class _BenchmarkTabState extends State<_BenchmarkTab> {
  static const _itemCount = 144;
  static const _runs = 56;

  int _rebuildCount = 0;
  final List<int> _uiTimes = [];
  final List<int> _rasterTimes = [];
  final List<int> _totalTimes = [];
  final List<int> _vsyncOverheads = [];
  final List<int> _buildHits = [];
  final List<int> _pendingBuildHits = [];
  final _buildCounter = _BuildCounter();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    super.dispose();
  }

  void _startBenchmark() {
    if (_running) return;
    setState(() {
      _running = true;
      _rebuildCount = 0;
      _uiTimes.clear();
      _rasterTimes.clear();
      _totalTimes.clear();
      _vsyncOverheads.clear();
      _buildHits.clear();
      _pendingBuildHits.clear();
    });
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (_rebuildCount >= _runs) {
      return;
    }
    _buildCounter.resetFrame();
    setState(() => _rebuildCount++);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pendingBuildHits.add(_buildCounter.takeFrameHits());
      if (_rebuildCount < _runs) {
        _scheduleRebuild();
      }
    });
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!_running || _pendingBuildHits.isEmpty) {
      return;
    }

    var accepted = false;
    for (final timing in timings) {
      if (_pendingBuildHits.isEmpty || _uiTimes.length >= _runs) {
        break;
      }
      _uiTimes.add(timing.buildDuration.inMicroseconds);
      _rasterTimes.add(timing.rasterDuration.inMicroseconds);
      _totalTimes.add(timing.totalSpan.inMicroseconds);
      _vsyncOverheads.add(timing.vsyncOverhead.inMicroseconds);
      _buildHits.add(_pendingBuildHits.removeAt(0));
      accepted = true;
    }

    if (!accepted || !mounted) {
      return;
    }

    if (_uiTimes.length >= _runs) {
      _benchmarkHistory.store(
        useScreenUtil: widget.useScreenUtil,
        snapshot: _BenchmarkSnapshot(
          modeLabel: widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt',
          runs: _uiTimes.length,
          ui: _uiStats,
          raster: _rasterStats,
          total: _totalStats,
          vsync: _vsyncStats,
          buildHits: _buildHitStats,
        ),
      );
      setState(() => _running = false);
    } else {
      setState(() {});
    }
  }

  _SeriesStats get _uiStats => _SeriesStats.from(_uiTimes);
  _SeriesStats get _rasterStats => _SeriesStats.from(_rasterTimes);
  _SeriesStats get _totalStats => _SeriesStats.from(_totalTimes);
  _SeriesStats get _vsyncStats => _SeriesStats.from(_vsyncOverheads);
  _SeriesStats get _buildHitStats => _SeriesStats.from(_buildHits);

  String _formatMs(int micros) => (micros / 1000).toStringAsFixed(2);

  String _formatSeriesLine(String label, _SeriesStats stats, {bool micros = true}) {
    String value(int raw) => micros ? '${_formatMs(raw)}ms' : '$raw';

    return '$label avg=${value(stats.avg)} min=${value(stats.min)} '
        'p50=${value(stats.p50)} p95=${value(stats.p95)} '
        'p99=${value(stats.p99)} max=${value(stats.max)}';
  }

  String get _exportText {
    final buffer = StringBuffer()
      ..writeln('mode: ${widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt'}')
      ..writeln('timing_source: SchedulerBinding.addTimingsCallback / FrameTiming')
      ..writeln('note: ui = framework UI thread time, covering build + layout + paint')
      ..writeln('item_count: $_itemCount')
      ..writeln('configured_runs: $_runs')
      ..writeln('captured_runs: ${_uiTimes.length}')
      ..writeln()
      ..writeln(_formatSeriesLine('ui', _uiStats))
      ..writeln(_formatSeriesLine('raster', _rasterStats))
      ..writeln(_formatSeriesLine('total', _totalStats))
      ..writeln(_formatSeriesLine('vsync', _vsyncStats))
      ..writeln(_formatSeriesLine('buildHits', _buildHitStats, micros: false))
      ..writeln()
      ..writeln('samples:');

    for (var i = 0; i < _uiTimes.length; i++) {
      buffer.writeln(
        '#${(i + 1).toString().padLeft(2, '0')} '
        'ui=${_formatMs(_uiTimes[i])}ms '
        'raster=${_formatMs(_rasterTimes[i])}ms '
        'total=${_formatMs(_totalTimes[i])}ms '
        'vsync=${_formatMs(_vsyncOverheads[i])}ms '
        'buildHits=${_buildHits[i]}',
      );
    }
    return buffer.toString();
  }

  Future<void> _copyExport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _exportText));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${_uiTimes.length} FrameTiming samples for '
          '${widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiStats = _uiStats;
    final rasterStats = _rasterStats;
    final totalStats = _totalStats;
    final vsyncStats = _vsyncStats;
    final buildHitStats = _buildHitStats;
    final cards = List<Widget>.generate(
      _itemCount,
      (index) => widget.useScreenUtil
          ? _FeedCardSU(
              tick: _rebuildCount,
              index: index,
            )
          : const _FeedCardSA(),
      growable: false,
    );

    return Column(
      children: [
        AnimatedBuilder(
          animation: _benchmarkHistory,
          builder: (context, _) {
            return _ComparePanel(
              screenAdapt: _benchmarkHistory.screenAdapt,
              flutterScreenUtil: _benchmarkHistory.flutterScreenUtil,
            );
          },
        ),
        _StatsBar(
          uiStats: uiStats,
          rasterStats: rasterStats,
          totalStats: totalStats,
          vsyncStats: vsyncStats,
          buildHitStats: buildHitStats,
          runs: _uiTimes.length,
          running: _running,
          useScreenUtil: widget.useScreenUtil,
          onStart: _startBenchmark,
        ),
        if (_uiTimes.isNotEmpty)
          _ExportPanel(
            modeLabel: widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt',
            runs: _uiTimes.length,
            exportText: _exportText,
            onCopy: () => _copyExport(context),
          ),
        Expanded(
          child: _BuildCountScope(
            counter: _buildCounter,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: cards,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.uiStats,
    required this.rasterStats,
    required this.totalStats,
    required this.vsyncStats,
    required this.buildHitStats,
    required this.runs,
    required this.running,
    required this.useScreenUtil,
    required this.onStart,
  });

  final _SeriesStats uiStats;
  final _SeriesStats rasterStats;
  final _SeriesStats totalStats;
  final _SeriesStats vsyncStats;
  final _SeriesStats buildHitStats;
  final int runs;
  final bool running;
  final bool useScreenUtil;
  final VoidCallback onStart;

  String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            useScreenUtil
                ? 'Extreme stress mode: eager whole-tree rebuilds, 144 cards, 56 runs, and a dynamic probe matrix that reactivates many deep helper-sized sections every frame. Metrics now come from FrameTiming.'
                : 'Extreme stress mode: the same 144-card eager tree is rebuilt, but the probe matrix and most deep sections stay const and should largely be skipped after mount. Metrics now come from FrameTiming.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Note: FrameTiming can accurately report UI thread time and raster time. The UI metric here covers build + layout + paint on the framework side, not three separately split numbers.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6E675B),
                ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final summary = runs == 0
                  ? const Text(
                      'Press Run to benchmark 56 rebuilds × 144 cards. The headline metrics come from SchedulerBinding.addTimingsCallback and are more reliable than Stopwatch timing.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ui avg ${_ms(uiStats.avg)}  '
                          'p50 ${_ms(uiStats.p50)}  '
                          'p95 ${_ms(uiStats.p95)}  '
                          'p99 ${_ms(uiStats.p99)}  '
                          'max ${_ms(uiStats.max)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'raster avg ${_ms(rasterStats.avg)}  '
                          'p95 ${_ms(rasterStats.p95)}  '
                          'p99 ${_ms(rasterStats.p99)}  '
                          'max ${_ms(rasterStats.max)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'total avg ${_ms(totalStats.avg)}  '
                          'p95 ${_ms(totalStats.p95)}  '
                          'p99 ${_ms(totalStats.p99)}  '
                          'max ${_ms(totalStats.max)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'vsync avg ${_ms(vsyncStats.avg)}  '
                          'buildHits p50 ${buildHitStats.p50}  '
                          'p95 ${buildHitStats.p95}  '
                          'p99 ${buildHitStats.p99}  '
                          '($runs runs)',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );

              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summary,
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: running ? null : onStart,
                      child: Text(running ? 'Running…' : 'Run'),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: running ? null : onStart,
                    child: Text(running ? 'Running…' : 'Run'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComparePanel extends StatelessWidget {
  const _ComparePanel({
    required this.screenAdapt,
    required this.flutterScreenUtil,
  });

  final _BenchmarkSnapshot? screenAdapt;
  final _BenchmarkSnapshot? flutterScreenUtil;

  String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (screenAdapt == null && flutterScreenUtil == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DDCA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Comparison',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Each side stores the most recent completed run. Use p95 / p99 / max for the most meaningful stress comparison.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6E675B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CompareCard(
                title: 'screen_adapt',
                accent: const Color(0xFF2D6A4F),
                snapshot: screenAdapt,
                ms: _ms,
              ),
              _CompareCard(
                title: 'flutter_screenutil',
                accent: const Color(0xFFBC6C25),
                snapshot: flutterScreenUtil,
                ms: _ms,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.title,
    required this.accent,
    required this.snapshot,
    required this.ms,
  });

  final String title;
  final Color accent;
  final _BenchmarkSnapshot? snapshot;
  final String Function(int micros) ms;

  @override
  Widget build(BuildContext context) {
    final cardWidth = (MediaQuery.sizeOf(context).width - 12 * 2 - 10 - 14 * 2).clamp(140.0, 420.0);

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: snapshot == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No completed run yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E675B),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot!.runs} runs',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E675B),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ui p95 ${ms(snapshot!.ui.p95)}  p99 ${ms(snapshot!.ui.p99)}  max ${ms(snapshot!.ui.max)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'raster p95 ${ms(snapshot!.raster.p95)}  p99 ${ms(snapshot!.raster.p99)}  max ${ms(snapshot!.raster.max)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'total p95 ${ms(snapshot!.total.p95)}  p99 ${ms(snapshot!.total.p99)}  max ${ms(snapshot!.total.max)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'buildHits p95 ${snapshot!.buildHits.p95}  p99 ${snapshot!.buildHits.p99}  max ${snapshot!.buildHits.max}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _ExportPanel extends StatelessWidget {
  const _ExportPanel({
    required this.modeLabel,
    required this.runs,
    required this.exportText,
    required this.onCopy,
  });

  final String modeLabel;
  final int runs;
  final String exportText;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: const Color(0xFFFFFBF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE8DDCA)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'Export Snapshot · $modeLabel',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text('$runs FrameTiming samples · includes p50 / p95 / p99 and per-frame rows'),
          trailing: OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copy'),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F1E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  exportText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF3C372F),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// screen_adapt version: plain numbers, most subtree can stay const.

class _FeedCardSA extends StatelessWidget {
  const _FeedCardSA();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFE7E1D7)),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderSA(),
              SizedBox(height: 12),
              _BuildProbe(
                child: Text(
                  'Synthetic benchmark payload. This card keeps several nested sections alive so repeated eager rebuilds can expose const-subtree reuse more clearly.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF302C24),
                  ),
                ),
              ),
              SizedBox(height: 12),
              _BuildProbe(child: _HeroMosaicSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _InsightPanelSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _TagWrapSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _MetricStripSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _StressMatrixSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _ActionRowSA()),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSA extends StatelessWidget {
  const _HeaderSA();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvatarSA(),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Case A / Benchmark Node',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusBadgeSA(),
                  Text(
                    'plain numeric sizes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7E786C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(
          Icons.more_horiz,
          size: 20,
          color: Color(0xFF8B8578),
        ),
      ],
    );
  }
}

class _AvatarSA extends StatelessWidget {
  const _AvatarSA();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F3C88), Color(0xFF4FA3D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(
          Icons.auto_graph_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _StatusBadgeSA extends StatelessWidget {
  const _StatusBadgeSA();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'CONST HEAVY',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E7B47),
        ),
      ),
    );
  }
}

class _HeroMosaicSA extends StatelessWidget {
  const _HeroMosaicSA();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 132,
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: _HeroPrimaryTileSA(),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(child: _HeroSecondaryTileSA(label: 'Scale Path', value: 'const')),
                SizedBox(height: 8),
                Expanded(child: _HeroSecondaryTileSA(label: 'Build Hit', value: 'Low')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPrimaryTileSA extends StatelessWidget {
  const _HeroPrimaryTileSA();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123458), Color(0xFF2E6F95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rebuild Payload',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Const Reuse Bias',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Spacer(),
          Row(
            children: [
              _MiniBarSA(width: 18),
              SizedBox(width: 4),
              _MiniBarSA(width: 30),
              SizedBox(width: 4),
              _MiniBarSA(width: 24),
              SizedBox(width: 4),
              _MiniBarSA(width: 34),
              SizedBox(width: 4),
              _MiniBarSA(width: 28),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBarSA extends StatelessWidget {
  const _MiniBarSA({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _HeroSecondaryTileSA extends StatelessWidget {
  const _HeroSecondaryTileSA({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7C7568),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF23201A),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPanelSA extends StatelessWidget {
  const _InsightPanelSA();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D89A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: Color(0xFF946200),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Insight: this branch keeps most deep sections const, so the same eager rebuild loop usually touches fewer nested widgets frame-to-frame.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Color(0xFF6B571F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagWrapSA extends StatelessWidget {
  const _TagWrapSA();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TagChipSA('benchmark'),
        _TagChipSA('const subtree'),
        _TagChipSA('eager rebuild'),
        _TagChipSA('plain size'),
        _TagChipSA('probe matrix'),
      ],
    );
  }
}

class _TagChipSA extends StatelessWidget {
  const _TagChipSA(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF24538C),
        ),
      ),
    );
  }
}

class _MetricStripSA extends StatelessWidget {
  const _MetricStripSA();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricCardSlotSA(
          child: _MetricCardSA(
            label: 'Card Depth',
            value: '6',
            accent: Color(0xFF2E7D32),
            background: Color(0xFFEAF6EC),
          ),
        ),
        _MetricCardSlotSA(
          child: _MetricCardSA(
            label: 'Branches',
            value: '14',
            accent: Color(0xFF8E5A00),
            background: Color(0xFFFFF4E2),
          ),
        ),
        _MetricCardSlotSA(
          child: _MetricCardSA(
            label: 'Probe Slots',
            value: '6',
            accent: Color(0xFF6A1B9A),
            background: Color(0xFFF4EBFF),
          ),
        ),
      ],
    );
  }
}

class _MetricCardSlotSA extends StatelessWidget {
  const _MetricCardSlotSA({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: child,
    );
  }
}

class _MetricCardSA extends StatelessWidget {
  const _MetricCardSA({
    required this.label,
    required this.value,
    required this.accent,
    required this.background,
  });

  final String label;
  final String value;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF756E62),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StressMatrixSA extends StatelessWidget {
  const _StressMatrixSA();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Probe Matrix',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5C564B),
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BuildProbe(child: _StressCellSA(label: 'P0', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P1', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P2', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P3', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P4', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P5', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P6', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P7', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P8', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P9', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P10', value: 'idle')),
            _BuildProbe(child: _StressCellSA(label: 'P11', value: 'idle')),
          ],
        ),
      ],
    );
  }
}

class _StressCellSA extends StatelessWidget {
  const _StressCellSA({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E1D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF7E786C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E2A24),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRowSA extends StatelessWidget {
  const _ActionRowSA();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionPillSA(
          icon: Icons.account_tree_outlined,
          label: 'tree reuse',
        ),
        _ActionPillSA(
          icon: Icons.bolt_outlined,
          label: 'frame time',
        ),
        _ActionPillSA(
          icon: Icons.layers_outlined,
          label: 'build hits',
        ),
        _ActionPillSA(
          icon: Icons.rule_folder_outlined,
          label: 'const path',
        ),
      ],
    );
  }
}

class _ActionPillSA extends StatelessWidget {
  const _ActionPillSA({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF7C7568)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7C7568),
            ),
          ),
        ],
      ),
    );
  }
}

// flutter_screenutil version: .w / .h / .sp makes the subtree mostly non-const.

class _FeedCardSU extends StatelessWidget {
  const _FeedCardSU({
    required this.tick,
    required this.index,
  });

  final int tick;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFE7E1D7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x11000000),
              blurRadius: 20.r,
              offset: Offset(0, 10.h),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderSU(),
              SizedBox(height: 12.h),
              _BuildProbe(
                child: Text(
                  'Synthetic benchmark payload. This card keeps several nested sections alive so repeated eager rebuilds can expose non-const subtree pressure more clearly.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.35,
                    color: const Color(0xFF302C24),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              _BuildProbe(child: _HeroMosaicSU()),
              SizedBox(height: 12.h),
              _BuildProbe(child: _InsightPanelSU()),
              SizedBox(height: 12.h),
              _BuildProbe(child: _TagWrapSU()),
              SizedBox(height: 12.h),
              _BuildProbe(child: _MetricStripSU()),
              SizedBox(height: 12.h),
              _BuildProbe(
                child: _StressMatrixSU(
                  tick: tick,
                  index: index,
                ),
              ),
              SizedBox(height: 12.h),
              _BuildProbe(child: _ActionRowSU()),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildCounter {
  int _frameHits = 0;

  void hit() {
    _frameHits++;
  }

  void resetFrame() {
    _frameHits = 0;
  }

  int takeFrameHits() {
    final hits = _frameHits;
    _frameHits = 0;
    return hits;
  }
}

class _BuildCountScope extends InheritedWidget {
  const _BuildCountScope({
    required this.counter,
    required super.child,
  });

  final _BuildCounter counter;

  static _BuildCounter? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_BuildCountScope>()
        ?.counter;
  }

  @override
  bool updateShouldNotify(_BuildCountScope oldWidget) {
    return identical(counter, oldWidget.counter) == false;
  }
}

class _BuildProbe extends StatelessWidget {
  const _BuildProbe({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    _BuildCountScope.maybeOf(context)?.hit();
    return child;
  }
}

class _HeaderSU extends StatelessWidget {
  const _HeaderSU();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AvatarSU(),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Case B / Benchmark Node',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 4.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusBadgeSU(),
                  Text(
                    '.w / .h / .sp sizing',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF7E786C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(
          Icons.more_horiz,
          size: 20.sp,
          color: const Color(0xFF8B8578),
        ),
      ],
    );
  }
}

class _AvatarSU extends StatelessWidget {
  const _AvatarSU();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F3C88), Color(0xFF4FA3D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: SizedBox(
        width: 42.w,
        height: 42.h,
        child: Icon(
          Icons.auto_graph_rounded,
          color: Colors.white,
          size: 22.sp,
        ),
      ),
    );
  }
}

class _StatusBadgeSU extends StatelessWidget {
  const _StatusBadgeSU();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EC),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        'NON-CONST',
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E7B47),
        ),
      ),
    );
  }
}

class _HeroMosaicSU extends StatelessWidget {
  const _HeroMosaicSU();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132.h,
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: _HeroPrimaryTileSU(),
          ),
          SizedBox(width: 8.w),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: _HeroSecondaryTileSU(
                    label: 'Scale Path',
                    value: '.w/.h',
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: _HeroSecondaryTileSU(
                    label: 'Build Hit',
                    value: 'High',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPrimaryTileSU extends StatelessWidget {
  const _HeroPrimaryTileSU();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123458), Color(0xFF2E6F95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rebuild Payload',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Sizing Helper Bias',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _MiniBarSU(width: 18),
              SizedBox(width: 4.w),
              _MiniBarSU(width: 30),
              SizedBox(width: 4.w),
              _MiniBarSU(width: 24),
              SizedBox(width: 4.w),
              _MiniBarSU(width: 34),
              SizedBox(width: 4.w),
              _MiniBarSU(width: 28),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBarSU extends StatelessWidget {
  const _MiniBarSU({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }
}

class _HeroSecondaryTileSU extends StatelessWidget {
  const _HeroSecondaryTileSU({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1E8),
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: const Color(0xFF7C7568),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF23201A),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPanelSU extends StatelessWidget {
  const _InsightPanelSU();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0D89A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 18.sp,
            color: const Color(0xFF946200),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Insight: this branch keeps many helper-sized widgets non-const, so the same eager rebuild loop tends to reactivate more deep sections frame-to-frame.',
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.35,
                color: const Color(0xFF6B571F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagWrapSU extends StatelessWidget {
  const _TagWrapSU();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _TagChipSU('benchmark'),
        _TagChipSU('screenutil'),
        _TagChipSU('eager rebuild'),
        _TagChipSU('sizing helper'),
        _TagChipSU('probe matrix'),
      ],
    );
  }
}

class _TagChipSU extends StatelessWidget {
  const _TagChipSU(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FF),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          color: const Color(0xFF24538C),
        ),
      ),
    );
  }
}

class _MetricStripSU extends StatelessWidget {
  const _MetricStripSU();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        SizedBox(
          width: 96.w,
          child: _MetricCardSU(
            label: 'Card Depth',
            value: '6',
            accent: Color(0xFF2E7D32),
            background: Color(0xFFEAF6EC),
          ),
        ),
        SizedBox(
          width: 96.w,
          child: _MetricCardSU(
            label: 'Branches',
            value: '14',
            accent: Color(0xFF8E5A00),
            background: Color(0xFFFFF4E2),
          ),
        ),
        SizedBox(
          width: 96.w,
          child: _MetricCardSU(
            label: 'Probe Slots',
            value: '6',
            accent: Color(0xFF6A1B9A),
            background: Color(0xFFF4EBFF),
          ),
        ),
      ],
    );
  }
}

class _MetricCardSU extends StatelessWidget {
  const _MetricCardSU({
    required this.label,
    required this.value,
    required this.accent,
    required this.background,
  });

  final String label;
  final String value;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: const Color(0xFF756E62),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StressMatrixSU extends StatelessWidget {
  const _StressMatrixSU({
    required this.tick,
    required this.index,
  });

  final int tick;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Probe Matrix',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF5C564B),
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: List<Widget>.generate(12, (slot) {
            final value = (tick + index + slot) % 10;
            return _BuildProbe(
              child: _StressCellSU(
                label: 'P$slot',
                value: 't$value',
                active: value.isEven,
              ),
            );
          }, growable: false),
        ),
      ],
    );
  }
}

class _StressCellSU extends StatelessWidget {
  const _StressCellSU({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68.w,
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFFF1E0) : const Color(0xFFF7F4EE),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: active ? const Color(0xFFFFB86A) : const Color(0xFFE7E1D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: const Color(0xFF7E786C),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF8E4A00) : const Color(0xFF2E2A24),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRowSU extends StatelessWidget {
  const _ActionRowSU();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _ActionPillSU(
          icon: Icons.account_tree_outlined,
          label: 'tree reuse',
        ),
        _ActionPillSU(
          icon: Icons.bolt_outlined,
          label: 'frame time',
        ),
        _ActionPillSU(
          icon: Icons.layers_outlined,
          label: 'build hits',
        ),
        _ActionPillSU(
          icon: Icons.straighten_outlined,
          label: 'scale path',
        ),
      ],
    );
  }
}

class _ActionPillSU extends StatelessWidget {
  const _ActionPillSU({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3ED),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.sp, color: const Color(0xFF7C7568)),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFF7C7568),
            ),
          ),
        ],
      ),
    );
  }
}
