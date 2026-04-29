// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _benchmarkViewportSize = Size(375, 667);

enum _BenchLevel { simple, medium, stress }

class _BenchProfile {
  const _BenchProfile({
    required this.level,
    required this.label,
    required this.itemCount,
    required this.runs,
  });

  final _BenchLevel level;
  final String label;
  final int itemCount;
  final int runs;
}

const _simpleProfile = _BenchProfile(
  level: _BenchLevel.simple,
  label: 'Simple',
  itemCount: 48,
  runs: 24,
);

const _mediumProfile = _BenchProfile(
  level: _BenchLevel.medium,
  label: 'Medium',
  itemCount: 96,
  runs: 40,
);

const _stressProfile = _BenchProfile(
  level: _BenchLevel.stress,
  label: 'Stress',
  itemCount: 144,
  runs: 56,
);

int _levelItemCount(_BenchLevel level) {
  return switch (level) {
    _BenchLevel.simple => _simpleProfile.itemCount,
    _BenchLevel.medium => _mediumProfile.itemCount,
    _BenchLevel.stress => _stressProfile.itemCount,
  };
}

int _levelRuns(_BenchLevel level) {
  return switch (level) {
    _BenchLevel.simple => _simpleProfile.runs,
    _BenchLevel.medium => _mediumProfile.runs,
    _BenchLevel.stress => _stressProfile.runs,
  };
}

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  final _history = _BenchmarkHistory();
  _BenchProfile _profile = _stressProfile;

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BenchmarkHistoryScope(
      history: _history,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F3EA),
          appBar: AppBar(
            title: const Text('Benchmark · 性能对比'),
            backgroundColor: const Color(0xFFF7F3EA),
            surfaceTintColor: Colors.transparent,
            actions: [
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: '使用引导',
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  icon: const Icon(Icons.help_outline_rounded),
                ),
              ),
              IconButton(
                tooltip: 'Home',
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.home_outlined),
              ),
            ],
          ),
          endDrawer: const _GuideDrawer(),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _BenchmarkLevelSelector(
                  current: _profile.level,
                  onChanged: (level) {
                    setState(() {
                      _profile = switch (level) {
                        _BenchLevel.simple => _simpleProfile,
                        _BenchLevel.medium => _mediumProfile,
                        _BenchLevel.stress => _stressProfile,
                      };
                    });
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _BenchmarkModeTabs(),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _BenchmarkTab(useScreenUtil: false, profile: _profile),
                    _ScreenUtilWrapper(
                        child: _BenchmarkTab(
                            useScreenUtil: true, profile: _profile)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideDrawer extends StatelessWidget {
  const _GuideDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      backgroundColor: const Color(0xFFF7F3EA),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_outlined, color: Color(0xFF1F3C88)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'How to run · 新手引导',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    tooltip: '收起',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '固定视口压力测试：对比两种方案的 tail latency 与 build 命中。',
                style: TextStyle(fontSize: 12, color: Color(0xFF666257)),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDF6DD), Color(0xFFF0F4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E2DA)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GuideStep(index: 1, text: '先跑 screen_adapt。'),
                    SizedBox(height: 8),
                    _GuideStep(index: 2, text: '再跑 flutter_screenutil。'),
                    SizedBox(height: 8),
                    _GuideStep(index: 3, text: '看 Comparison 的 Δms 和 Δ%。'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E2DA)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Interpretation',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('• p95/p99/max 越低越好，表示卡顿尾部更稳。',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF4B4A43))),
                    SizedBox(height: 4),
                    Text('• buildHits 越低，说明可复用子树越多。',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF4B4A43))),
                    SizedBox(height: 4),
                    Text('• 红色代表慢，绿色代表快。',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF4B4A43))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1F3C88),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(text, style: const TextStyle(color: Color(0xFF4B4A43)))),
      ],
    );
  }
}

class _BenchmarkLevelSelector extends StatelessWidget {
  const _BenchmarkLevelSelector({
    required this.current,
    required this.onChanged,
  });

