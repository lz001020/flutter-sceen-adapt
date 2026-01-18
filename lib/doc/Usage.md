# `screen_adapt` 使用指南

欢迎使用 `screen_adapt`！这是一个为 Flutter 设计的、侵入性低且高性能的屏幕适配方案。本指南将引导您快速地在您的项目中使用它。

---

## 1. 安装

将 `screen_adapt` 添加到您的 `pubspec.yaml` 文件的 `dependencies` 中：

```yaml
dependencies:
  flutter:
    sdk: flutter
  screen_adapt: ^latest_version # 请替换为最新的版本号
```

然后，在您的项目根目录运行 `flutter pub get` 来安装依赖。

---

## 2. 快速开始：激活适配方案

激活 `screen_adapt` 非常简单，只需在您的 `main.dart` 文件的 `main()` 函数中，在 `runApp()` 之前调用 `DesignSizeWidgetsFlutterBinding.ensureInitialized()` 即可。

**这是唯一必须的步骤！**

```dart
import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart'; // 1. 导入包

void main() {
  // 2. 定义您的设计稿尺寸
  const Size designSize = Size(360, 690);

  // 3. 在 runApp() 前初始化并激活适配方案
  // 您可以在这里选择不同的适配模式
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    designSize,
    type: ScreenAdaptType.width, // 这是默认值，可以省略
  );

  runApp(const MyApp());
}
```

### 选择适配模式 (`ScreenAdaptType`)

`ensureInitialized` 方法的 `type` 参数允许您选择适配的基准：

- **`ScreenAdaptType.width`** (默认): 基于屏幕**宽度**进行缩放。这是最常用的模式，可以确保应用在不同宽度的设备上布局一致。
- **`ScreenAdaptType.height`**: 基于屏幕**高度**进行缩放。适用于内容高度固定的场景，如启动屏或某些全屏页面。
- **`ScreenAdaptType.min`**: 基于屏幕**宽度和高度中的最小值**进行缩放。适用于需要同时在手机和平板上保持相似外观的应用，常用于响应式布局。

**示例：按高度适配**
```dart
DesignSizeWidgetsFlutterBinding.ensureInitialized(
  const Size(360, 690),
  type: ScreenAdaptType.height,
);
```

---

## 3. 进行 UI 布局

一旦激活了 `screen_adapt`，您就可以像往常一样编写 Flutter UI，但有一个巨大的优势：**您可以直接使用设计稿上的尺寸 (dp) 值！**

- **忘记手动计算**：不再需要 `MediaQuery.of(context).size.width * 0.5` 这样的代码。
- **无需扩展方法**：不再需要到处写 `.w`, `.h` 或 `.r`。
- **不影响const优化**: 不再会因为使用 `.w`修饰而无法使用const

**示例：**

假设您的设计稿宽度为 360dp，您想创建一个宽度为 180dp 的红色容器。

```dart
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设计稿尺寸为 360x690'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 这个容器的宽度将自动适配为屏幕宽度的一半
            Container(
              width: 180, // 直接使用设计稿的 dp 值
              height: 100, // 直接使用设计稿的 dp 值
              color: Colors.red,
            ),
            const SizedBox(height: 20), // 间距也直接使用设计稿 dp 值
            const Text(
              '字体大小为 16sp',
              style: TextStyle(
                fontSize: 16, // 字体大小也会自动缩放
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 4. 局部禁用适配: `UnscaledZone`

在某些情况下，您可能希望局部区域不参与全局缩放，以保持其原始的像素尺寸。例如，显示第三方 UI 组件、绘制精确的像素图形等。此时，您可以使用 `UnscaledZone`。

`UnscaledZone` 会在其子树中创建一个“隔离区”，恢复到设备原始的、未经缩放的尺寸体系。

**示例：**

```dart
import 'package:screen_adapt/screen_adapt.dart';

// ...

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // 这是参与全局适配的 Widget
      Container(
        width: 180, 
        height: 100,
        color: Colors.blue, // 在任何设备上都是半屏宽
        child: const Center(child: Text('已适配')),
      ),

      // --- 使用 UnscaledZone 创建一个不适配的区域 ---
      UnscaledZone(
        child: Container(
          width: 180, 
          height: 100,
          color: Colors.green, // 在任何设备上都是 180dp 原始宽度
          child: const Center(child: Text('未适配 (原始尺寸)')),
        ),
      ),
    ],
  );
}
```

**注意**: `UnscaledZone` 已经内置了对嵌套的保护，所以您可以安全地在组件内部使用它，而不用担心意外的嵌套导致布局错误。

---

## 5. 其他高级用法

### 在运行时切换设计稿尺寸

如果您需要动态地改变适配基准，您可以通过 `DesignSize.of(context)` 来访问 `DesignSizeWidgetState` 并调用其方法。

```dart
// 切换到新的设计稿尺寸
DesignSize.of(context).setDesignSize(const Size(750, 1334));

// 重置为不适配状态
DesignSize.of(context).reset();
```

这在使用响应式布局，需要根据窗口大小切换不同设计稿基准时非常有用。

---

恭喜！您现在已经掌握了 `screen_adapt` 的主要用法。开始享受顺滑的屏幕适配开发体验吧！
