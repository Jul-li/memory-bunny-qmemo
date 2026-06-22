# Codex Project Rules

本文件适用于仓库 `/Users/liy/Documents/GitHub/memory-bunny-qmemo` 及其全部子目录。当前主要开发对象是 `NativeIOS/QMemoCute.xcodeproj`。

## 任务开始前

每次任务开始必须：

1. 运行 `git status --short --branch`，确认分支和用户已有改动。
2. 运行 `git rev-parse --show-toplevel`，确认仓库根目录。
3. 阅读 `README.md`、`AGENTS.md`、`CONTRIBUTING.md`、`docs/coding-rules.md`。
4. 涉及 UI 或产品行为时阅读 `docs/CODE_STYLE_GUIDE.md`。
5. 涉及功能进度时阅读 `docs/DEVELOPMENT_ROADMAP.md` 及相关状态文档。
6. 阅读与任务直接相关的 Swift 文件和 Xcode 配置，不凭文件名猜测行为。

## 项目路径

- 仓库：`/Users/liy/Documents/GitHub/memory-bunny-qmemo`
- 原生目录：`/Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS`
- 原生源码：`/Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS/QMemoCute`
- Xcode 工程：`/Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS/QMemoCute.xcodeproj`

提交到文档或代码中的工程引用优先使用相对路径；绝对路径只用于本机命令和定位说明。

## 修改原则

- 保持修改范围与任务一致，优先使用现有模式和已有组件。
- 默认保留现有样式、动画、交互、持久化格式和导航行为。
- 修复局部问题时不得顺带重写正常工作的页面或组件。
- 结构调整先做行为不变的机械移动，再单独进行功能修改和验证。
- 工作区可能包含用户的未提交改动；不得回退、覆盖或清理这些改动。
- 新文件必须放入职责所属目录，并确认 Xcode file reference、group、target membership 和 build phase。
- 无法从代码或文档确认的信息标记为 `TODO`。

## 禁止事项

- 不进行未经要求的大范围重构、批量重命名或格式化。
- 不随意删除文件，不使用 `git reset --hard`、`git checkout --` 等破坏性命令。
- 不直接覆盖、压缩或替换 `Assets.xcassets` 中的资源。
- 不从桌面、下载目录等临时路径加载运行时资源。
- 不改变 `Codable` 字段、UserDefaults key 或提醒 ID 规则而不考虑数据兼容。
- 不吞掉通知、AlarmKit、编码或持久化错误并伪装为成功。
- 不新增后端、登录、网络依赖或第三方包，除非任务明确要求。
- 不把 build 成功等同于功能验证完成。
- 不声称已运行不存在的测试 Target。

## 架构约定

- `App/`：App 入口、根容器、一级 Tab 和全局页面协调。
- `Core/`：共享 Model、Store、Theme 和跨功能基础能力。
- `Features/<FeatureName>/`：功能页面及功能私有组件。
- `Resources/`：`Assets.xcassets` 和 `Info.plist`。
- 页面组合和导航留在 View；复杂状态和副作用应放入 Store、Service 或 Manager。
- `MemoStore` 是原生便签列表状态的单一来源。
- 普通便签使用 `MemoEditorView`；待办便签使用 `TodoListEditorView`。
- 富文本 UIKit 桥接保留在 `MemoRichTextView` 等对应支持文件中。
- 提醒注册、更新与取消集中在 `TodoReminderManager`。

具体 Swift、资源和可访问性规则见 `docs/coding-rules.md`；具体视觉参数见 `docs/CODE_STYLE_GUIDE.md`。

## 修改后检查

每次修改完成后必须：

1. 运行 `git diff --check`。
2. 运行 `git diff --stat` 并展示改动文件范围。
3. 展示 `git diff` 或任务相关文件的定向 diff。
4. 说明影响的页面、Model、存储、通知、资源和兼容性范围。
5. 执行构建，并在模拟器或真机验证本次修改的准确路径。
6. 回归任何被触及的既有交互。

## Build 与测试

通用模拟器构建：

```bash
cd /Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS
xcodebuild clean build \
  -project QMemoCute.xcodeproj \
  -scheme QMemoCute \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/QMemoCuteDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

查看可用模拟器：

```bash
xcrun simctl list devices available
```

当前没有 `QMemoCuteTests` 或 `QMemoCuteUITests` Target。建立测试 Target 前，不执行或记录虚假的 `xcodebuild test` 成功结果。AlarmKit 到点触发必须在真机验证。
