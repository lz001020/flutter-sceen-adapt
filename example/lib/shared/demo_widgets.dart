import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

class DesignPreset {
  const DesignPreset({
    required this.label,
    required this.size,
  });

  final String label;
  final Size size;
}

const demoPresets = <DesignPreset>[
  DesignPreset(label: '320 x 568', size: Size(320, 568)),
  DesignPreset(label: '375 x 667', size: Size(375, 667)),
  DesignPreset(label: '390 x 844', size: Size(390, 844)),
  DesignPreset(label: '768 x 1024', size: Size(768, 1024)),
];

class DemoPageScaffold extends StatelessWidget {
  const DemoPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
    this.bottomPanel,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final Widget? bottomPanel;

  @override
  Widget build(BuildContext context) {
    final listView = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPanel == null ? 24 : 12),
      children: [
        if (trailing != null) trailing!,
        _IntroCard(subtitle: subtitle),
        const SizedBox(height: 12),
        const DesignControlCard(),
        const SizedBox(height: 12),
        ...children,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: bottomPanel == null
          ? listView
          : Column(
              children: [
                Expanded(child: listView),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: bottomPanel!,
                ),
              ],
            ),
    );
  }
}

class DesignControlCard extends StatelessWidget {
  const DesignControlCard({super.key});

  @override
  Widget build(BuildContext context) {
    final utils = ScreenSizeUtils.instance;
    final adapted = MediaQuery.of(context);
    final origin = utils.originData ?? adapted;
    final currentDesignSize = utils.designSize;

    return DemoCard(
      title: 'Runtime Controls',
      subtitle: '切换设计稿尺寸，观察 scale、MediaQuery、交互命中和局部反适配的变化。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in demoPresets)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: _matchesPreset(currentDesignSize, preset.size),
                  onSelected: (_) {
                    DesignSize.of(context).setDesignSize(preset.size);
                  },
                ),
              OutlinedButton.icon(
                onPressed: () => DesignSize.of(context).reset(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Design',
                value: formatSize(currentDesignSize),
              ),
              _MetricPill(
                label: 'Scale',
                value: utils.scale.toStringAsFixed(3),
              ),
              _MetricPill(
                label: 'Adapted',
                value: formatSize(adapted.size),
              ),
              _MetricPill(
                label: 'Origin',
                value: formatSize(origin.size),
              ),
              _MetricPill(
                label: 'Adapted DPR',
                value: adapted.devicePixelRatio.toStringAsFixed(2),
              ),
              _MetricPill(
                label: 'Origin DPR',
                value: origin.devicePixelRatio.toStringAsFixed(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _matchesPreset(Size current, Size preset) {
    return (current.width - preset.width).abs() < 0.1 &&
        (current.height - preset.height).abs() < 0.1;
  }
}

class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E2DA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF666257),
                  ),
            ),
          ],
          if (title != null || subtitle != null) const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class DemoNavCard extends StatelessWidget {
  const DemoNavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBF2), Color(0xFFF3F6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3E2DA)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1F3C88),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF666257),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiagnosticsCard extends StatelessWidget {
  const DiagnosticsCard({
    super.key,
    required this.title,
    required this.data,
  });

  final String title;
  final MediaQueryData data;

  @override
  Widget build(BuildContext context) {
    return DemoCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricLine('size', formatSize(data.size)),
          _metricLine(
              'devicePixelRatio', data.devicePixelRatio.toStringAsFixed(2)),
          _metricLine('padding', formatInsets(data.padding)),
          _metricLine('viewPadding', formatInsets(data.viewPadding)),
          _metricLine('viewInsets', formatInsets(data.viewInsets)),
        ],
      ),
    );
  }

  Widget _metricLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $value'),
    );
  }
}

class DemoSlot extends StatelessWidget {
  const DemoSlot({
    super.key,
    required this.label,
    required this.child,
    this.width = 180,
    this.height = 140,
  });

  final String label;
  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth.isFinite
            ? math.min(width, constraints.maxWidth)
            : width;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: slotWidth,
                height: height,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0B8),
                  border: Border.all(color: const Color(0xFFE8A400), width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label  $value'),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.subtitle,
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDF6DD), Color(0xFFF0F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.4,
            ),
      ),
    );
  }
}

String formatSize(Size size) {
  return '${size.width.toStringAsFixed(1)} x ${size.height.toStringAsFixed(1)}';
}

String formatInsets(EdgeInsets insets) {
  return 'l:${insets.left.toStringAsFixed(1)} '
      't:${insets.top.toStringAsFixed(1)} '
      'r:${insets.right.toStringAsFixed(1)} '
      'b:${insets.bottom.toStringAsFixed(1)}';
}