  final _BenchLevel current;
  final ValueChanged<_BenchLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E2DA)),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _LevelChip(
            selected: current == _BenchLevel.simple,
            label: 'Simple',
            subLabel: '48 cards · 24 runs',
            onTap: () => onChanged(_BenchLevel.simple),
          ),
          _LevelChip(
            selected: current == _BenchLevel.medium,
            label: 'Medium',
            subLabel: '96 cards · 40 runs',
            onTap: () => onChanged(_BenchLevel.medium),
          ),
          _LevelChip(
            selected: current == _BenchLevel.stress,
            label: 'Stress',
            subLabel: '144 cards · 56 runs',
            onTap: () => onChanged(_BenchLevel.stress),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.selected,
    required this.label,
    required this.subLabel,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final String subLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1F3C88) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF4B4A43),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? const Color(0xFFE2E8FF)
                      : const Color(0xFF7A766E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenchmarkModeTabs extends StatelessWidget {
  const _BenchmarkModeTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E2DA)),
      ),
      padding: const EdgeInsets.all(2),
      child: TabBar(
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF1F3C88),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF666257),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        tabs: const [
          Tab(height: 30, text: 'screen_adapt'),
          Tab(height: 30, text: 'flutter_screenutil'),
        ],
      ),
    );
  }
}

class _ScreenUtilWrapper extends StatefulWidget {
  const _ScreenUtilWrapper({required this.child});

  final Widget child;

  @override
  State<_ScreenUtilWrapper> createState() => _ScreenUtilWrapperState();
}

