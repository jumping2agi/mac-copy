# MenuBarTool

一个 macOS 顶部状态栏常驻工具（原生 Swift / AppKit 开发，无第三方依赖）。

## 功能

- 点击状态栏图标弹出下拉菜单
  - **预置快捷文本**：点击即复制到剪贴板
  - **剪切板**（悬停展开二级菜单）：展示历史复制内容，点击重新复制；底部可一键清空
  - 菜单最下方常驻 **设置…** 与 **退出**
- 点击 **设置…** 弹出窗口，可对预置快捷文本进行增、删、改
  - 两列表格（标题 / 内容），均可在行内直接编辑
  - `保存` 提交、`取消` 放弃（⌘↩ 保存，Esc 取消）
- 无 Dock 图标、无主菜单栏，仅作为菜单栏后台代理运行（`LSUIElement = true`）
- 预置文本与剪切板历史均持久化在 `UserDefaults`，重启后保留

## 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 11.0 (Big Sur) 及以上 |
| Swift | 5.9+（随 Xcode 自带） |
| 工具链 | Xcode Command Line Tools |
| 依赖 | 无第三方依赖 |

检查环境：

```bash
swift --version          # 确认 Swift 5.9+
xcode-select -p          # 确认 Command Line Tools 已安装
```

如果未安装工具链：

```bash
xcode-select --install
```

## 目录结构

```
.
├── .github/workflows/
│   └── release.yml                     # GitHub Actions：构建并发布到 Release
├── Package.swift                       # SwiftPM 包定义
├── Resources/
│   └── Info.plist                      # App bundle 配置（LSUIElement 等）
├── Scripts/
│   └── build.sh                        # 编译、打包、签名、压缩
├── Sources/MenuBarTool/
│   ├── main.swift                      # 入口，设置 .accessory 激活策略
│   ├── AppDelegate.swift               # 启动状态栏 + 剪切板轮询
│   ├── StatusBarController.swift       # NSStatusItem 与下拉菜单 / 二级菜单
│   ├── PresetTextManager.swift         # 预置快捷文本的加载与持久化
│   ├── ClipboardHistoryManager.swift   # 轮询 NSPasteboard，维护历史
│   ├── SettingsWindowController.swift  # 设置弹窗（可编辑表格）
│   └── AppConstants.swift              # 常量与 PresetText 模型
└── README.md
```

## 快速开始

```bash
git clone <your-repo-url> MenuBarTool
cd MenuBarTool

# 一键编译、打包、签名、启动
./Scripts/build.sh run
```

状态栏会出现一个剪贴板图标 📋，点击即可使用。

## 构建方式详解

本项目提供三种构建途径，按需选择。

### 方式一：build.sh 脚本（推荐）

脚本内部调用 SwiftPM 编译，再将产物组装成 `.app` bundle 并做 ad-hoc 签名。

```bash
# 1) Release 构建（默认）→ build/MenuBarTool.app
./Scripts/build.sh

# 2) Debug 构建（含调试符号，体积略大）
./Scripts/build.sh debug

# 3) 构建并直接启动
./Scripts/build.sh run

# 4) 构建并打包成 zip（用于分发 / 上传 Release）
./Scripts/build.sh zip
#   产物：build/MenuBarTool.app + build/MenuBarTool.zip
```

脚本做了什么：

1. `swift build -c <release|debug>` 编译可执行文件
2. 创建 `build/MenuBarTool.app/Contents/{MacOS,Resources}/` 目录结构
3. 拷贝可执行文件到 `Contents/MacOS/MenuBarTool` 并 `chmod +x`
4. 拷贝 `Resources/Info.plist` 到 `Contents/Info.plist`
5. `codesign --sign - --force --deep` 做 ad-hoc 签名（无需开发者证书）

### 方式二：SwiftPM 直接运行（不打包）

适合快速迭代调试，不生成 `.app` bundle：

```bash
swift run
```

此方式没有 `Info.plist`，但代码中 `app.setActivationPolicy(.accessory)` 同样会隐藏 Dock 图标，功能完整。

### 方式三：用 Xcode 打开

```bash
open Package.swift
```

Xcode 会识别 SwiftPM 包，选择 `My Mac` target 后直接 ⌘R 运行。

## 安装到系统

### 从源码安装

```bash
git clone <your-repo-url> MenuBarTool
cd MenuBarTool
./Scripts/build.sh

# 安装到 /Applications（需要管理员密码）
sudo cp -R build/MenuBarTool.app /Applications/

# 启动
open /Applications/MenuBarTool.app
```

