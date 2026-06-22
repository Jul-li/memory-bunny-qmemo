# Contributing

本文适用于 `/Users/liy/Documents/GitHub/memory-bunny-qmemo`。原生 iOS 主工程位于 `NativeIOS/QMemoCute.xcodeproj`。

## 开始前

```bash
cd /Users/liy/Documents/GitHub/memory-bunny-qmemo
git status --short --branch
git rev-parse --show-toplevel
```

阅读 `README.md`、`AGENTS.md`、`docs/coding-rules.md`、`docs/CODE_STYLE_GUIDE.md` 和任务相关源码。不要覆盖工作区中其他人的未提交改动。

## 分支命名

使用小写英文和连字符：

- `feature/<short-description>`：新功能
- `fix/<short-description>`：缺陷修复
- `refactor/<short-description>`：行为不变的重构
- `docs/<short-description>`：仅文档
- `test/<short-description>`：测试
- `chore/<short-description>`：工程或维护任务

示例：`feature/statistics-day-detail`、`fix/todo-reminder-cancel`。

当前工作分支可能按仓库协作需要使用 `ios-native`。创建、切换或合并分支前先确认用户意图，不擅自改写分支历史。

## Commit Message

采用 Conventional Commits 风格：

```text
<type>(<scope>): <summary>
```

常用 type：`feat`、`fix`、`refactor`、`docs`、`test`、`chore`。

示例：

```text
feat(statistics): add selected-day summary
fix(reminder): cancel alarm when todo is deleted
docs(ios): document simulator build workflow
```

- summary 使用祈使语气，简洁说明结果。
- 一个提交只包含一个可解释的改动主题。
- 不提交 DerivedData、`.DS_Store`、签名文件或个人 Xcode 配置。
- 不把未经验证的功能写成完成状态。

## 开发步骤

1. 确认工作区和任务边界。
2. 阅读相关实现及规范。
3. 进行最小范围修改。
4. 检查 diff 和资源变动。
5. 构建并验证准确的交互路径。
6. 回归被触及的已有行为。
7. 提交前再次检查状态和 diff。

## Build

打开 Xcode：

```bash
cd /Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS
open QMemoCute.xcodeproj
```

通用模拟器构建：

```bash
xcodebuild clean build \
  -project QMemoCute.xcodeproj \
  -scheme QMemoCute \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/QMemoCuteDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

指定模拟器验证前先运行：

```bash
xcrun simctl list devices available
```

然后将 destination 替换为当前实际设备，例如：

```bash
-destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

不要把示例设备版本当作所有机器都存在的固定前提。

## 测试与模拟器验证

当前工程没有单元测试或 UI 测试 Target，`xcodebuild test` 暂不可用。

提交前至少验证：

- App 可以 clean build、安装、启动和重启。
- 本次修改的完整用户路径正常。
- 被修改代码触及的既有交互没有回归。
- 页面无白屏、明显布局溢出或资源缺失。
- 有数据和空数据状态均符合本次改动范围。
- 持久化相关改动在 App 重启后仍正确。
- 通知相关改动覆盖授权、拒绝、取消、过期和回退路径。
- AlarmKit 到点触发在支持的真机验证，不能用模拟器结果代替。

TODO：创建 `QMemoCuteTests`、`QMemoCuteUITests` 后补充固定 test plan 和命令。

## PR / 合并前检查清单

- [ ] 改动与任务范围一致，无无关重构或格式化。
- [ ] 未删除、覆盖或重命名无关文件和资源。
- [ ] Xcode group、file reference、target membership 和 build phase 正确。
- [ ] `git diff --check` 通过。
- [ ] 已查看并展示 `git diff --stat` 和相关 `git diff`。
- [ ] Debug 模拟器 clean build 通过。
- [ ] 已记录模拟器或真机型号及系统版本。
- [ ] 已验证准确功能路径和相关回归路径。
- [ ] 数据格式变化具有兼容或迁移方案。
- [ ] 通知和 AlarmKit 结果没有被错误描述。
- [ ] 文档、路线图和实际代码状态一致；不确定项标记为 `TODO`。
- [ ] PR 描述包含影响范围、验证证据、已知限制和必要截图。

## PR 描述建议

```text
## 变更
- 说明用户可见结果和主要实现。

## 影响范围
- 页面 / Model / 存储 / 通知 / 资源 / 兼容性。

## 验证
- 构建命令与结果。
- 模拟器或真机信息。
- 已验证的准确路径与回归路径。

## 限制或 TODO
- 未验证或后续工作。
```