class _ScreenUtilWrapperState extends State<_ScreenUtilWrapper> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ScreenUtil.enableScale(
      enableWH: () => true,
      enableText: () => true,
    );
    ScreenUtil.configure(
      data: MediaQuery.of(context),
      designSize: _benchmarkViewportSize,
      splitScreenMode: false,
      minTextAdapt: false,
      fontSizeResolver: FontSizeResolvers.width,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

  static const zero =
      _SeriesStats(avg: 0, min: 0, p50: 0, p95: 0, p99: 0, max: 0);

  final int avg;
  final int min;
  final int p50;
  final int p95;
  final int p99;
  final int max;

  static _SeriesStats from(List<int> values) {
    if (values.isEmpty) return zero;
    final sorted = List<int>.of(values)..sort();
    final avg = values.reduce((a, b) => a + b) ~/ values.length;

    int percentile(double p) {
      final rank = (sorted.length * p).ceil().clamp(1, sorted.length);
      return sorted[rank - 1];
    }

    return _SeriesStats(
      avg: avg,
      min: sorted.first,
      p50: percentile(0.5),
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
  final Map<_BenchLevel, _BenchmarkSnapshot?> _screenAdaptByLevel = {
    _BenchLevel.simple: null,
    _BenchLevel.medium: null,
    _BenchLevel.stress: null,
  };
  final Map<_BenchLevel, _BenchmarkSnapshot?> _screenUtilByLevel = {
    _BenchLevel.simple: null,
    _BenchLevel.medium: null,
    _BenchLevel.stress: null,
  };

  void store(
      {required _BenchLevel level,
      required bool useScreenUtil,
      required _BenchmarkSnapshot snapshot}) {
    if (useScreenUtil) {
      _screenUtilByLevel[level] = snapshot;
    } else {
      _screenAdaptByLevel[level] = snapshot;
    }
    notifyListeners();
  }

  _BenchmarkSnapshot? screenAdaptOf(_BenchLevel level) =>
      _screenAdaptByLevel[level];
  _BenchmarkSnapshot? screenUtilOf(_BenchLevel level) =>
      _screenUtilByLevel[level];
}

class _BenchmarkHistoryScope extends InheritedWidget {
  const _BenchmarkHistoryScope({required this.history, required super.child});

  final _BenchmarkHistory history;

  static _BenchmarkHistory of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_BenchmarkHistoryScope>()!
        .history;
  }

  @override
  bool updateShouldNotify(_BenchmarkHistoryScope oldWidget) =>
      !identical(history, oldWidget.history);
}

class _BenchmarkTab extends StatefulWidget {
  const _BenchmarkTab({required this.useScreenUtil, required this.profile});

  final bool useScreenUtil;
  final _BenchProfile profile;

  @override
  State<_BenchmarkTab> createState() => _BenchmarkTabState();
}

class _BenchmarkTabState extends State<_BenchmarkTab> {
  int get _itemCount => widget.profile.itemCount;
  int get _runs => widget.profile.runs;

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
  void didUpdateWidget(covariant _BenchmarkTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.level != widget.profile.level && !_running) {
      _rebuildCount = 0;
      _uiTimes.clear();
      _rasterTimes.clear();
      _totalTimes.clear();
      _vsyncOverheads.clear();
      _buildHits.clear();
      _pendingBuildHits.clear();
    }
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
    if (_rebuildCount >= _runs) return;
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
    if (!_running || _pendingBuildHits.isEmpty) return;

    var accepted = false;
    for (final timing in timings) {
      if (_pendingBuildHits.isEmpty || _uiTimes.length >= _runs) break;
      _uiTimes.add(timing.buildDuration.inMicroseconds);
      _rasterTimes.add(timing.rasterDuration.inMicroseconds);
      _totalTimes.add(timing.totalSpan.inMicroseconds);
      _vsyncOverheads.add(timing.vsyncOverhead.inMicroseconds);
      _buildHits.add(_pendingBuildHits.removeAt(0));
      accepted = true;
    }

    if (!accepted || !mounted) return;

    if (_uiTimes.length >= _runs) {
      _BenchmarkHistoryScope.of(context).store(
        level: widget.profile.level,
        useScreenUtil: widget.useScreenUtil,
        snapshot: _BenchmarkSnapshot(
          modeLabel:
              widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt',
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

  String _formatSeriesLine(String label, _SeriesStats stats,
      {bool micros = true}) {
    String value(int raw) => micros ? '${_formatMs(raw)}ms' : '$raw';
    return '$label avg=${value(stats.avg)} min=${value(stats.min)} p50=${value(stats.p50)} p95=${value(stats.p95)} p99=${value(stats.p99)} max=${value(stats.max)}';
  }

  String get _exportText {
    final b = StringBuffer()
      ..writeln(
          'mode: ${widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt'}')
      ..writeln(
          'timing_source: SchedulerBinding.addTimingsCallback / FrameTiming')
      ..writeln(
          'note: ui = framework UI thread time, covering build + layout + paint')
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
      b.writeln(
        '#${(i + 1).toString().padLeft(2, '0')} ui=${_formatMs(_uiTimes[i])}ms raster=${_formatMs(_rasterTimes[i])}ms total=${_formatMs(_totalTimes[i])}ms vsync=${_formatMs(_vsyncOverheads[i])}ms buildHits=${_buildHits[i]}',
      );
    }
    return b.toString();
  }

  Future<void> _copyExport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _exportText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Copied ${_uiTimes.length} samples for ${widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt'}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = List<Widget>.generate(
      _itemCount,
      (index) {
        if (widget.useScreenUtil) {
          return _FeedCardSU(
            tick: _rebuildCount,
            index: index,
            level: widget.profile.level,
          );
        }
        return _FeedCardSA(level: widget.profile.level);
      },
      growable: false,
    );

    return Column(
      children: [
        AnimatedBuilder(
          animation: _BenchmarkHistoryScope.of(context),
          builder: (context, _) {
            final history = _BenchmarkHistoryScope.of(context);
            return _ComparePanel(
              screenAdapt: history.screenAdaptOf(widget.profile.level),
              flutterScreenUtil: history.screenUtilOf(widget.profile.level),
            );
          },
        ),
        _StatsBar(
          uiStats: _uiStats,
          rasterStats: _rasterStats,
          totalStats: _totalStats,
          vsyncStats: _vsyncStats,
          buildHitStats: _buildHitStats,
          runs: _uiTimes.length,
          configuredRuns: _runs,
          running: _running,
          useScreenUtil: widget.useScreenUtil,
          onStart: _startBenchmark,
        ),
        if (_uiTimes.isNotEmpty)
          _ExportPanel(
            modeLabel:
                widget.useScreenUtil ? 'flutter_screenutil' : 'screen_adapt',
            runs: _uiTimes.length,
            exportText: _exportText,
            onCopy: () => _copyExport(context),
          ),
        Expanded(
          child: _BuildCountScope(
            counter: _buildCounter,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(children: cards),
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
    required this.configuredRuns,
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
  final int configuredRuns;
  final bool running;
  final bool useScreenUtil;
  final VoidCallback onStart;

  String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final progress =
        configuredRuns == 0 ? 0.0 : (runs / configuredRuns).clamp(0.0, 1.0);
    final accent =
        useScreenUtil ? const Color(0xFFBC6C25) : const Color(0xFF2D6A4F);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, accent.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E2DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                useScreenUtil ? 'flutter_screenutil 分支' : 'screen_adapt 分支',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Runs $runs/$configuredRuns',
                    style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '重点关注 tail latency：p95 / p99 / max。',
            style: TextStyle(fontSize: 12, color: Color(0xFF666257)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: const Color(0xFFF0F0EA),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 10),
          if (runs == 0)
            const Text('Press Run 开始采样。')
          else ...[
            Row(
              children: [
                Expanded(
                  child: _PerfGauge(
                    label: 'UI p95',
                    value: '${_ms(uiStats.p95)}ms',
                    color: _severityColor(uiStats.p95),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PerfGauge(
                    label: 'TOTAL p95',
                    value: '${_ms(totalStats.p95)}ms',
                    color: _severityColor(totalStats.p95),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PerfGauge(
                    label: 'UI max',
                    value: '${_ms(uiStats.max)}ms',
                    color: _severityColor(uiStats.max),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _MetricLine(
                label: 'ui',
                avg: _ms(uiStats.avg),
                p95: _ms(uiStats.p95),
                p99: _ms(uiStats.p99),
                max: _ms(uiStats.max)),
            _MetricLine(
                label: 'raster',
                avg: _ms(rasterStats.avg),
                p95: _ms(rasterStats.p95),
                p99: _ms(rasterStats.p99),
                max: _ms(rasterStats.max)),
            _MetricLine(
                label: 'total',
                avg: _ms(totalStats.avg),
                p95: _ms(totalStats.p95),
                p99: _ms(totalStats.p99),
                max: _ms(totalStats.max)),
            _MetricLine(
                label: 'buildHits',
                avg: '${buildHitStats.avg}',
                p95: '${buildHitStats.p95}',
                p99: '${buildHitStats.p99}',
                max: '${buildHitStats.max}'),
            _MetricLine(
                label: 'vsync',
                avg: _ms(vsyncStats.avg),
                p95: _ms(vsyncStats.p95),
                p99: _ms(vsyncStats.p99),
                max: _ms(vsyncStats.max)),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: running ? null : onStart,
              icon: Icon(running
                  ? Icons.hourglass_top_rounded
                  : Icons.play_arrow_rounded),
              label: Text(running ? 'Running...' : 'Run Benchmark'),
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(int micros) {
    if (micros >= 16000) return const Color(0xFFB3261E);
    if (micros >= 8000) return const Color(0xFFBC6C25);
    return const Color(0xFF2D6A4F);
  }
}

class _PerfGauge extends StatelessWidget {
  const _PerfGauge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.avg,
    required this.p95,
    required this.p99,
    required this.max,
  });

  final String label;
  final String avg;
  final String p95;
  final String p99;
  final String max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label  avg $avg  p95 $p95  p99 $p99  max $max',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

class _ComparePanel extends StatelessWidget {
  const _ComparePanel(
      {required this.screenAdapt, required this.flutterScreenUtil});

  final _BenchmarkSnapshot? screenAdapt;
  final _BenchmarkSnapshot? flutterScreenUtil;

  String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (screenAdapt == null && flutterScreenUtil == null)
      return const SizedBox.shrink();

    final winner = _winner(screenAdapt, flutterScreenUtil);
    final hasBoth = screenAdapt != null && flutterScreenUtil != null;
    final uiP95Delta =
        hasBoth ? (flutterScreenUtil!.ui.p95 - screenAdapt!.ui.p95) : null;
    final totalP95Delta = hasBoth
        ? (flutterScreenUtil!.total.p95 - screenAdapt!.total.p95)
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E2DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Latest Comparison',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          if (hasBoth)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DeltaPill(
                  label: 'ui p95',
                  deltaMicros: uiP95Delta!,
                  baselineMicros: screenAdapt!.ui.p95,
                ),
                _DeltaPill(
                  label: 'total p95',
                  deltaMicros: totalP95Delta!,
                  baselineMicros: screenAdapt!.total.p95,
                ),
              ],
            )
          else
            const Text('先把两个 Tab 都跑完，系统会自动给出差值与百分比。',
                style: TextStyle(fontSize: 12, color: Color(0xFF666257))),
          if (winner != null) ...[
            const SizedBox(height: 8),
            Text(
              winner == 'draw' ? '结果接近：两边 ui p95 相同。' : '当前胜出（ui p95）: $winner',
              style: TextStyle(
                fontSize: 12,
                color: winner == 'draw'
                    ? const Color(0xFF6A6254)
                    : const Color(0xFF2D6A4F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final cardWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _CompareCard(
                    width: cardWidth,
                    title: 'screen_adapt',
                    accent: const Color(0xFF2D6A4F),
                    snapshot: screenAdapt,
                    ms: _ms,
                    highlight: winner == 'screen_adapt',
                  ),
                  _CompareCard(
                    width: cardWidth,
                    title: 'flutter_screenutil',
                    accent: const Color(0xFFBC6C25),
                    snapshot: flutterScreenUtil,
                    ms: _ms,
                    highlight: winner == 'flutter_screenutil',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String? _winner(_BenchmarkSnapshot? a, _BenchmarkSnapshot? b) {
    if (a == null || b == null) return null;
    if (a.ui.p95 == b.ui.p95) return 'draw';
    return a.ui.p95 < b.ui.p95 ? 'screen_adapt' : 'flutter_screenutil';
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({
    required this.label,
    required this.deltaMicros,
    required this.baselineMicros,
  });

  final String label;
  final int deltaMicros;
  final int baselineMicros;

  @override
  Widget build(BuildContext context) {
    final slower = deltaMicros > 0;
    final faster = deltaMicros < 0;
    final ratio =
        baselineMicros == 0 ? 0.0 : (deltaMicros / baselineMicros * 100);
    final color = slower
        ? const Color(0xFFB3261E)
        : faster
            ? const Color(0xFF2D6A4F)
            : const Color(0xFF6A6254);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label ${deltaMicros >= 0 ? '+' : ''}${(deltaMicros / 1000).toStringAsFixed(1)}ms (${ratio >= 0 ? '+' : ''}${ratio.toStringAsFixed(1)}%)',
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.width,
    required this.title,
    required this.accent,
    required this.snapshot,
    required this.ms,
    required this.highlight,
  });

  final double width;
  final String title;
  final Color accent;
  final _BenchmarkSnapshot? snapshot;
  final String Function(int micros) ms;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? accent.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlight ? accent : accent.withValues(alpha: 0.35),
            width: highlight ? 1.6 : 1),
      ),
      child: snapshot == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontWeight: FontWeight.w800, color: accent)),
                const SizedBox(height: 8),
                const Text('No completed run yet.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF666257))),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: accent))),
                    if (highlight)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('WIN',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${snapshot!.runs} runs',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF666257))),
                const SizedBox(height: 8),
                Text(
                    'ui p95 ${ms(snapshot!.ui.p95)}  p99 ${ms(snapshot!.ui.p99)}  max ${ms(snapshot!.ui.max)}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                    'total p95 ${ms(snapshot!.total.p95)}  p99 ${ms(snapshot!.total.p99)}  max ${ms(snapshot!.total.max)}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                    'buildHits p95 ${snapshot!.buildHits.p95}  p99 ${snapshot!.buildHits.p99}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11)),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE3E2DA)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('Export Snapshot · $modeLabel',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('$runs FrameTiming samples'),
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

class _BuildCounter {
  int _frameHits = 0;

  void hit() => _frameHits++;

  void resetFrame() => _frameHits = 0;

  int takeFrameHits() {
    final hits = _frameHits;
    _frameHits = 0;
    return hits;
  }
}

class _BuildCountScope extends InheritedWidget {
  const _BuildCountScope({required this.counter, required super.child});

  final _BuildCounter counter;

  static _BuildCounter? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_BuildCountScope>()
        ?.counter;
  }

  @override
  bool updateShouldNotify(_BuildCountScope oldWidget) =>
      !identical(counter, oldWidget.counter);
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

class _FeedCardSA extends StatelessWidget {
  const _FeedCardSA({required this.level});

  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    final isSimple = level == _BenchLevel.simple;
    final isStress = level == _BenchLevel.stress;

    if (isStress) {
      return const _StressCardSARef();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(18)),
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFE7E1D7))),
          boxShadow: [
            BoxShadow(
                color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BuildProbe(child: _CardHeaderSA(level: level)),
              const SizedBox(height: 10),
              _BuildProbe(child: _ConstParagraph(level: level)),
              const SizedBox(height: 10),
              _BuildProbe(child: _ConstGridRow()),
              if (!isSimple) ...[
                const SizedBox(height: 10),
                _BuildProbe(child: _ConstGridRow()),
                const SizedBox(height: 10),
                _BuildProbe(child: _ConstTagWrap(level: level)),
              ],
              if (isStress) ...[
                const SizedBox(height: 10),
                _BuildProbe(child: _ConstTagWrap(level: level)),
              ],
              const SizedBox(height: 10),
              _BuildProbe(child: _ConstActionRow()),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeaderSA extends StatelessWidget {
  const _CardHeaderSA({required this.level});

  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    final levelLabel = switch (level) {
      _BenchLevel.simple => 'simple',
      _BenchLevel.medium => 'medium',
      _BenchLevel.stress => 'stress',
    };

    return Row(
      children: [
        const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1F3C88),
            child: Icon(Icons.bolt_rounded, color: Colors.white, size: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Benchmark Node',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text('screen_adapt · const-heavy · $levelLabel',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF666257))),
            ],
          ),
        ),
        const Icon(Icons.more_horiz, size: 18, color: Color(0xFF8B8578)),
      ],
    );
  }
}

class _ConstParagraph extends StatelessWidget {
  const _ConstParagraph({required this.level});

  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Same ${_levelItemCount(level)}-card tree, eager rebuild ${_levelRuns(level)} runs; const subtree keeps deep sections reusable.',
      style:
          const TextStyle(height: 1.35, fontSize: 12, color: Color(0xFF3B372F)),
    );
  }
}

class _ConstGridRow extends StatelessWidget {
  const _ConstGridRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _ConstMetricBox(label: 'UI', value: 'stable')),
        SizedBox(width: 8),
        Expanded(child: _ConstMetricBox(label: 'Tail', value: 'low')),
        SizedBox(width: 8),
        Expanded(child: _ConstMetricBox(label: 'Reuse', value: 'high')),
      ],
    );
  }
}

class _ConstMetricBox extends StatelessWidget {
  const _ConstMetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B675F))),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ConstTagWrap extends StatelessWidget {
  const _ConstTagWrap({required this.level});

  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        const _ConstTag('const subtree'),
        _ConstTag('${_levelItemCount(level)} cards'),
        _ConstTag('${_levelRuns(level)} runs'),
        const _ConstTag('frame timing'),
      ],
    );
  }
}

