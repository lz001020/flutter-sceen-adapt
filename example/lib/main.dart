import 'package:design_scale/design_scale.dart';
import 'package:flutter/material.dart';

void main() {
  // Initialize before runApp or any other binding. All dimensions below are
  // design coordinates; no per-widget .w/.h conversion is needed.
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 812),
    type: ScreenAdaptType.width,
    supportSystemTextScale: true,
  );
  runApp(const CoffeeApp());
}

class CoffeeApp extends StatelessWidget {
  const CoffeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '街角咖啡',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF72513D)),
        scaffoldBackgroundColor: const Color(0xFFFAF7F2),
      ),
      home: const CoffeeOrderPage(),
    );
  }
}

class CoffeeOrderPage extends StatefulWidget {
  const CoffeeOrderPage({super.key});

  @override
  State<CoffeeOrderPage> createState() => _CoffeeOrderPageState();
}

class _CoffeeOrderPageState extends State<CoffeeOrderPage> {
  final _note = TextEditingController();
  int _quantity = 1;
  bool _iced = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('街角咖啡')),
      // Scaffold handles the keyboard in adapted logical coordinates. A
      // scrollable body also keeps the form reachable on short screens.
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _CoffeeDetails(),
            const SizedBox(height: 24),
            Text('选择温度', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: const Text('热饮'),
                  selected: !_iced,
                  onSelected: (_) => setState(() => _iced = false),
                ),
                ChoiceChip(
                  label: const Text('冰饮'),
                  selected: _iced,
                  onSelected: (_) => setState(() => _iced = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('数量')),
                IconButton(
                  tooltip: '减少数量',
                  onPressed:
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_quantity', key: const ValueKey('quantity')),
                IconButton(
                  tooltip: '增加数量',
                  onPressed:
                      _quantity < 9 ? () => setState(() => _quantity++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '订单备注',
                hintText: '例如：少冰',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onPressed: _confirmOrder,
              child: Text('确认订单 · ¥${28 * _quantity}'),
            ),
            const SizedBox(height: 12),
            const Text(
              '示例订单，仅在本地展示，不会付款。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmOrder() {
    FocusScope.of(context).unfocus();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('订单确认'),
        content: SingleChildScrollView(
          child: Text(
            '燕麦拿铁 · ${_iced ? '冰饮' : '热饮'} × $_quantity\n'
            '合计 ¥${28 * _quantity}\n'
            '备注：${_note.text.trim().isEmpty ? '无' : _note.text.trim()}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回菜单'),
          ),
        ],
      ),
    );
  }
}

// The static product subtree stays const when order options change.
class _CoffeeDetails extends StatelessWidget {
  const _CoffeeDetails();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFE5D8),
            borderRadius: BorderRadius.circular(24),
          ),
          child:
              const Icon(Icons.local_cafe, size: 80, color: Color(0xFF72513D)),
        ),
        const SizedBox(height: 20),
        const Text('燕麦拿铁',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('浓缩咖啡与燕麦奶，柔和醇香。', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        const Text('¥28',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
