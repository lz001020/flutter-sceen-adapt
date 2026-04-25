import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

class LayoutBlock extends StatefulWidget {
  const LayoutBlock({super.key});

  @override
  State<LayoutBlock> createState() => _LayoutBlockState();
}

class _LayoutBlockState extends State<LayoutBlock> {
  static const _presets = [
    ('0.5x', 750.0),
    ('1.0x', 375.0),
    ('2.0x', 188.0),
  ];

  int _selectedPreset = 1;
  int _scaledTapCount = 0;
  int _contextTapCount = 0;
  int _fullTapCount = 0;

  void _applyPreset(int index) {
    final width = _presets[index].$2;
    DesignSize.of(context).setDesignSize(Size(width, width * 667 / 375));
    setState(() {
      _selectedPreset = index;
      _scaledTapCount = 0;
      _contextTapCount = 0;
      _fullTapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final utils = ScreenSizeUtils.instance;
    final adapted = MediaQuery.of(context);
    final origin = utils.originData ?? adapted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UnscaledZone Demo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '黄色边框表示父布局槽位。观察 contextFallback 和 full 的占位差异，并点按钮验证命中测试。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_presets.length, (index) {
              return ChoiceChip(
                label: Text(_presets[index].$1),
                selected: _selectedPreset == index,
                onSelected: (_) => _applyPreset(index),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'scale = ${utils.scale.toStringAsFixed(3)}   adapted width = ${adapted.size.width.toStringAsFixed(1)}   origin width = ${origin.size.width.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _DemoSection(
            title: '1. 正常适配',
            subtitle: '作为对照组，卡片宽高和占位都处于适配后的坐标系。',
            child: _SlotFrame(
              child: _DemoCard(
                title: 'Scaled',
                color: Colors.red.shade100,
                tapCount: _scaledTapCount,
                onTap: () => setState(() => _scaledTapCount += 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DemoSection(
            title: '2. UnscaledZone.contextFallback',
            subtitle: '子树 MediaQuery 已回退，但父布局槽位仍然按适配后尺寸计算。',
            child: _SlotFrame(
              child: UnscaledZone(
                child: _DemoCard(
                  title: 'Context Fallback',
                  color: Colors.lightBlue.shade100,
                  tapCount: _contextTapCount,
                  onTap: () => setState(() => _contextTapCount += 1),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DemoSection(
            title: '3. UnscaledZone.full',
            subtitle: '子树上下文、视觉尺寸和父布局占位一起回退到原始坐标系。',
            child: _SlotFrame(
              child: UnscaledZone(
                mode: UnscaledZoneMode.full,
                child: _DemoCard(
                  title: 'Full Unscaled',
                  color: Colors.green.shade100,
                  tapCount: _fullTapCount,
                  onTap: () => setState(() => _fullTapCount += 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoSection extends StatelessWidget {
  const _DemoSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SlotFrame extends StatelessWidget {
  const _SlotFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 180,
        height: 140,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.yellow.shade100,
          border: Border.all(color: Colors.amber.shade700, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.color,
    required this.tapCount,
    required this.onTap,
  });

  final String title;
  final Color color;
  final int tapCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      width: 120,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'mq.width: ${mediaQuery.size.width.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            'dpr: ${mediaQuery.devicePixelRatio.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 11),
          ),
          const Spacer(),
          SizedBox(
            height: 28,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text('tap $tapCount'),
            ),
          ),
        ],
      ),
    );
  }
}
