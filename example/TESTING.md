# 精简测试实验室

运行：在 example 目录执行 `flutter run`。首页包含指针、UnscaledZone、键盘与安全区、字体与系统缩放、窗口与横竖屏。

各页顶部均可切换设计宽度 320、375、768。右上角按钮重置当前页面。

## 手动验证

1. 指针页依次点击 A、B、C，确认只有对应计数增加；在蓝色区域横向拖动。
2. UnscaledZone 页比较 normal、context、full。矩形逻辑尺寸为 80×48，红线表示下一个兄弟组件的起点。
3. 每组依次点击中心和边缘，再点击灰色测试区内、蓝色矩形右侧和下侧的外部，确认计数与视觉触点吻合。
4. 切换每个设计尺寸重复操作，分别选择“一致”或“存在偏移”。未选择时保持“待验证”。

PASS 仅代表几何数值符合预期，不代表点击验证完成。两种反适配模式的绘制比例均为 1/scale；full 同时改变布局占位。context 保留原占位，超出占位的绘制区域可能无法命中。

交互组件推荐显式使用 `UnscaledZoneMode.full`。2026-09-13 的模拟器内外边界验证结果、context 已复现的限制和未覆盖范围见 [UnscaledZone 验证记录](../docs/unscaled-zone-validation.md)。

坐标表示测量当时的位置；滚动后可点击“重新测量”获取新坐标。

## 日志与自动化

操作前可清空旧日志，操作后读取（不要操作后再清空）：

```sh
adb logcat -c
# 在模拟器中操作
adb logcat -d -s flutter | rg 'demo:profile|demo:pointer|demo:zone'
```

日志仅在切换配置、测量、点击、拖动结束/取消和人工确认时输出。

灰色测试区会额外输出配对的 `probe=N down/up` 日志：`inside` 表示触点是否位于蓝色矩形内部，`delta` 表示点击计数变化。单次外部点击应为 `inside=false delta=0`；拖动或多指操作标记为 `drag-or-multi`，不当作单击验收。灰色区域以外的文字和操作按钮不属于外部点击测试区。

仓库根目录运行 `flutter test`，覆盖缩放 0.5、1、2，布局占位、原始物理尺寸、中心/边缘/区域外点击，以及 full 嵌套和运行时切换。

example 目录运行 `flutter test`，验证页面导航、独立靶点计数、拖动、重置和几何结果。Widget test 不能替代真实设备的视觉触点确认。

## 键盘与安全区

1. 打开“键盘与安全区”，确认底部输入框、绿线未进入系统手势区。
2. 点击输入框，输入文字；确认输入框位于键盘上方，日志显示 `keyboard=打开 visible=true insetMatches=true`。
3. 收起键盘，确认输入框回到底部；切换 320、375、768，重复操作。也尝试键盘打开时切换设计尺寸。
4. 旋转设备后重复打开/收起；通过“正常”或“有遮挡”记录人工结论。

用 `adb logcat -d -s flutter | rg 'demo:keyboard|demo:profile'` 读取记录。日志包含原始/适配尺寸、DPR、Insets、padding、viewPadding、输入框边界和可用底边，不记录输入的文字。

`visible` 检查输入框是否位于安全区与键盘边界内；`insetMatches` 检查适配后的底部 Insets 换算为物理像素后是否与 FlutterView 一致。浮动键盘等不报告底部 Insets 的场景仍需人工确认。

自动测试通过注入窗口 Insets 验证键盘开关、键盘高度变化、布局恢复和横屏安全区；不等于真实软键盘或自定义 binding 的设备验证通过。

已知未解决项（2026-09-13 模拟器）：横屏 320/375 下软键盘完全打开时输入框部分超出可用底边；Insets 映射通过，但可见性检查失败。此项暂缓处理，不标记为验收通过。

## 字体与系统缩放

在 example 目录分别启动以下配置，切换配置需停止应用后重新运行：

```sh
flutter run --dart-define=SUPPORT_SYSTEM_TEXT_SCALE=false
flutter run --dart-define=SUPPORT_SYSTEM_TEXT_SCALE=true
```

1. 打开“字体与系统缩放”，查看 normal/full 的 16、28 字号样本。
2. 到系统设置把字体由默认调大，返回页面；查看字号映射、实际尺寸、是否超过两行。测试结束恢复系统设置。
3. 在 320/375/768 下重复；切换设计尺寸会保留当前字体策略。
4. 在样本下点击“正常”或“裁切或重叠”，记录人工观察。

normal 在配置 false 时应忽略系统字体大小，true 时应跟随。full 恢复原始 MediaQuery，两种启动配置下均应跟随系统字体。

日志：`adb logcat -d -s flutter | rg 'demo:text|demo:profile'`。mapping 只判断字号映射；ellipsis 表示两行容器不足，不能把字号 PASS 理解成没有截断。Android 非线性字体缩放下，若 16/28 字号出现映射差异，应保留 FAIL 证据再分析，不按统一比例自动判通过。

## 窗口与横竖屏

打开“窗口与横竖屏”，旋转设备到横屏再恢复竖屏，并在每次稳定后切换 320、375、768。页面只在物理尺寸、DPR、scale 有效时显示 PASS；窗口创建/旋转的零尺寸过渡会被忽略。日志：`adb logcat -d -s flutter | rg 'demo:window|demo:profile'`。