### 设置开机自启

1. 打开 **系统设置 → 通用 → 登录项与扩展**
2. 在 **登录时打开** 下点击 **+**
3. 选择 `/Applications/MenuBarTool.app`，点击添加

或者用命令行添加：

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/MenuBarTool.app", hidden:true}'
```

查看 / 移除：

```bash
# 查看当前登录项
osascript -e 'tell application "System Events" to get the name of every login item'

# 移除
osascript -e 'tell application "System Events" to delete login item "MenuBarTool"'
```

### 从 GitHub Release 安装

1. 前往项目的 **Releases** 页面
2. 下载 `MenuBarTool.zip`
3. 解压后将 `MenuBarTool.app` 拖入 `/Applications/`
4. 首次打开时若被 Gatekeeper 拦截：
   - **系统设置 → 隐私与安全性**，点击 **仍要打开**
   - 或在终端执行：
     ```bash
     xattr -cr /Applications/MenuBarTool.app
     open /Applications/MenuBarTool.app
     ```

## GitHub Actions 自动发布

仓库内置 `.github/workflows/release.yml`，支持两种触发方式：

### 方式一：推送 tag 自动发布

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions 会自动在 `macos-14` runner 上构建、打包 zip、创建 Release 并上传产物。

### 方式二：手动触发

1. 前往仓库的 **Actions** 页面
2. 左侧选择 **Release** 工作流
3. 点击 **Run workflow**，输入版本号（如 `v1.0.0`）
4. 等待构建完成，Release 页面会出现下载链接

### 关于签名与公证

当前 workflow 使用 **ad-hoc 签名**（`codesign --sign -`），适用于个人使用和开源分发。用户首次打开需手动允许（见上方 Gatekeeper 说明）。

如需 **正式公证**（Notarization，消除 Gatekeeper 提示）：

1. 加入 Apple Developer Program
2. 在 GitHub Secrets 中配置：
   - `APPLE_DEVELOPER_ID` — Developer ID Application 证书名称
   - `APPLE_DEVELOPER_ID_PASSWORD` — 对应的密码（或 App-specific password）
   - `APPLE_TEAM_ID` — 团队 ID
3. 修改 `Scripts/build.sh` 中的签名步骤为 Developer ID 签名 + `xcrun notarytool submit`

## 设计要点

| 特性 | 实现方式 |
|------|----------|
| 菜单栏常驻 | `NSStatusBar.system.statusItem(...)` + SF Symbol `doc.on.clipboard` 图标 |
| 下拉菜单 | `statusItem.menu = NSMenu`，点击状态栏图标即弹出 |
| 二级菜单 | `NSMenuItem.submenu = NSMenu`，鼠标悬停自动展开 |
| 剪切板轮询 | 0.5s 间隔轮询 `NSPasteboard.changeCount`（macOS 无变更通知） |
| 复制即入历史 | 写入 pasteboard 后立即调用 `add()` + `syncChangeCount()` 防重复 |
| 历史去重 | 同内容自动移到最前，最多保留 50 条 |
| 设置弹窗 | `NSWindowController` + 可编辑 `NSTableView`，工作副本模式，保存时整体写回 |
| 持久化 | `UserDefaults`：预置文本 JSON 编码，剪切板历史字符串数组 |
| 无 Dock 图标 | `Info.plist` 的 `LSUIElement = true` + 代码 `setActivationPolicy(.accessory)` |
| 数据安全 | 菜单项存储实际内容（非索引），菜单过期也不会复制错误内容 |

## 可扩展方向

- 支持富文本 / 图片类型的剪贴板历史
- 全局快捷键唤起菜单
- 预置文本分组与搜索
- 导入 / 导出预置配置
- 开机自启辅助工具（LaunchAgent）

## 常见问题

**Q: 构建报错 "No such module 'AppKit'"？**

A: AppKit 仅在 macOS 上可用。请在 Mac 上执行构建，而非 Linux 或 Windows。

**Q: 状态栏没有出现图标？**

A: 检查是否有其他菜单栏应用占满了空间，导致图标被隐藏。尝试按住 ⌘ 拖动其他图标来腾出空间。

**Q: 剪切板历史没有记录？**

A: 确认应用正在运行（状态栏有图标）。历史通过轮询 `NSPasteboard` 获取，复制后最多 0.5 秒延迟。

**Q: 如何重置所有数据？**

A: 打开终端执行：
```bash
defaults delete com.menubar.tool
```
然后退出并重新启动应用。