class _ConstTag extends StatelessWidget {
  const _ConstTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: const TextStyle(fontSize: 10, color: Color(0xFF24538C))),
    );
  }
}

class _ConstActionRow extends StatelessWidget {
  const _ConstActionRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.insights_outlined, size: 14, color: Color(0xFF666257)),
        SizedBox(width: 4),
        Text('Observe p95/p99/max & build hits',
            style: TextStyle(fontSize: 11, color: Color(0xFF666257))),
      ],
    );
  }
}

class _FeedCardSU extends StatelessWidget {
  const _FeedCardSU(
      {required this.tick, required this.index, required this.level});

  final int tick;
  final int index;
  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    final isSimple = level == _BenchLevel.simple;
    final isStress = level == _BenchLevel.stress;

    if (isStress) {
      return _StressCardSURef(tick: tick, index: index);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.w, 16.w, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFFE7E1D7)),
          boxShadow: [
            BoxShadow(
                color: const Color(0x11000000),
                blurRadius: 16.r,
                offset: Offset(0, 8.w)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BuildProbe(child: _CardHeaderSU(level: level)),
              SizedBox(height: 10.w),
              _BuildProbe(
                  child: _DynamicParagraph(
                      tick: tick, index: index, level: level)),
              SizedBox(height: 10.w),
              _BuildProbe(child: _DynamicGridRow(tick: tick, index: index)),
              if (!isSimple) ...[
                SizedBox(height: 10.w),
                _BuildProbe(
                    child: _DynamicGridRow(tick: tick + 1, index: index + 1)),
                SizedBox(height: 10.w),
                _BuildProbe(
                    child: _DynamicTagWrap(
                        tick: tick, index: index, level: level)),
              ],
              if (isStress) ...[
                SizedBox(height: 10.w),
                _BuildProbe(
                    child: _DynamicTagWrap(
                        tick: tick + 2, index: index + 2, level: level)),
              ],
              SizedBox(height: 10.w),
              _BuildProbe(child: _DynamicActionRow(tick: tick)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeaderSU extends StatelessWidget {
  const _CardHeaderSU({required this.level});

  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    final levelLabel = switch (level) {
      _BenchLevel.simple => 'simple',
      _BenchLevel.medium => 'medium',
      _BenchLevel.stress => 'stress',
    };

    return Row(
      children: [
        CircleAvatar(
            radius: 16.w,
            backgroundColor: const Color(0xFFBC6C25),
            child: Icon(Icons.auto_graph_rounded,
                color: Colors.white, size: 16.sp)),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Benchmark Node',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp)),
              Text('flutter_screenutil · helper-heavy · $levelLabel',
                  style: TextStyle(
                      fontSize: 11.sp, color: const Color(0xFF666257))),
            ],
          ),
        ),
        Icon(Icons.more_horiz, size: 18.sp, color: const Color(0xFF8B8578)),
      ],
    );
  }
}

