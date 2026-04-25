import 'package:example/shared/demo_widgets.dart';
import 'package:flutter/material.dart';

class KeyboardMediaQueryPage extends StatefulWidget {
  const KeyboardMediaQueryPage({super.key});

  @override
  State<KeyboardMediaQueryPage> createState() => _KeyboardMediaQueryPageState();
}

class _KeyboardMediaQueryPageState extends State<KeyboardMediaQueryPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rootMediaQuery = MediaQuery.of(context);

    return DemoPageScaffold(
      title: 'Keyboard & Insets',
      subtitle:
          '此页同时展示两个层级的 MediaQuery：滚动区里的 Root MediaQuery（进入 Scaffold 前），以及 Scaffold Body MediaQuery（进入 Scaffold 后）。诊断卡不再固定在底部，避免键盘弹起时被遮挡。',
      children: [
        DiagnosticsCard(
          title: 'Root MediaQuery',
          data: rootMediaQuery,
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) => DiagnosticsCard(
            title: 'Scaffold Body MediaQuery',
            data: MediaQuery.of(context),
          ),
        ),
        const SizedBox(height: 12),
        _KeyboardInputDemo(
          controller: _controller,
          focusNode: _focusNode,
          rootMediaQuery: rootMediaQuery,
        ),
      ],
    );
  }
}

class _KeyboardInputDemo extends StatelessWidget {
  const _KeyboardInputDemo({
    required this.controller,
    required this.focusNode,
    required this.rootMediaQuery,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final MediaQueryData rootMediaQuery;

  @override
  Widget build(BuildContext context) {
    final bodyMediaQuery = MediaQuery.of(context);

    return DemoCard(
      title: 'Input Area',
      subtitle:
          '点击输入框拉起软键盘。上方这一行会同时展示 Root Insets 和 Body Insets，下面的输入区用于触发键盘变化。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InsetStatusCard(
                  title: 'Root Insets',
                  accentColor: const Color(0xFFC96F2D),
                  mediaQuery: rootMediaQuery,
                  activeText: 'System keyboard inset is visible here.',
                  inactiveText: 'Keyboard hidden at the root level.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InsetStatusCard(
                  title: 'Body Insets',
                  accentColor: const Color(0xFF2E6FD4),
                  mediaQuery: bodyMediaQuery,
                  activeText: 'Body still sees a bottom inset.',
                  inactiveText:
                      'Scaffold body usually removes bottom viewInsets and shrinks the layout instead.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF4EEE3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message Composer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type something and open the keyboard...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => focusNode.requestFocus(),
                      child: const Text('Focus'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => focusNode.unfocus(),
                      child: const Text('Unfocus'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsetStatusCard extends StatelessWidget {
  const _InsetStatusCard({
    required this.title,
    required this.accentColor,
    required this.mediaQuery,
    required this.activeText,
    required this.inactiveText,
  });

  final String title;
  final Color accentColor;
  final MediaQueryData mediaQuery;
  final String activeText;
  final String inactiveText;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: keyboardVisible ? 76 : 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: keyboardVisible ? 0.22 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              keyboardVisible ? activeText : inactiveText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF333333),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          _metricLine('size', formatSize(mediaQuery.size)),
          _metricLine('padding.bottom',
              mediaQuery.padding.bottom.toStringAsFixed(1)),
          _metricLine('viewPadding.bottom',
              mediaQuery.viewPadding.bottom.toStringAsFixed(1)),
          _metricLine('viewInsets.bottom',
              mediaQuery.viewInsets.bottom.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _metricLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}
