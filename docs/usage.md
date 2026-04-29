# `screen_adapt` 使用指南

本文档只回答两个问题：

- 怎么接入
- 遇到局部特殊场景时该用哪个能力

如果你想看底层原理，读 [Concept.md](../../docs/concepts.md)；如果你想看当前限制，读 [KnownIssues.md](../../docs/known-issues.md)。

## 1. 接入

### 在 `main()` 里初始化 binding

```dart
import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    scaleText: true,
    supportSystemTextScale: true,
  );
  runApp(const MyApp());
}
```

这是唯一必须的接入步骤。

初始化之后，Flutter 的全局逻辑坐标系会被映射到你的设计稿尺寸语义上。

### 字体策略开关

`DesignSizeWidgetsFlutterBinding.ensureInitialized(...)` 还提供两个和字体相关的参数：

- `scaleText`
  字体是否跟随全局适配一起缩放
- `supportSystemTextScale`
  是否保留系统字体缩放设置

示例：

```dart
DesignSizeWidgetsFlutterBinding.ensureInitialized(
  const Size(375, 667),
  scaleText: true,
  supportSystemTextScale: false,
);
```

这两个参数的组合含义如下：

- `scaleText: true, supportSystemTextScale: true`
  字体跟随全局适配，同时保留系统大字体
- `scaleText: true, supportSystemTextScale: false`
  字体跟随全局适配，但忽略系统大字体
- `scaleText: false, supportSystemTextScale: true`
  字体不跟随全局适配，但保留系统大字体
- `scaleText: false, supportSystemTextScale: false`
  字体既不跟随全局适配，也不跟随系统大字体

推荐理解：

- 想让整页文字和布局一起按设计稿缩放：`scaleText: true`
- 想让文字保持更接近设备原始阅读尺寸：`scaleText: false`
- 想兼容系统无障碍大字体：`supportSystemTextScale: true`
- 想做强设计稿一致性的展示页或对照 demo：`supportSystemTextScale: false`

注意：

- 当前已经有“初始化时配置字体策略”的开关
- 当前还没有单独公开“运行时动态切换字体策略”的 API
- 运行时切设计稿用的是 `DesignSize.of(context).setDesignSize(...)`
- 字体策略的实际生效点在适配后的 `MediaQuery.textScaler`

## 2. 适配模式

`DesignSizeWidgetsFlutterBinding.ensureInitialized(...)` 支持 `ScreenAdaptType`：

- `ScreenAdaptType.width`
  默认模式，按宽度适配
- `ScreenAdaptType.height`
  按高度适配
- `ScreenAdaptType.min`
  按宽高最小边适配

示例：

```dart
DesignSizeWidgetsFlutterBinding.ensureInitialized(
  const Size(375, 667),
  type: ScreenAdaptType.width,
);
```

## 3. 正常写布局

大多数场景下，你可以直接按设计稿尺寸写 Flutter UI：

```dart
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 180,
          height: 100,
          color: Colors.orange,
          alignment: Alignment.center,
          child: const Text(
            '180 x 100',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
```

这里的 `180 / 100 / 16` 都直接使用设计稿语义，不需要再写 `.w / .h / .sp`。

## 4. 运行时切换设计稿

如果树中存在 `DesignSizeWidget`，可以在运行时切换设计稿：

```dart
DesignSize.of(context).setDesignSize(const Size(390, 844));
DesignSize.of(context).reset();
```

适合：

- 调试不同设计稿基线
- 平板 / 桌面场景下按窗口或断点切换设计稿

## 5. 从 `flutter_screenutil` 迁移

如果历史代码已经广泛使用 `.w / .h / .sp`，推荐分阶段迁移，而不是在同一子树
里同时混用两套尺寸语义。

推荐顺序：

1. `main()` 先切到 `DesignSizeWidgetsFlutterBinding.ensureInitialized(...)`
2. 尚未迁移的旧页面整体包进 `LegacyScreenUtilScope`
3. 兼容壳内部继续保留 `ScreenUtilInit`
4. 按页移除 `.w / .h / .sp`，改成直接写设计稿尺寸
5. 最后删除 `flutter_screenutil` 依赖

### 根接入替换

旧项目常见写法：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  runApp(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => const MyApp(),
    ),
  );
}
```

切到 `screen_adapt` 后：

```dart
import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 812),
    type: ScreenAdaptType.width,
    scaleText: true,
    supportSystemTextScale: true,
  );
  runApp(const MyApp());
}
```

这里的核心变化只有两点：

- 根部初始化从 `ScreenUtilInit` 换成 `DesignSizeWidgetsFlutterBinding.ensureInitialized(...)`
- `MaterialApp` 不再需要包在尺寸初始化 builder 里

如果旧项目以前是在 `ScreenUtilInit.builder` 中直接返回 `MaterialApp`，
迁移后一般只需要把 `MaterialApp` 放回正常的 `MyApp` 结构即可。

示例：

```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_adapt/screen_adapt.dart';

class LegacyProfileRoute extends StatelessWidget {
  const LegacyProfileRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return LegacyScreenUtilScope(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => const LegacyProfilePage(),
      ),
    );
  }
}
```

如果你只想改路由入口，不想每次手写 `LegacyScreenUtilScope`，可以直接用：

```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_adapt/screen_adapt.dart';

