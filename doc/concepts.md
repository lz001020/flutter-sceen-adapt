# 核心概念

全局适配改变 Flutter 的逻辑坐标和 DPR，屏幕物理尺寸保持不变。
例如原始逻辑宽 400、设计宽 200，width 策略下 scale=2；100 个设计单位占 200 个原始逻辑单位。

渲染、MediaQuery 和触点必须使用同一快照。只缩放绘制会造成布局或命中不一致，因此库在 binding 层完成全局映射。

Controller 是配置及运行时状态来源，Metrics 是不可变计算结果。
`enabled` 独立于 scale：scale=1 仍可能处于开启状态，所以启停必须按 enabled 判断。

公式、字体和公共契约见 [使用指南](usage.md)，实现边界见 [架构](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/architecture.md)。
