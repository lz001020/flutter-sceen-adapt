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

## Roadmap

这个项目的目标不是再做一组 `.w / .h / .sp` 扩展方法，而是逐步把 Flutter 中的
“设计稿尺寸语义”上移到更底层的运行时链路里。

当前 roadmap 可以概括为：

| 阶段 | 目标 | 核心能力 | 当前状态 |
|---|---|---|---|
| 1 | 手机端全局适配基线 | `DesignSizeWidgetsFlutterBinding`、`ViewConfiguration` 重写、指针事件坐标补偿 | ✅ 已实现 |
| 2 | 补齐全局适配后的例外场景 | `UnscaledZone`、`AdaptedPlatformView`、`PhysicalPixelZone`、字体与 `MediaQuery` / 键盘 / `viewInsets` 行为校准 | ✅ 已实现并持续完善 |
| 3 | 提供可落地的迁移与验证体系 | `flutter_screenutil` 迁移方案、`LegacyScreenUtilScope`、example 专题验证页面、benchmark、已知限制与排查文档 | ✅ 已实现并持续完善 |
| 4 | 向多形态设备策略化演进 | 大屏 / 展开态窗口布局、居中窗口与偏移补偿、可扩展的策略抽象、更清晰的桌面与多终端产品语义 | 🚧 规划中 |
