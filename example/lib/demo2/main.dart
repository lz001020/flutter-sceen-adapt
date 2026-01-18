import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaQuery Demo',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const HomePage(),
    );
  }
}

// 定义一个缩放因子，方便理解和修改
const scaleFactor = 2.0;

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    // 1. 获取真实的设备屏幕信息，作为我们修改的基础
    final realMediaQuery = MediaQuery.of(context);

    final fakeSmallScreenData = realMediaQuery.copyWith(
      // 逻辑尺寸变小
        size: realMediaQuery.size ,
        devicePixelRatio: realMediaQuery.devicePixelRatio * scaleFactor,
    );
    final fakeLargeScreenData = realMediaQuery.copyWith(
        devicePixelRatio: realMediaQuery.devicePixelRatio / scaleFactor,
        // textScaleFactor: realMediaQuery.textScaleFactor * scaleFactor
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediaQuery 魔法演示'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            '下面的三个盒子都由同一个 InfoBox Widget 创建，代码宽度写死为 150。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),

          // --- 场景1: 默认环境的盒子 ---
          const Text('1. 默认环境 (基准大小)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const InfoBox(
            label: '默认盒子',
            color: Colors.blue,
          ),
          const Divider(height: 40),

          // --- 场景2: 看起来“被放大”的盒子 ---
          // 在这里，我们用 MediaQuery Widget 包裹 InfoBox，并传入伪造的“小屏幕”数据
          const Text('2. 伪造小屏幕 (看起来更大)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          MediaQuery(
            data: fakeSmallScreenData, // 注入我们伪造的数据
            child: const InfoBox(
              label: '放大盒子',
              color: Colors.green,
            ),
          ),
          const Divider(height: 40),

          // --- 场景3: 看起来“被缩小”的盒子 ---
          // 在这里，我们用另一个 MediaQuery Widget 包裹 InfoBox，并传入伪造的“大屏幕”数据
          const Text('3. 伪造大屏幕 (看起来更小)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          MediaQuery(
            data: fakeLargeScreenData, // 注入我们伪造的数据
            child: const InfoBox(
              label: '缩小盒子',
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一个拥有固定尺寸 (宽150) 的 UI 组件，用于演示。
class InfoBox extends StatelessWidget {
  final String label;
  final Color color;

  const InfoBox({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 这行代码是关键：它会获取离自己最近的 MediaQueryData
    final perceivedMediaQuery = MediaQuery.of(context);
    final perceivedScreenWidth = perceivedMediaQuery.size.width;

    return Container(
      // 尺寸在代码中永远是 150x100
      width: perceivedMediaQuery.devicePixelRatio * 150 ,
      height: perceivedMediaQuery.devicePixelRatio * 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '代码宽度: 150\n感知到的屏幕宽度:\n${perceivedScreenWidth.toStringAsFixed(1)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}