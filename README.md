# screen_adapter

一种Flutter的屏幕适配方案

## 使用

```dart
void main() {
  // 传入设计稿尺寸
  DesignSizeWidgetsFlutterBinding.ensureInitialized(const Size(375, 667));
  runApp(const MyApp());
}

```