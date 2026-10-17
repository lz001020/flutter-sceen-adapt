# example

`screen_adapt` 的示例工程。

它不是一个简单的展示页，而是一套按能力拆开的验证集。每个专题页都对应一个具体问题：全局适配是否正确、局部反适配是否正确、点击是否偏移、`PlatformView` 是否失真、物理像素语义是否成立、键盘和 `viewInsets` 是否正确。

## 运行方式

在仓库根目录执行：

```bash
cd example
flutter run
```

示例入口：

- [example/lib/main.dart](example/lib/main.dart)

启动时会先调用：

```dart
DesignSizeWidgetsFlutterBinding.ensureInitialized(
  const Size(375, 667),
);
```

## 建议的阅读顺序

第一次看示例，建议按这个顺序：

1. `Adaptation Gallery`
2. `UnscaledZone`
3. `Pointer Events`
4. `PlatformView`
5. `PhysicalPixelZone`
6. `Keyboard & Insets`

原因很简单：

- 先确认全局适配本身是对的
- 再看局部退出适配
- 然后再看点击、原生视图、物理像素和键盘这类边界场景

## 首页

首页在：

- [example/lib/app/home_page.dart](example/lib/app/home_page.dart)

作用：

- 统一进入所有专题页
- 提供运行时设计稿切换
- 提供当前适配信息的基础观察入口

## 专题页

示例工程按 Android / iOS 单窗口移动设备设计，不能用于判断 Flutter Web、桌面端或多窗口场景的兼容性。

### 1. UnscaledZone

文件：

- [example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart](example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart)

重点看：

- `contextFallback` 和 `full` 的区别
- `context / paint / layout` 三层语义
- 嵌套 `UnscaledZone` 是否重复反缩放
- `DesignSizeWidget` 重进适配态时是否只补缺失层
- 相邻 widget 是否会被原逻辑坑位推开

这一页是理解当前实现最重要的一页。

### 2. Pointer Events

文件：

- [example/lib/pages/input/pointer_events_page.dart](example/lib/pages/input/pointer_events_page.dart)

重点看：

- 点击坐标是否准确
- 拖拽轨迹是否连续
- 命中测试区域是否和视觉区域一致

适合回答：

- 改了全局逻辑坐标系之后，手势有没有跟上

## 如何把示例用于验证

示例工程按 Android / iOS 单窗口移动设备设计，不能用于判断 Flutter Web、桌面端或多窗口场景的兼容性。

你可以按问题类型选页面：

- 全局布局不对：示例首页和主文档
- 局部退出适配不对：`UnscaledZone`
- 点击偏移：`Pointer Events`
- 原生视图、物理像素和键盘场景：参考主文档对应 API 小节

## 和主文档的关系

- 根说明： [README.md](README.md)
- 接入指南： [docs/usage.md](docs/usage.md)
- 设计原理： [docs/concepts.md](docs/concepts.md)
- 已知问题： [docs/known-issues.md](docs/known-issues.md)
- 排查指南： [docs/troubleshooting.md](docs/troubleshooting.md)
