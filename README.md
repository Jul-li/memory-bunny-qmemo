# 记忆兔 QMemo

记忆兔是一款本地优先的 Q 版卡通备忘录 App。当前产品主线是原生 SwiftUI iOS App；仓库根目录仍保留 React Native / Expo 参考实现，用于历史对照和视觉、交互参考。

## 本地路径

- 仓库根目录：`/Users/liy/Documents/GitHub/memory-bunny-qmemo`
- 原生 iOS 目录：`/Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS`
- 原生业务代码：`/Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS/QMemoCute`
- Xcode 工程：`/Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS/QMemoCute.xcodeproj`
- 原生资源目录：`/Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS/QMemoCute/Resources/Assets.xcassets`

本地绝对路径只用于当前开发环境定位。代码和文档中的工程引用应使用仓库相对路径。

## 技术栈

### 原生 iOS 主线

- Swift 5
- SwiftUI 为主要页面和布局技术
- UIKit 用于富文本编辑、原生菜单等桥接能力
- `ObservableObject` / `EnvironmentObject` 管理本地便签状态
- `Codable` + `UserDefaults` 保存便签数据
- UserNotifications 提供普通本地通知
- iOS 26+ 使用 AlarmKit 提供紧急提醒，并为旧系统保留通知回退
- 最低部署版本：iOS 17.0
- Bundle ID：`com.memorybunny.qmemo`

### 参考实现

- Expo 54、React Native 0.81、React 19
- Expo Router、TypeScript、Expo SQLite
- Node.js 依赖以 `package-lock.json` 为准

## 目录结构

```text
memory-bunny-qmemo/
├── NativeIOS/
│   ├── QMemoCute.xcodeproj/       # 当前原生 Xcode 工程
│   └── QMemoCute/
│       ├── App/                    # App 入口、根页面和一级导航
│       ├── Core/                   # Model、MemoStore、Theme
│       ├── Features/
│       │   ├── Home/               # 首页、搜索、筛选和便签卡片
│       │   ├── MemoEditor/         # 普通便签及富文本、贴纸编辑
│       │   ├── Todo/               # 待办编辑和提醒调度
│       │   ├── Statistics/         # 日历与统计页面
│       │   └── Settings/           # 设置页面
│       └── Resources/              # Assets.xcassets 和 Info.plist
├── app/                            # Expo Router 参考入口
├── docs/                           # 规范、路线图和上架资料
├── package.json                    # Expo 参考实现依赖与脚本
└── README.md
```

## 安装与运行

### 原生 iOS

原生工程当前没有 CocoaPods 或 Swift Package 依赖，不需要执行额外的依赖安装。

1. 安装 Xcode，并确保命令行工具指向所用版本：

   ```bash
   xcode-select -p
   xcodebuild -version
   ```

2. 打开工程：

   ```bash
   cd /Users/liy/Documents/GitHub/memory-bunny-qmemo/NativeIOS
   open QMemoCute.xcodeproj
   ```

3. 在 Xcode 中选择 `QMemoCute` scheme 和可用 iPhone 模拟器，按 `Command-R` 运行。

命令行构建：

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

2026-06-22 已使用 Xcode 26.5 和 iPhone 17 / iOS 26.5 模拟器完成 clean build、安装、启动及统计页交互验证。

### Expo 参考实现

```bash
cd /Users/liy/Documents/GitHub/memory-bunny-qmemo
npm ci
npm run typecheck
npm start
```

原生功能开发不应同时修改 Expo 参考实现，除非任务明确要求同步。

## 测试

当前 Xcode 工程只有 `QMemoCute` App Target，尚未配置单元测试或 UI 测试 Target。因此目前不能把 `xcodebuild test` 作为有效验证。

每次原生改动至少需要：

1. 执行 `xcodebuild clean build`。
2. 在目标模拟器或真机启动 App。
3. 验证本次修改对应的完整交互路径。
4. 回归本次修改触及的既有交互。
5. AlarmKit 到点触发必须使用支持该能力的真机验证。

TODO：创建 `QMemoCuteTests` 和 `QMemoCuteUITests` Target，并补充稳定的 `xcodebuild test` 命令。

## 当前进度

### 已完成或已有实现

- 首页搜索、分类筛选、空状态、便签卡片列表、置顶重排和删除确认。
- 普通便签创建、编辑、删除及本地保存。
- 标题、正文、段落样式和多种行内富文本格式。
- 贴纸插入、拖动、缩放、旋转、删除、保存和恢复。
- 独立待办编辑器、完成状态、日期时间提醒和保存恢复。
- 普通本地通知，以及 iOS 26+ AlarmKit 紧急提醒和失败回退。
- 首页最近待办提醒倒计时。
- 日历统计页的月份切换、日期标记、汇总指标、周趋势和分类统计。
- 设置一级页面的基础结构。
- 原生代码已按 `App/Core/Features/Resources` 重新组织。

### 待办事项

- 增加日期详情页。
- 完善待办优先级、重复任务等进阶能力。
- 持续进行 AlarmKit 真机到点触发验证。
- 完善设置页、清空确认、数据迁移和备份。
- 增加单元测试与 UI 测试 Target。
- 规划内购、恢复购买及 App Store 上架材料。

详细顺序见 [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md)。无法从当前代码确认的计划应保留为 `TODO`，不能写成已完成功能。

## 常见问题与调试

### Xcode 找不到文件或资源

确认文件位于 `NativeIOS/QMemoCute/` 的当前分层目录中，并同时检查 `project.pbxproj` 的 group、file reference、target membership 和 build phase。资源只能从 `Resources/Assets.xcassets` 使用，不能依赖桌面临时路径。

### App 首次启动出现四条示例便签

这是 `MemoStore.seedMemos` 的当前行为。便签以 key `qmemo.native.memos` 编码后写入 `UserDefaults`。

### 修改后仍显示旧数据或旧界面

先确认运行的是 `NativeIOS/QMemoCute.xcodeproj` 的 `QMemoCute` scheme。必要时清理 DerivedData，并重新安装 App。删除模拟器 App 会同时清除其本地 `UserDefaults` 数据。

### 提醒没有触发

- 检查通知权限和提醒时间是否在未来。
- 模拟器只用于界面、权限、注册和通知回退路径。
- AlarmKit 紧急提醒必须在真机验证到点触发。
- AlarmKit 成功状态应通过本 App 的 `AlarmManager` 查询，不应以系统时钟 App 是否出现条目为依据。

### 查看运行日志

在 Xcode Debug Console 中查看日志，或针对已启动模拟器执行：

```bash
xcrun simctl spawn booted log stream \
  --level debug \
  --predicate 'process == "QMemoCute"'
```

协作规则见 [`AGENTS.md`](AGENTS.md)，编码规则见 [`docs/coding-rules.md`](docs/coding-rules.md)，贡献流程见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。