class _DynamicParagraph extends StatelessWidget {
  const _DynamicParagraph(
      {required this.tick, required this.index, required this.level});

  final int tick;
  final int index;
  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    final phase = (tick + index) % 3;
    final label = phase == 0
        ? 'warming'
        : phase == 1
            ? 'sampling'
            : 'spiking';
    return Text(
      'Same ${_levelItemCount(level)}-card tree under eager rebuild (${_levelRuns(level)} runs). Phase: $label.',
      style: TextStyle(
          height: 1.35, fontSize: 12.sp, color: const Color(0xFF3B372F)),
    );
  }
}

class _DynamicGridRow extends StatelessWidget {
  const _DynamicGridRow({required this.tick, required this.index});

  final int tick;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final active = (tick + index + i).isEven;
        final label = i == 0
            ? 'UI'
            : i == 1
                ? 'Tail'
                : 'Reuse';
        final value = i == 0
            ? 't${(tick + i) % 10}'
            : i == 1
                ? 'p${(tick + index) % 7}'
                : active
                    ? 'mid'
                    : 'low';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 8.w),
            child: Container(
              padding: EdgeInsets.fromLTRB(8.w, 8.w, 8.w, 8.w),
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xFFFFEFD8) : const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                    color:
                        active ? const Color(0xFFFFB86A) : Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10.sp, color: const Color(0xFF6B675F))),
                  SizedBox(height: 4.w),
                  Text(value,
                      style: TextStyle(
                          fontSize: 12.sp, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
      }, growable: false),
    );
  }
}

