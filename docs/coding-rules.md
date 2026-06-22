# QMemoCute Coding Rules

本文定义原生 iOS 工程的代码与资源管理规则。具体颜色、字体、间距、动画和已确认交互以 [`CODE_STYLE_GUIDE.md`](CODE_STYLE_GUIDE.md) 为准；冲突时优先遵循用户最新的明确要求，并同步更新相关规范。

## 适用范围

- 仓库：`/Users/liy/Documents/GitHub/memory-bunny-qmemo`
- 原生项目：`NativeIOS/QMemoCute.xcodeproj`
- 原生源码：`NativeIOS/QMemoCute/`
- Swift 5，最低 iOS 17.0
- SwiftUI 为主，UIKit 用于需要原生文本、菜单或手势能力的桥接

## Swift 规范

- 遵循 Swift API Design Guidelines，类型使用 `UpperCamelCase`，变量、函数和参数使用 `lowerCamelCase`。
- Bool 命名使用 `is`、`has`、`can`、`should` 等可读前缀。
- 枚举 case 使用 `lowerCamelCase`，持久化枚举的 raw value 不得随意修改。
- 默认使用 `struct` 表示值和 SwiftUI View；需要身份、共享可变状态或系统 delegate 时使用 `final class`。
- UI 状态和 `ObservableObject` 默认隔离到 `@MainActor`。
- 优先使用 `private` / `private(set)` 缩小可见范围。
- 避免强制解包、强制类型转换和无解释的 magic number。
- 小型计算属性可留在 View 内；复杂计算、数据转换和副作用应提取到明确的类型或方法。
- 注释解释约束、兼容原因和非直观行为，不复述代码表面含义。

## SwiftUI 与 UIKit

- 新页面和普通组件优先使用 SwiftUI。
- UIKit 只用于 SwiftUI 难以稳定实现的富文本、原生菜单、手势或系统行为。
- `UIViewRepresentable` / `UIViewControllerRepresentable` 的 Coordinator 只负责桥接 delegate、状态同步和生命周期。
- SwiftUI 与 UIKit 双向同步必须防止重复更新、光标跳动和递归回调。
- View 的 `body` 保持声明式；文件、通知、编码等副作用不得直接散落在布局代码中。
- 使用 `Task` 时明确主线程、取消和对象生命周期。

## 目录与职责

```text
QMemoCute/
├── App/                    # App 入口、根容器、一级导航
├── Core/                   # 共享 Model、Store、Theme
├── Features/<Feature>/     # 页面和功能私有组件
└── Resources/              # Assets.xcassets、Info.plist
```

- 页面：使用 `<Feature>View.swift` 或语义明确的页面名，负责组合和导航。
- 组件：仅被单个功能使用时放在该 Feature；跨功能复用达到实际需求后再提取到 Core 或共享目录。
- Model：纯数据类型、`Codable` 兼容和领域规则放在 Core 或所属 Feature。
- ViewModel：当前工程未普遍采用独立 ViewModel，不为形式统一而空建类型；当页面状态和异步流程明显复杂时再引入 `<Feature>ViewModel`。`TODO`：在新增首个 ViewModel 时统一依赖注入和生命周期约定。
- Service/Manager：系统通知、AlarmKit、文件或网络等副作用集中管理，View 不直接复制系统调用。
- 文件移动后必须同步 Xcode group、file reference、target membership、build phase 和相关路径设置。

## 状态与数据流

- `MemoStore` 是便签列表状态的单一来源，通过 Environment 注入页面。
- 子 View 优先接收最小必要值、`Binding` 或操作闭包。
- 不在多个页面维护互相竞争的便签副本。
- 置顶、删除、提醒等状态变化必须同步更新列表排序和持久化结果。
- Todo 的结构化 `MemoTodoItem` 与用于首页展示、搜索兼容的纯文本摘要必须保持一致。

## 资源管理

- 运行时图片必须进入 `NativeIOS/QMemoCute/Resources/Assets.xcassets`。
- Swift 中使用 Assets 的逻辑名称，例如 `Image("TabHome")`，不使用源文件路径。
- imageset 使用稳定、可读的 `UpperCamelCase` 名称；同一含义不得建立近似重复资源。
- 新增或替换资源前检查像素尺寸、透明背景、缩放模式和版权来源。
- 不直接覆盖现有资源。需要替换时保留来源说明，先展示 diff/文件清单并确认影响页面。
- 不把 `.DS_Store`、临时导出文件或桌面路径加入工程。
- AppIcon、AccentColor 和 `Contents.json` 必须保持 Asset Catalog 结构有效。

