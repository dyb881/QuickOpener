# QuickOpener

macOS 菜单栏项目启动器。按 `⌥Z` 在光标位置弹出窗口，输入几个字就能打开常用项目文件夹——用哪个应用打开也可以指定。

SwiftUI + SwiftData，沙盒、无网络依赖。

## 功能

**快速打开**

- 全局快捷键 `⌥Z`（可改）：窗口不可见时弹出、可见且光标在窗口内时收起、可见但光标在外面时挪到光标处
- 窗口以光标为中心弹出，四边由 `visibleFrame` 钳制，不越出屏幕
- `Esc` 隐藏窗口（保留状态，下次直接复用）

**项目管理**

- 拖入或选择文件/文件夹添加，重复路径自动跳过
- 按「使用频率 × 时间衰减」排序：`weight` 以 7 天为半衰期衰减，最近常用的排在前面
- 实时过滤名称与路径（忽略大小写）
- 右键 10 项操作：打开、在 Finder 中显示、在终端 / VS Code 中打开、复制路径 / 名称 / 文件、设为默认打开方式、重新计算体量、从列表移除

**项目巡检**

- 异步统计目录大小、文件数、Git 分支，未就绪时显示占位条
- 沙盒下通过安全书签（`startAccessingSecurityScopedResource`）访问用户目录，书签路径优先于模型里的路径
- 删除项目时清理巡检缓存

**应用与打开方式**

- 内置 Finder 不可删除，可添加任意 `.app`
- 当前打开方式显示在横条右侧，单击行或回车用默认应用打开

**外观**（`外观` 页签）

| 项 | 可选值 |
| --- | --- |
| 外观模式 | 跟随系统 / 亮色 / 暗色 |
| 主题色 | 系统、薄荷、蓝、紫、橙、粉、黑蓝、自定义（系统取色器） |
| 背景材质 | 纯色 / 磨砂 / 玻璃 |
| 透明度 | 0.35 – 1.0 |

材质与透明度只作用于主窗口；设置窗口是不透明窗口，标题栏由 AppKit 绘制。

**数据**

- 导出 / 导入 JSON（`version`、`exportedAt`、`projects`、`applications`）
- 重置缓存（二次确认）

## 快捷键

| 按键 | 行为 |
| --- | --- |
| `⌥Z` | 显示 / 挪到光标 / 隐藏 |
| `Esc` | 隐藏窗口 |
| `↑` `↓` | 切换选中项 |
| `↩` | 打开选中项 |
| `⌘1` – `⌘9` | 直接打开第 N 项 |

搜索框自动获得焦点，可以纯键盘完成「打字过滤 → 选择 → 打开」。有模态面板（`NSOpenPanel` / `NSAlert`）时键盘监听自动让行。

## 界面结构

**主窗口 780 × 514**：标题条 30 / 输入行 56 / 当前项横条 124 / 五列列表 266 / 底栏 38。列表行高 38，一屏 7 行。滚动条自绘（3.5pt 主题色胶囊，隐藏系统滚动条）。

**设置窗口 760 × 300**：左侧 172pt 侧边栏，右侧内容区一次显示一页。

| 页签 | 内容 |
| --- | --- |
| 通用 | 登录时自动启动 |
| 外观 | 外观模式、主题色、背景材质、透明度 |
| 语言 | 界面语言 + 重启生效 |
| 快捷键 | 录制 / 恢复默认 |
| 数据 | 导出、导入、重置缓存 |
| 关于 | 版本信息 |

## 实现映射

