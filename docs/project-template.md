# `screen_adapt` 项目实施模板

如果你还不清楚整套文档怎么分工，先看 [文档导航](./README.md)。

本文档给开发者直接照抄，用于新项目接入或老项目迁移。

## 1. 目标

在不修改大部分业务布局代码的前提下，让项目使用统一的设计稿尺寸语义。

## 2. 新项目接入模板

### `main()`

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

### 页面写法

```dart
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 343,
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: const Text(
            'screen_adapt',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
```

规则：

- 直接写设计稿尺寸
- 不写 `.w / .h / .sp`
- 优先保留 `const`

## 3. 老项目迁移模板

### 第一步：根部接入

```dart
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

### 第二步：旧页面兼容

```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_adapt/screen_adapt.dart';

class LegacyOrderEntry extends StatelessWidget {
  const LegacyOrderEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return LegacyScreenUtilScope(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => const LegacyOrderPage(),
      ),
    );
  }
}
```

### 第三步：路由层统一包装

```dart
Route<void> buildLegacyRoute() {
  return legacyMaterialPageRoute(
    builder: (_) => const LegacyOrderPage(),
    wrapChild: (_, child) => ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => child,
    ),
  );
}
```

### 第四步：逐步改业务代码

迁移规则：

- `100.w` 改为 `100`
- `16.sp` 改为 `16`
- `1.sw` / `1.sh` 优先改标准布局或 `MediaQuery.sizeOf(context)`
- 整页迁移完成后再移除 `ScreenUtilInit`

## 4. 特殊场景模板

### 局部退出全局适配

```dart
UnscaledZone(
  mode: UnscaledZoneMode.full,
  child: ThirdPartyWidget(),
)
```

选择规则：

- 保留外层占位：`UnscaledZoneMode.contextFallback`
- 连占位一起回退：`UnscaledZoneMode.full`

### 原生视图

优先评估 `AdaptedPlatformView`，不要直接假设 `PlatformView` 在全局适配下行为完全正确。

### 物理像素绘制

需要 1px 线条或像素级绘制时，优先评估 `PhysicalPixelZone`。

## 5. 上线前检查单

- `main()` 已使用 `DesignSizeWidgetsFlutterBinding.ensureInitialized(...)`
- 已显式传入设计稿尺寸
- 已显式传入 `type`
- 页面未继续大面积混用 `.w / .h / .sp`
- 点击、拖拽、滑动验证通过
- 键盘与安全区验证通过
- 原生视图验证通过
- 横屏场景已验证
- 无障碍字体策略已确认

## 6. 推荐默认配置

常规手机业务推荐：

```dart
DesignSizeWidgetsFlutterBinding.ensureInitialized(
  const Size(375, 812),
  type: ScreenAdaptType.width,
  scaleText: true,
  supportSystemTextScale: true,
);
```

## 7. 进一步阅读

- 总方案文档：`docs/adoption-guide.md`
- 日常使用：`docs/usage.md`
- 底层原理：`docs/concepts.md`
- 已知限制：`docs/known-issues.md`
- 问题排查：`docs/troubleshooting.md`
