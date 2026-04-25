import 'dart:io';

import 'package:example/shared/demo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_adapt/screen_adapt.dart';

class PlatformViewDemoPage extends StatefulWidget {
  const PlatformViewDemoPage({super.key});

  @override
  State<PlatformViewDemoPage> createState() => _PlatformViewDemoPageState();
}

class _PlatformViewDemoPageState extends State<PlatformViewDemoPage> {
  static const String _viewType = 'example_view';

  MethodChannel? _normalChannel;
  MethodChannel? _adaptedChannel;

  int _normalClicks = 0;
  int _adaptedClicks = 0;

  static const _presets = [
    ('0.5x (750dp)', 750.0),
    ('1.0x (375dp)', 375.0),
    ('2.0x (188dp)', 188.0),
  ];
  int _selectedPreset = 1;

  @override
  void dispose() {
    _normalChannel?.setMethodCallHandler(null);
    _adaptedChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _applyPreset(int index) {
    final w = _presets[index].$2;
    DesignSize.of(context).setDesignSize(Size(w, w * 667 / 375));
    setState(() => _selectedPreset = index);
  }

  void _bindChannel(int viewId, bool adapted) {
    final ch = MethodChannel('$_viewType/$viewId');
    ch.setMethodCallHandler((call) async {
      if (call.method != 'onNativeClick' || !mounted) return;
      final args = call.arguments as Map;
      final count = (args['count'] as num).toInt();
      setState(() {
        if (adapted) {
          _adaptedClicks = count;
        } else {
          _normalClicks = count;
        }
      });
    });
    if (adapted) {
      _adaptedChannel = ch;
    } else {
      _normalChannel = ch;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('PlatformView Demo')),
        body: const Center(child: Text('Android only')),
      );
    }

    final scale = ScreenSizeUtils.instance.scale;

    return DemoPageScaffold(
      title: 'PlatformView',
      subtitle:
          '此页用于验证 Flutter 全局适配后，原生视图如果不做补偿会发生尺寸失真；使用 AdaptedPlatformView 后应重新对齐。',
      trailing: Wrap(
        spacing: 8,
        children: List.generate(
          _presets.length,
          (i) {
            return ChoiceChip(
              label: Text(_presets[i].$1),
              selected: _selectedPreset == i,
              onSelected: (_) => _applyPreset(i),
            );
          },
        ),
      ),
      children: [
        DemoCard(
          title: 'Runtime State',
          child: Text(
            'scale = ${scale.toStringAsFixed(3)}   adapted DPR = ${ScreenSizeUtils.instance.data.devicePixelRatio.toStringAsFixed(2)}',
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'Comparison',
          subtitle: '黄色区域 = Flutter 容器边界。原生视图未填满或点击异常时，说明未跟随当前适配坐标系。',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _column(
                  label: '未适配',
                  labelColor: Colors.red,
                  clicks: _normalClicks,
                  child: AndroidView(
                    viewType: _viewType,
                    creationParams: const {
                      'text': 'Normal',
                      'message': 'No fix'
                    },
                    creationParamsCodec: const StandardMessageCodec(),
                    onPlatformViewCreated: (id) => _bindChannel(id, false),
                  ),
                  adapted: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _column(
                  label: '已适配',
                  labelColor: Colors.green,
                  clicks: _adaptedClicks,
                  child: AdaptedPlatformView(
                    child: AndroidView(
                      viewType: _viewType,
                      creationParams: const {
                        'text': 'Adapted',
                        'message': 'Fixed'
                      },
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (id) => _bindChannel(id, true),
                    ),
                  ),
                  adapted: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _column({
    required String label,
    required Color labelColor,
    required int clicks,
    required Widget child,
    required bool adapted,
  }) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: labelColor, fontSize: 13)),
        const SizedBox(height: 6),
        _demoBox(child: child, adapted: adapted),
        const SizedBox(height: 4),
        Text('clicks: $clicks', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _demoBox({required Widget child, required bool adapted}) {
    return Stack(
      children: [
        Container(
          height: 200,
          color: Colors.yellow.shade300,
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: adapted ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