| 文件 | 职责 |
| --- | --- |
| `QuickOpenerApp.swift` | 应用入口、`ModelContainer`、主窗口创建与定位、`⌥Z` 三态切换 |
| `AppDelegate+StatusItem.swift` | 菜单栏图标与菜单、设置窗口创建 |
| `AppDelegate+Keyboard.swift` | 窗口内键盘监听、快捷键变化观察 |
| `ContentView.swift` | 主界面（标题条 / 输入行 / 当前项横条 / 五列列表 / 底栏） |
| `SettingsView.swift` | 设置界面（侧边栏 + 六个页签） |
| `DesignSystem.swift` | 色板 `DS`、等宽字体、毛玻璃、`WindowDragArea`、`SlimScrollView` |
| `AccentTheme.swift` | `AccentTheme` / `AppearanceMode` / `WindowBackdrop` / `ThemeManager` |
| `ProjectInspector.swift` | 目录大小与文件数统计、Git 分支读取、安全书签访问 |
| `DataManager/DataManager.swift` | 增删项目与应用、衰减排序、选中索引、导入导出、缓存重置 |
| `DataManager/ProjectModel.swift` | 项目模型（`weight`、`lastOpenedAt`、`bookmarkData`、`open()`） |
| `DataManager/ApplicationModel.swift` | 应用模型（默认应用路径） |
| `DataManager/FileCommonData.swift` | 通用文件属性（`url` / `name` / `icon` / `exists`） |
| `QuickOpenerTests/DataManagerTests.swift` | 11 个单元测试 |

## 数据与持久化

- SwiftData 存储 `ProjectModel` 与 `ApplicationModel`
- `UserDefaults` 存：`accentTheme`、`appearanceMode`、`windowBackdrop`、`windowOpacity`、`customAccentHex`、`currentApplicationPath`、`AppleLanguages`
- 项目路径同时存安全书签，沙盒重启后仍可访问

## 本地化

8 种语言：`en`、`zh-Hans`、`zh-Hant`、`ja`、`ko`、`de`、`fr`、`es`，各 87 条 key，通过 `LocalizedStringKey` + `Localizable.strings` 提供。切换语言写入 `AppleLanguages`，需重启生效。

## 构建与测试

```bash
cd "QuickOpener"

# 编译（跳过签名，本地验证用）
xcodebuild -project QuickOpener.xcodeproj -scheme QuickOpener -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# 单元测试（必须允许签名：无签名的 xctest 无法加载）
xcodebuild test -project QuickOpener.xcodeproj -scheme QuickOpener \
  -configuration Debug -destination 'platform=macOS'
```

若 `xcodebuild test` 报 `code object is not signed at all`，说明增量构建复用了之前跳过签名的产物，先 `xcodebuild clean` 再跑。

测试覆盖：默认应用播种、权重递增、重复路径去重、时间衰减排序、删除应用后的引用回退、Finder 保护、JSON 导入导出、选中索引越界、清空缓存。全部使用内存 `ModelConfiguration(isStoredInMemoryOnly: true)`，不触碰真实数据。

## 分发

**自签名 DMG，不做 notarization**（无付费 Apple Developer Program 会员）。

```bash
xcodebuild -project QuickOpener.xcodeproj -scheme QuickOpener -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/qo-release build
```

接收方首次打开需要**右键 → 打开**，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/QuickOpener.app
```

签名身份为 `Apple Development`（Team `WK7Q9Q7BXC`），`spctl` 校验会返回 `rejected`，属预期行为。

## 已知限制

- **无 notarization**：接收方必须主动绕过 Gatekeeper（见上）
- **设置窗口无毛玻璃**：系统标题栏只在窗口不透明时才有稳定背景色，因此材质与透明度只作用于主窗口
- **巡检上限**：单次遍历最多 20000 个条目，超大目录会截断
- **iCloud 目录**：遍历 `~/Documents`、`Desktop` 等可能触发按需下载
- **语言切换需重启**：`AppleLanguages` 变更由系统在下次启动时读取

## 开发说明

- Schema 在 `QuickOpenerApp.swift` 的 `sharedModelContainer` 中声明
- `DataManager` 标了 `@MainActor`，构造时接收 `modelContext`
- 设置窗口不能开 `sizingOptions = .preferredContentSize`：会与 SwiftUI 布局形成约束死循环（`more Update Constraints in Window passes than there are views`）
- 主窗口的拖动靠 `WindowDragArea` 里的真实 `NSView` + `performDrag`，`isMovableByWindowBackground` 对铺满内容无效
