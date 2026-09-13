# 精简测试实验室

运行：在 example 目录执行 `flutter run`。首页仅保留指针与 UnscaledZone。

两页顶部均可切换设计宽度 320、375、768。右上角按钮清空当前页面的记录。

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
