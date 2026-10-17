# 排错

| 问题 | 检查方法 |
| --- | --- |
| binding 初始化冲突 | 在其他 binding 创建前初始化适配。自定义 binding 使用 mixin，适配 mixin 放在组合列表最后，见[使用指南](usage.md#组合-binding)。 |
| 找不到 Controller | 在 `runApp` 内的组件上下文中读取，确保位于 binding 自动挂载的根节点下。 |
| 点击位置不一致 | 检查插件是否在初始化后覆盖 `onPointerDataPacket`，并记录原始与适配后的 DPR。 |
| 字体变化不符合预期 | 检查 `scaleText` 与 `supportSystemTextScale`，分别控制设计缩放和系统字号。 |
| 键盘遮挡内容 | 检查页面是否支持滚动，以及 Scaffold 的键盘避让设置；对照 `metrics.origin.viewInsets` 和 `metrics.adapted.viewInsets`。仓库内可用 [demo 键盘页面](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/demo/lib/pages/input/keyboard_test_page.dart)复现。 |
| 关闭后又恢复适配 | `setEnabled(false)` 会保持关闭；检查业务是否再次调用了会启用适配的 `configure` 或 `setDesignSize`。 |
| 旧导入或 API 找不到 | 按[迁移说明](migration-0.2.md)更新。 |

## iOS 模拟器构建

Flutter 3.35.7 与当前 Xcode 组合曾出现 `lipo verify_arch` 多架构检查失败。在仓库根目录执行以下命令，改为构建本机架构：

```sh
zsh tool/build_ios_simulator.sh example
# 回归应用或性能工程：将 example 替换为 demo
```

此脚本需克隆完整仓库后使用。该问题记录来自构建工具链，与应用内的适配配置无关。

## 提交复现信息

保留 Flutter 版本、设备与系统版本、设计尺寸、缩放策略、字体配置、操作步骤及完整错误日志。测试入口见[测试与验证](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/testing.md)。