class _DynamicTagWrap extends StatelessWidget {
  const _DynamicTagWrap(
      {required this.tick, required this.index, required this.level});

  final int tick;
  final int index;
  final _BenchLevel level;

  @override
  Widget build(BuildContext context) {
    final dynamicTag = 'phase-${(tick + index) % 5}';
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.w,
      children: [
        const _DynamicTag('helper sizing'),
        _DynamicTag('${_levelItemCount(level)} cards'),
        _DynamicTag('${_levelRuns(level)} runs'),
        _DynamicTag(dynamicTag),
      ],
    );
  }
}

class _DynamicTag extends StatelessWidget {
  const _DynamicTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.w),
      decoration: BoxDecoration(
          color: const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.circular(999.r)),
      child: Text(text,
          style: TextStyle(fontSize: 10.sp, color: const Color(0xFF24538C))),
    );
  }
}

class _DynamicActionRow extends StatelessWidget {
  const _DynamicActionRow({required this.tick});

  final int tick;

  @override
  Widget build(BuildContext context) {
    final hot = tick.isOdd;
    return Row(
      children: [
        Icon(
            hot ? Icons.local_fire_department_rounded : Icons.insights_outlined,
            size: 14.sp,
            color: hot ? const Color(0xFFB3261E) : const Color(0xFF666257)),
        SizedBox(width: 4.w),
        Text(
            hot
                ? 'Hot frame pressure in progress'
                : 'Observe p95/p99/max & build hits',
            style: TextStyle(
                fontSize: 11.sp,
                color:
                    hot ? const Color(0xFFB3261E) : const Color(0xFF666257))),
      ],
    );
  }
}

