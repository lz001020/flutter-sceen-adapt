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

- [example/lib/home_page.dart](example/lib/home_page.dart)

作用：

- 统一进入所有专题页
- 提供运行时设计稿切换
- 提供当前适配信息的基础观察入口

## 专题页

### 1. Adaptation Gallery

文件：

- [example/lib/adaptation_gallery_page.dart](example/lib/adaptation_gallery_page.dart)

重点看：

- 固定设计稿尺寸组件是否整体缩放
- 字体、间距、栅格是否保持设计稿语义
- 当前 `MediaQuery` 是否和适配结果一致

适合回答：

- 全局适配到底有没有生效
- 设计稿切换后是否立即反映到页面

### 2. UnscaledZone

文件：

- [example/lib/unscaled_zone_demo_page.dart](example/lib/unscaled_zone_demo_page.dart)

重点看：

- `contextFallback` 和 `full` 的区别
- `context / paint / layout` 三层语义
- 嵌套 `UnscaledZone` 是否重复反缩放
- `DesignSizeWidget` 重进适配态时是否只补缺失层
- 相邻 widget 是否会被原逻辑坑位推开

这一页是理解当前实现最重要的一页。

### 3. Pointer Events

文件：

- [example/lib/demo3/pointer_test_page.dart](example/lib/demo3/pointer_test_page.dart)

重点看：

- 点击坐标是否准确
- 拖拽轨迹是否连续
- 命中测试区域是否和视觉区域一致

适合回答：

- 改了全局逻辑坐标系之后，手势有没有跟上

### 4. PlatformView

文件：

- [example/lib/platform_view_demo.dart](example/lib/platform_view_demo.dart)

重点看：

- 原生视图在全局适配下未补偿时的失真
- `AdaptedPlatformView` 补偿后的尺寸与点击表现
- Flutter 容器边界和原生内容是否重新对齐

适合回答：

- 为什么普通 `PlatformView` 不能直接放进全局适配环境

### 5. PhysicalPixelZone

文件：

- [example/lib/physical_pixel_demo_page.dart](example/lib/physical_pixel_demo_page.dart)

重点看：

- 1px 线条和细网格在普通逻辑像素下的表现
- `PhysicalPixelZone` 内部 `width: 1` 的物理像素语义

适合回答：

- 为什么有些绘制问题不是全局适配能解决的，而要回到物理像素语义

### 6. Keyboard & Insets

文件：

- [example/lib/keyboard_media_query_page.dart](example/lib/keyboard_media_query_page.dart)

重点看：

- 键盘弹出后 `viewInsets` 是否正确
- 输入区和诊断区是否能一起滚动，避免被键盘遮挡
- `padding / viewPadding / viewInsets` 是否可观测

适合回答：

- 全局适配后，`MediaQuery` 和键盘相关指标是否还可信

## 如何把示例用于验证

你可以按问题类型选页面：

- 全局布局不对：`Adaptation Gallery`
- 局部退出适配不对：`UnscaledZone`
- 点击偏移：`Pointer Events`
- 原生视图尺寸不对：`PlatformView`
- 1px 线条发虚：`PhysicalPixelZone`
- 键盘遮挡 / inset 异常：`Keyboard & Insets`

## 和主文档的关系

- 根说明： [README.md](README.md)
- 接入指南： [lib/doc/Usage.md](lib/doc/Usage.md)
- 设计原理： [lib/doc/Concept.md](lib/doc/Concept.md)
- 已知问题： [lib/doc/KnownIssues.md](lib/doc/KnownIssues.md)
- 排查指南： [lib/doc/Troubleshooting.md](lib/doc/Troubleshooting.md)