Route<void> buildLegacyProfileRoute() {
  return legacyMaterialPageRoute(
    builder: (_) => const LegacyProfilePage(),
    wrapChild: (_, child) => ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => child,
    ),
  );
}
```

如果你项目里这类页面很多，也可以先在业务层封一个 helper：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_adapt/screen_adapt.dart';

Widget legacyScreenUtilPage(
  Widget child, {
  Size designSize = const Size(375, 812),
}) {
  return LegacyScreenUtilScope(
    child: ScreenUtilInit(
      designSize: designSize,
      builder: (_, __) => child,
    ),
  );
}
```

然后你的页面入口就可以写成：

```dart
MaterialPageRoute(
  builder: (_) => legacyScreenUtilPage(const LegacyProfilePage()),
)
```

默认情况下，`LegacyScreenUtilScope` 使用 `UnscaledZoneMode.full`：

- 恢复原始 `MediaQuery`
- 恢复原始布局占位
- 恢复原始绘制和命中测试语义

适合：

- 整页旧模块
- 第三方复杂 legacy 子系统

如果你只想让旧子树恢复原始 `MediaQuery` 和绘制语义，但不想改变父布局槽位，
可以显式传：

```dart
LegacyScreenUtilScope(
  mode: UnscaledZoneMode.contextFallback,
  child: ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => const LegacyPanel(),
  ),
)
```

迁移过程中建议优先替换：

- `180.w / 180.h / 16.sp / 20.r` -> `180 / 180 / 16 / 20`
- `1.sw / 1.sh` -> `MediaQuery.sizeOf(context)` 或标准约束布局
- 读取真实设备指标 -> `ScreenSizeUtils.instance.originData`

## 6. 局部退出全局适配

### `UnscaledZone`

`UnscaledZone` 用于“全局适配已经打开，但局部区域不该跟着适配”的场景。

当前实现按三层能力拼装：

- 恢复 `MediaQuery`
- 恢复绘制与命中测试
- 可选恢复布局占位

#### `contextFallback`

默认模式。

恢复：

- `context`
- `paint`

不恢复：

- `layout`

效果：

- 子树看起来回到原始尺寸
- 但父布局里的占位不变

适合：

- 局部图表、自绘区域、坐标系、标尺
- 只想让子树恢复原尺寸，但不想打乱外层布局节奏

示例：

```dart
UnscaledZone(
  child: Container(
    width: 180,
    height: 100,
    color: Colors.green,
  ),
)
```

#### `full`

恢复：

- `context`
- `layout`
- `paint`

效果：

- 子树看起来回到原始尺寸
- 子树对父布局汇报的占位也一起回退

适合：

- legacy 模块
- 相邻 widget 的排布必须跟着真实尺寸变化
- 局部独立子系统、第三方复杂组件

示例：

```dart
UnscaledZone(
  mode: UnscaledZoneMode.full,
  child: Container(
    width: 180,
    height: 100,
    color: Colors.orange,
  ),
)
```

### 该选哪一个

- 普通页面：不用 `UnscaledZone`
- 只想让子树自己恢复原尺寸，父布局别动：`contextFallback`
- 连占位和相邻排版都要一起回退：`full`

## 7. 原生视图

### `AdaptedPlatformView`

`PlatformView` 在全局适配下常见问题：

- 视觉尺寸失真
- 容器边界和原生内容不对齐
- 点击区域错位

这类场景优先使用 `AdaptedPlatformView`。

## 8. 物理像素绘制

### `PhysicalPixelZone`

用于处理：

- 1px 线条
- 细网格
- 像素级绘制

注意：

- 它主要改变的是内部绘制语义
- 不会自动改变外层父布局占位

## 9. 示例工程怎么读

示例入口：

- [example/lib/main.dart](../../example/lib/main.dart)
- [example/lib/app/home_page.dart](../../example/lib/app/home_page.dart)

专题页：

- [example/lib/pages/adaptation/adaptation_gallery_page.dart](../../example/lib/pages/adaptation/adaptation_gallery_page.dart)
  看全局适配和设计稿切换
- [example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart](../../example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart)
  看 `UnscaledZone` 两种模式、嵌套、row sibling 影响、重进适配态
- [example/lib/pages/input/pointer_events_page.dart](../../example/lib/pages/input/pointer_events_page.dart)
  看点击和拖拽是否准确
- [example/lib/pages/platform_view/platform_view_demo_page.dart](../../example/lib/pages/platform_view/platform_view_demo_page.dart)
  看原生视图补偿
- [example/lib/pages/graphics/physical_pixel_demo_page.dart](../../example/lib/pages/graphics/physical_pixel_demo_page.dart)
  看物理像素语义
- [example/lib/pages/input/keyboard_media_query_page.dart](../../example/lib/pages/input/keyboard_media_query_page.dart)
  看键盘与 `viewInsets`

## 9. 常见判断

- 想按设计稿直接写 UI：初始化 binding
- 想动态切设计稿：`DesignSize.of(context)`
- 想局部恢复原始尺寸但不影响父布局：`UnscaledZone.contextFallback`
- 想连占位一起恢复：`UnscaledZone.full`
- 想处理原生视图尺寸失真：`AdaptedPlatformView`
- 想做 1px / 像素级绘制：`PhysicalPixelZone`
