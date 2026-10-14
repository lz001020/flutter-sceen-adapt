# 排错

1. 初始化冲突：在其他 binding 创建前初始化适配。需要自定义 binding 时使用 mixin，并放在组合列表最后。
2. 找不到 Controller：确保组件位于 binding 自动挂载的根节点下；测试可使用库内部测试工具，但业务不要导入 src。
3. 点击位置不一致：检查插件是否在初始化后覆盖 onPointerDataPacket，运行 binding_callback_* 测试。
4. 字体变化不符合预期：检查 scaleText 和 supportSystemTextScale，两者分别控制设计缩放和系统字号。
5. 键盘遮挡：同时记录原始/适配 viewInsets、当前 DPR 和设计尺寸，并用 example 键盘页面复现。
6. 关闭后旋转又恢复适配：当前 setEnabled(false) 会保持关闭，检查业务是否又调用 configure 或 setDesignSize。
7. 旧导入或扩展找不到：按 [迁移说明](migration-0.2.md) 更新，归档代码不属于当前发布 API。

复现时保留 Flutter 版本、设备/系统版本、设计尺寸、策略、字体配置及操作步骤。
