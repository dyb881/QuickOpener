# QuickOpener

QuickOpener 是一个 macOS 菜单栏应用，用于快速打开项目或文件并以指定应用程序打开，支持全局快捷键、项目排序与多语言。下面是功能说明、实现位置、构建与运行方法、常见问题与开发说明。

## 主要功能

- 全局快捷键打开/隐藏项目选择窗口（默认 Option + Z）
- 在菜单栏显示应用图标并提供菜单：显示窗口、偏好设置、重置缓存、退出
- 浮动的项目选择窗口（鼠标附近打开），显示项目列表、过滤和快速打开
- 按打开频率（weight）对项目排序，打开项目时自动增加权重
- 支持为每个项目选择用于打开的应用（可添加/删除 .app）
- 批量添加项目或单个添加项目（通过文件/文件夹选择面板）
- 设置页面：语言选择、快捷键录制/重置、关于文字与重启生效
- 本地化支持（内置多语言资源）
- 持久化：使用 SwiftData（ModelContainer）存储 ApplicationModel 与 ProjectModel

## 实现映射（快速定位代码）

- 应用入口 / 菜单栏 / 窗口管理：`QuickOpenerApp.swift`（包含 `AppDelegate`）
- 主界面（项目列表、过滤、打开、上下文菜单）：`ContentView.swift`
- 设置界面（语言、快捷键）：`SettingsView.swift`
- 数据管理（加载/保存/增删项目与应用、缓存重置）：`DataManager/DataManager.swift`
- 模型：
  - `DataManager/ApplicationModel.swift`（ApplicationModel）
  - `DataManager/ProjectModel.swift`（ProjectModel）
  - `DataManager/FileCommonData.swift`（通用文件属性扩展）
- 本地化：各 `*.lproj/Localizable.strings` 文件（已包含 `en`, `de`, `es`, `fr`, `ja`, `ko`, `zh-Hans`, `zh-Hant` 等）

## 快捷键与交互

- 打开/切换项目窗口：Option + Z（可在设置中修改）
- 关闭窗口：Esc（隐藏窗口并保留状态，下次按快捷键直接复用）
- 在项目窗口：点击行打开、垃圾桶图标删除、左侧应用图标弹出可选应用菜单
- 添加项目：窗口顶部“+”菜单中的「添加项目…」，或直接点菜单项批量添加
- 添加/删除/选择应用：`+` 菜单中的「添加应用」与「删除应用」（内置 Finder 不可删）

## 构建与运行

推荐使用 Xcode 打开并运行（常见且简单）：

```bash
# 在项目目录下（包含 QuickOpener.xcodeproj），用 Finder 或 Xcode 打开
open QuickOpener.xcodeproj
# 或者直接打开工程所在目录以 Xcode 打开
open -a Xcode QuickOpener.xcodeproj
```

如果需要在命令行构建：

```bash
# 在仓库根目录执行（macOS / zsh）
# 指定 scheme（示例名为 QuickOpener），如项目中不同请替换 scheme 名称
xcodebuild -project QuickOpener.xcodeproj -scheme QuickOpener -configuration Debug -sdk macosx build
```

构建后可以通过 Finder 或 `open` 命令启动生成的应用：

```bash
# 假设生成在 Xcode 默认的 build 目录
open ~/Library/Developer/Xcode/DerivedData/QuickOpener-*/Build/Products/Debug/QuickOpener.app
```

注意：如果在沙盒环境或使用 App Sandbox 发布，运行时文件访问行为（打开文件/添加应用）可能受限，需要使用安全书签或额外签名/权限配置。

## 数据与持久化

- 使用 SwiftData 的 `ModelContainer` 存储 `ApplicationModel` 与 `ProjectModel`。
- 当前选择的应用路径保存在 `UserDefaults` 的 `currentApplicationPath`。
- 清空缓存会删除所有持久化模型并重置 `UserDefaults`（在应用菜单中有“Reset Cache”项）。

## 本地化

- 文案通过 `LocalizedStringKey` + `Localizable.strings` 支持多语言。
- 设置页面允许选择语言，变更会写入 `AppleLanguages`（需要重启应用生效）。

## 常见问题 & 排查

- 无法打开文件或添加项目：请确认文件存在且应用有权限访问目标路径（若使用 App Sandbox，需处理安全书签）。
- 快捷键不生效：检查系统是否允许应用使用辅助功能/快捷键冲突，或在设置中修改快捷键。KeyboardShortcuts 插件负责录制与持久化快捷键。
- 窗口没有在鼠标附近弹出：主窗口创建逻辑使用鼠标位置计算窗口 origin，某些多显示器或 Dock/菜单布局差异可能导致位置偏移。
- 重置缓存后数据丢失：重置为不可逆操作，应用会先弹出确认弹窗，请谨慎操作。可在菜单栏中找到“Reset Cache”。

## 开发说明（快速上手）

- 模型 Schema 在 `QuickOpenerApp.swift` 中通过 `Schema([ApplicationModel.self, ProjectModel.self])` 创建。
- `DataManager` 使用 `@MainActor`，其构造函数接收 `modelContext`（在 `QuickOpenerApp.sharedModelContainer.mainContext` 创建 DataManager 实例）。
- 若要在内存中运行单元测试，可创建 `ModelContainer` 的内存配置（参考 `QuickOpenerApp.sharedModelContainer` 的构造方式并设置 `isStoredInMemoryOnly: true`）。

## 建议改进（可选）

- 为危险操作（如清空缓存）添加确认弹窗或撤销支持。
- 将关键持久化操作的错误反馈给用户（目前多数为控制台打印）。
- 补充单元/集成测试，特别是 `DataManager` 的增删查流程。
- 考虑导出/导入项目列表功能以便迁移或备份。

## 贡献

欢迎提交 issue 或 PR。在发起变更前，请确保编码风格与现有代码一致，并在可能的情况下添加对应的测试或运行验证步骤。

## 许可证

项目中未包含显式 LICENSE 文件；如需发布或共享，请添加合适的许可证并在仓库根目录放置 `LICENSE` 文件。

---

如果你希望我把 README 放到仓库其他位置（例如项目根而不是 `QuickOpener/QuickOpener` 目录），或者希望我在 README 中增加具体的截图、示例 GIF、或 CI/打包说明，我可以继续修改并提交补丁。
