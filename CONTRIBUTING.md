# 参与贡献

当前范围为 Android/iOS 单窗口全局设计坐标适配。局部反适配、PlatformView 补偿等扩展已归档；请先通过 Issue 讨论范围变化，避免提交无人维护的大幅扩展。

## 报告问题

先查阅 [已知限制](doc/known-issues.md)与 [排错指南](doc/troubleshooting.md)。通过仓库 Issues 提供：

- 最小可运行复现、预期行为和实际行为。
- Flutter/Dart 版本、包版本或提交、设备型号、系统版本、运行模式。
- 设计尺寸、适配策略、字体设置、屏幕方向以及相关插件的 binding 初始化顺序。
- 精确操作步骤和相关日志；移除个人信息、令牌及无关设备数据。

性能问题还需给出相同工作量下的逐轮结果、方向/分辨率/密度和采样方法。模拟器帧耗时不能作为真机性能结论。

## 修改与检查

从当前代码创建分支，围绕一个具体问题修改。修复行为缺陷时添加能复现该缺陷的测试；仅修改文档时检查链接、命令和 API 是否一致即可，不要求重复设备回归。

GitHub CI 在 push 和 Pull Request 时使用 Flutter 3.22.3、3.35.7，分别检查核心库、example 和 benchmark 的分析与测试。格式检查和 pub dry-run 统一使用 Flutter 3.35.7（Dart 3.9.2）；本地格式化与完整发布预检也使用该版本。

```sh
flutter pub get
flutter analyze
flutter test
(cd example && flutter pub get && flutter analyze && flutter test)
(cd benchmark && flutter pub get && flutter analyze && flutter test)
dart format --output=none --set-exit-if-changed lib test example/lib example/test benchmark/lib benchmark/test
git diff --check
flutter pub publish --dry-run
```

涉及 binding 初始化、指针、键盘或设备指标时，按 [核心测试规范](doc/testing.md)与 [移动端回归](example/TESTING.md)选择相关设备检查。没有设备时如实注明未验证范围，不伪称通过。发布预检为 `zsh tool/check_release.sh`，只执行 dry-run，不上传。

## 提交 Pull Request

说明具体问题、修改后行为、验证命令与结果，以及剩余限制。公共行为改变需要同步 README/使用指南与 CHANGELOG。保留失败证据；不要将测试日志、APK、个人资料或本机路径配置提交到仓库。

当前设备证据见 [最终复核](docs/performance-final-20261015.md)。提交贡献即表示你有权按本项目 [MIT 许可证](LICENSE)提供这些内容。
