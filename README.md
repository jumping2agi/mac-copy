# MenuBarTool

一个 macOS 顶部状态栏常驻工具（原生 Swift / AppKit 开发）。

## 功能

- 点击状态栏图标，弹出下拉菜单
  - 预置的快捷文本：点击即复制到剪贴板
  - **剪切板**（悬停展开二级菜单）：展示历史复制内容，点击可重新复制；底部可一键清空
  - 菜单最下方常驻 **设置…** 与 **退出** 按钮
- 点击 **设置…** 弹出窗口，可对预置快捷文本进行增、删、改
  - 两列表格：标题 / 内容，均可在行内直接编辑
  - `保存` 提交、`取消` 放弃（⌘↩ 保存，Esc 取消）
- 无 Dock 图标、无主菜单栏，仅作为菜单栏后台代理运行（`LSUIElement = true`）
- 预置文本与剪切板历史均持久化在 `UserDefaults`，重启后保留

## 目录结构

```
.
├── Package.swift                       # SwiftPM 包定义
├── Resources/
│   └── Info.plist                      # App bundle 配置（LSUIElement 等）
├── Scripts/
│   └── build.sh                        # 编译并打包成 .app
└── Sources/MenuBarTool/
    ├── main.swift                      # 入口，设置 .accessory 激活策略
    ├── AppDelegate.swift               # 启动状态栏 + 剪切板轮询
    ├── StatusBarController.swift       # NSStatusItem 与下拉菜单/二级菜单
    ├── PresetTextManager.swift         # 预置快捷文本的加载与持久化
    ├── ClipboardHistoryManager.swift   # 轮询 NSPasteboard，维护历史
    ├── SettingsWindowController.swift  # 设置弹窗（可编辑表格）
    └── AppConstants.swift              # 常量与 PresetText 模型
```

## 环境要求

- macOS 11.0 及以上
- Xcode Command Line Tools（提供 `swift` / `swiftc`）

## 构建与运行

```bash
# 1) 编译并打包成 .app（默认 release）
./Scripts/build.sh

# 产物：build/MenuBarTool.app
open build/MenuBarTool.app

# 2) 调试构建
./Scripts/build.sh debug

# 3) 编译并直接启动
./Scripts/build.sh run
```

也可以直接用 SwiftPM 跑（不打包，无 Info.plist，靠代码里的 `.accessory` 策略也能隐藏 Dock 图标）：

```bash
swift run
```

> 说明：本仓库在非 macOS 环境下无法编译（依赖 AppKit），构建请在 Mac 上进行。

## 设计要点

- **菜单栏常驻**：`NSStatusBar.system.statusItem(...)` 创建状态项，使用 SF Symbol `doc.on.clipboard` 作为图标。
- **二级菜单**：通过给 `NSMenuItem.submenu` 赋值实现「剪切板」悬停展开；`NSMenuDelegate.menuWillOpen` 在打开前刷新历史，保证内容最新。
- **剪切板历史**：`NSPasteboard` 在 macOS 上不提供变更通知，故以 0.5s 间隔轮询 `changeCount`，发现变化时记录新字符串（去重、限长 50 条）。
- **复制即入历史**：从菜单复制的内容会立即写入历史，无需等待下一次轮询。
- **设置弹窗**：基于 `NSWindowController` + 可编辑 `NSTableView`，编辑作用于工作副本，仅在 `保存` 时整体替换持久化数据，并通过通知驱动菜单重建。
- **持久化**：预置文本以 JSON 编码存入 `UserDefaults`；剪切板历史直接存为字符串数组。

## 可扩展方向

- 支持富文本 / 图片类型的剪贴板历史
- 全局快捷键唤起菜单
- 预置文本分组与搜索
- 导入 / 导出预置配置