class _StressCardSARef extends StatelessWidget {
  const _StressCardSARef();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFE7E1D7))),
          boxShadow: [
            BoxShadow(
                color: Color(0x11000000), blurRadius: 20, offset: Offset(0, 10))
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BuildProbe(child: _StressHeaderSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _StressHeroSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _StressInsightSA()),
              SizedBox(height: 12),
              _BuildProbe(child: _StressMatrixSARef()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StressHeaderSA extends StatelessWidget {
  const _StressHeaderSA();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1F3C88),
            child:
                Icon(Icons.auto_graph_rounded, color: Colors.white, size: 16)),
        SizedBox(width: 8),
        Expanded(
            child: Text('Case A / Benchmark Node · stress',
                style: TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _StressHeroSA extends StatelessWidget {
  const _StressHeroSA();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF123458), Color(0xFF2E6F95)]),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Const Reuse Bias',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          SizedBox(height: 6),
          Text('144 cards · 56 runs · eager rebuild',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StressInsightSA extends StatelessWidget {
  const _StressInsightSA();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Stress reference : keep deep sections const so BuildProbe hits should remain lower across 56 runs.',
      style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF3B372F)),
    );
  }
}

class _StressMatrixSARef extends StatelessWidget {
  const _StressMatrixSARef();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _BuildProbe(child: _StressCellSARef(label: 'P0')),
        _BuildProbe(child: _StressCellSARef(label: 'P1')),
        _BuildProbe(child: _StressCellSARef(label: 'P2')),
        _BuildProbe(child: _StressCellSARef(label: 'P3')),
        _BuildProbe(child: _StressCellSARef(label: 'P4')),
        _BuildProbe(child: _StressCellSARef(label: 'P5')),
      ],
    );
  }
}