## 颜色、字体与布局

- 优先复用 `Theme` 和 `CODE_STYLE_GUIDE.md` 中已有 token，不在页面重复硬编码同一颜色或间距。
- 使用系统字体；未经明确要求不引入自定义字体包。
- 文本应支持系统字号变化，固定高度不得裁剪重要文本。
- 使用 Safe Area 和容器尺寸组织布局，不按某一台设备的绝对坐标拼页面。
- 新增 iPhone 和 iPad 支持前先确认产品范围；当前 Expo 配置声明不支持平板，原生工程适配范围 `TODO` 进一步确认。

## 错误处理与日志

- 可恢复错误应返回、抛出或转成用户可理解的状态，不使用空 `catch`。
- 系统能力失败时记录真实原因；回退路径不能被描述为原能力成功。
- 使用 `OSLog.Logger` 记录通知、AlarmKit 和重要系统交互，不在发布代码散落 `print`。
- 日志不得包含完整便签正文、个人数据、令牌或其它敏感内容。
- 用户可处理的问题使用现有弹窗或页面状态反馈，错误文案应说明下一步。

## 网络请求

当前原生 App 没有后端和网络请求层，不得为假设需求新增网络依赖。

TODO：如果未来引入网络能力，统一建立 Service 协议、`URLSession` 实现、可取消异步 API、超时、状态码校验、解码错误和测试替身；不得从 View 直接调用 `URLSession.shared`。

## 数据存储

- 当前 `MemoStore` 使用 `Codable` 编码 `[Memo]`，保存到 `UserDefaults` key `qmemo.native.memos`。
- 不得随意修改 key、日期编码策略、字段含义或 enum raw value。
- 新字段应提供兼容旧数据的默认解码策略；破坏性变更必须先设计迁移和回滚方案。
- 编码失败不能静默造成数据丢失。现有静默失败属于待改进项，不应在新代码中复制。
- 大数据、图片或长期增长数据不应继续塞入 UserDefaults。TODO：达到迁移条件时评估文件存储、SwiftData 或数据库方案。
- 删除待办或提醒时同时取消相关本地通知和 AlarmKit 闹钟。

## 通知与 AlarmKit

- 仅在用户确认未来提醒时请求通知权限。
- 保存、完成、删除或修改待办后重新同步对应提醒。
- 过期、空文本、已完成或已删除项目不得保留待触发通知。
- iOS 26+ 紧急提醒使用 AlarmKit；旧系统和失败场景按现有规则回退到普通通知。
- 只有 `AlarmManager.schedule` 返回且能查询到相同 item ID 时才能记录为 AlarmKit 成功。
- 模拟器用于注册、权限、界面和回退验证；真机用于到点触发验证。

## UI 适配与可访问性

- 所有纯图标按钮提供准确的 accessibility label；装饰图片隐藏于辅助功能树。
- 可点击区域尽量不小于 44 x 44 pt。
- 不只依赖颜色表达选中、错误、完成或提醒状态。
- 支持 VoiceOver 的合理阅读顺序，组合卡片时避免重复朗读装饰内容。
- 检查大字号、较长中文文本、空数据、键盘弹出、横向空间不足和 Reduce Motion。
- 动画不是完成操作的唯一反馈；减少动态效果时应保留状态变化。
- 重要文字与背景保持足够对比度，不因可爱风格牺牲可读性。

## 验证要求

- 每次 Swift 或工程配置修改至少执行 Debug 模拟器 build。
- 每个行为修改必须验证准确的用户路径，不能只报告 build 成功。
- 修改已有交互时回归原路径；视觉改动应截图比较。
- 持久化改动验证新建、编辑、重启恢复和旧数据兼容。
- 提醒改动验证普通通知、权限拒绝、取消、过期和 AlarmKit 回退；到点 AlarmKit 另做真机验证。
- 当前没有测试 Target。TODO：增加单元测试和 UI 测试后在此记录固定命令。
