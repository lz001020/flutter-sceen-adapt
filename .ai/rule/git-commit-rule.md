# Git 提交规范

本项目采用 Conventional Commits 风格。本文件是 v2 分支唯一的提交标题规范；提交信息必须直接说明变更性质和影响范围，不能把所有提交都写成 `feat`。

## 1. 基本格式

```text
<type>(<scope>): <description>
```

示例：

```text
feat(core): add immutable adaptation result
fix(binding): preserve the original pointer callback
test(metrics): cover width strategy calculation
docs(api): document runtime profile switching
```

要求：

- `type` 和 `scope` 使用英文小写。
- `description` 使用中文。
- 一次提交只做一类逻辑变更。
- 不把格式化、重构、修 bug 和新功能混在一个提交中。
- 如果变更跨越多个模块，优先拆成多个提交；确实无法拆分时使用 `scope: all`。


## 2. Type 选择

### `feat`

新增用户可使用的功能或公共 API。

```text
feat(strategy): add fixed scale strategy
feat(scope): support runtime profile switching
feat(zones): add physical pixel zone
```

### `fix`

修复错误行为、崩溃、兼容性或回归问题。

```text
fix(binding): correct pointer event scale
fix(web): remove dart io platform detection
fix(metrics): handle empty view safely
```

### `refactor`

不改变预期功能的代码结构调整。

```text
refactor(core): isolate resolver from flutter binding
refactor(binding): split view configuration adapter
refactor(zones): remove singleton access from unscaled zone
```

### `test`

新增、修改或整理测试，但不改变生产代码行为。

```text
test(metrics): cover inset and text scale resolution
test(binding): verify pointer callback chaining
test(zones): cover nested unscaled zones
```

### `docs`

只修改文档、注释或 API 说明。

```text
docs(api): define v2 public api
docs(architecture): archive v2 roadmap
docs(repo): add git commit rules
```

### `build`

修改构建系统、依赖、Dart / Flutter SDK 约束或发布配置。

```text
build(pubspec): update sdk constraints
build(release): configure pub publish checks
```

### `ci`

修改持续集成、自动化检查或发布流水线。

```text
ci(github): test supported flutter platforms
ci(release): add pub publish dry run
```

### `perf`

以行为不变为前提的性能优化。

```text
perf(metrics): cache resolver results during resize
perf(binding): reduce metrics recalculation
```

### `style`

只改变格式、排版或 lint 风格，不改变代码逻辑。

```text
style(all): format dart sources
```

### `chore`

其他不影响包功能的维护工作，例如工具文件或仓库元数据整理。

```text
chore(repo): update editor settings
chore(example): refresh demo assets
```

### `revert`

撤销之前的提交。描述中应注明被撤销的提交。

```text
revert(core): revert immutable result change
```

## 3. Scope 约定

推荐使用以下 scope：

| scope | 范围 |
| --- | --- |
| `core` | 核心模型、公共基础抽象 |
| `config` | profile、字体和平台配置 |
| `strategy` | 缩放策略 |
| `metrics` | environment、resolver、result |
| `binding` | Flutter binding、ViewConfiguration、pointer |
| `scope` | InheritedWidget、运行时状态和 profile 作用域 |
| `zones` | UnscaledZone、PlatformView、PhysicalPixelZone |
| `web` | Web 特有实现或兼容性 |
| `example` | 示例工程 |
| `api` | 公共导出、命名和 API 文档 |
| `tests` | 跨模块测试基础设施 |
| `pubspec` | 包元数据、依赖和 SDK 约束 |
| `release` | 发布流程和版本准备 |
| `repo` | 仓库级规则和维护文件 |
| `all` | 确实无法拆分的跨模块变更 |

## 4. Breaking change

如果提交引入破坏性变更，在描述末尾加 `!`：

```text
feat(api)!: replace singleton initialization with profile binding
```

也可以在提交正文中注明：

```text
BREAKING CHANGE: remove ScreenSizeUtils from the public API
```

v2 重构允许破坏性变更，但必须同步更新 API 文档、README、example 和 CHANGELOG。

## 5. 提交前检查

提交前至少执行：

```bash
dart format .
dart analyze
flutter test
```

提交信息检查：

- type 是否准确表达变更性质
- scope 是否对应实际模块
- description 是否简洁、使用祈使句
- 是否混入了不相关改动
- 破坏性 API 是否使用 `!` 并更新迁移说明

## 6. 本项目示例

```text
docs(repo): add git commit rules
feat(core): implement screen adaptation profile
feat(strategy): add width and height strategies
refactor(metrics): make resolver independent of global state
feat(binding): connect adapted result to flutter view configuration
feat(scope): expose adaptation state to widget subtrees
fix(binding): chain existing pointer data callback
test(metrics): cover orientation and inset behavior
build(pubspec): prepare package metadata for pub dev
ci(release): run pub publish dry run
```