class _StressCellSARef extends StatelessWidget {
  const _StressCellSARef({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF7F4EE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7E1D7))),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _StressCardSURef extends StatelessWidget {
  const _StressCardSURef({required this.tick, required this.index});

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
                offset: Offset(0, 10.h))
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BuildProbe(child: _StressHeaderSU()),
              SizedBox(height: 12.h),
              _BuildProbe(child: _StressHeroSU()),
              SizedBox(height: 12.h),
              _BuildProbe(child: _StressInsightSU()),
              SizedBox(height: 12.h),
              _BuildProbe(child: _StressMatrixSURef(tick: tick, index: index)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StressHeaderSU extends StatelessWidget {
  const _StressHeaderSU();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
            radius: 16.w,
            backgroundColor: const Color(0xFFBC6C25),
            child: Icon(Icons.auto_graph_rounded,
                color: Colors.white, size: 16.sp)),
        SizedBox(width: 8.w),
        Expanded(
            child: Text('Case B / Benchmark Node · stress',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp))),
      ],
    );
  }
}

class _StressHeroSU extends StatelessWidget {
  const _StressHeroSU();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF123458), Color(0xFF2E6F95)]),
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sizing Helper Bias',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18.sp)),
          SizedBox(height: 6.h),
          Text('144 cards · 56 runs · eager rebuild',
              style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
        ],
      ),
    );
  }
}

class _StressInsightSU extends StatelessWidget {
  const _StressInsightSU();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Stress reference style from tst.dart: dynamic helper-sized sections reactivate more deeply on each rebuild frame.',
      style: TextStyle(
          fontSize: 12.sp, height: 1.35, color: const Color(0xFF3B372F)),
    );
  }
}

class _StressMatrixSURef extends StatelessWidget {
  const _StressMatrixSURef({required this.tick, required this.index});

  final int tick;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: List.generate(6, (slot) {
        final v = (tick + index + slot) % 10;
        final active = v.isEven;
        return _BuildProbe(
          child: Container(
            width: 68.w,
            padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFF1E0) : const Color(0xFFF7F4EE),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                  color: active
                      ? const Color(0xFFFFB86A)
                      : const Color(0xFFE7E1D7)),
            ),
            child: Text('P$slot t$v',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? const Color(0xFF8E4A00)
                        : const Color(0xFF2E2A24))),
          ),
        );
      }, growable: false),
    );
  }
}
