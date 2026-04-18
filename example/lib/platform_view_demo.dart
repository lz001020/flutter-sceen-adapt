import 'dart:io';

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

    return Scaffold(
      appBar: AppBar(title: const Text('PlatformView Adapt Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Force scale preset:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(_presets.length, (i) {
              return ChoiceChip(
                label: Text(_presets[i].$1),
                selected: _selectedPreset == i,
                onSelected: (_) => _applyPreset(i),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'scale = ${scale.toStringAsFixed(3)}   adapted DPR = ${ScreenSizeUtils.instance.data.devicePixelRatio.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            '黄色区域 = Flutter 容器边界。原生视图未填满时可见黄色。',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _column(
                  label: '未适配',
                  labelColor: Colors.red,
                  clicks: _normalClicks,
                  child: AndroidView(
                    viewType: _viewType,
                    creationParams: const {'text': 'Normal', 'message': 'No fix'},
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
                      creationParams: const {'text': 'Adapted', 'message': 'Fixed'},
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (id) => _bindChannel(id, true),
                    ),
                  ),
                  adapted: true,
                ),
              ),
            ],
          ),
        ],
      ),
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
            style: TextStyle(fontWeight: FontWeight.bold, color: labelColor, fontSize: 13)),
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
