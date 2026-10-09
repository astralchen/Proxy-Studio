# Proxy Studio

一个使用 SwiftUI 开发的本地代理配置工具。支持 iOS 26+（iPhone、iPhone Duo、iPad）和原生 macOS 26+。

产品范围、功能规则与验收标准见 [产品需求文档](REQUIREMENTS.md)；开发协作遵循 [AGENTS.md](AGENTS.md)，实际验证状态见 [VALIDATION.md](VALIDATION.md)。

## 界面预览

![Proxy Studio 宽屏分栏界面：左侧导入 SOCKS 链接，右侧展示待导入提示](Preview/duo-split-view.png)

![原生 Mac 浅色二维码工作区](Preview/mac-light-qr.png)

![原生 Mac 字段对齐后的节点工作区](Preview/mac-summary-aligned.png)

## 打开与运行

1. 使用 **Xcode 27.1 或更新版本**打开 `ProxyStudio.xcodeproj`。iPhone Duo 的完整屏幕适配依赖 iOS 27.1 SDK；工程最低运行版本仍为 iOS 26.0。
2. iOS 选择 `ProxyStudio` Scheme 和一个 iPhone / iPhone Duo / iPad 模拟器；Mac 选择 `ProxyStudioMac` Scheme 和 `My Mac`，运行。
3. 真机运行时，在 Signing & Capabilities 中选择自己的 Team，并修改 `com.example.ProxyStudio` Bundle Identifier。

工程使用 Apple 系统框架，无需 CocoaPods、外部 Swift Package 或 API 密钥。

## 原生 macOS

iOS 与 Mac 使用独立 app target 和共享源码：`ProxyStudio` / `ProxyStudioMac`，分别提供同名共享 Scheme。Mac 最低支持 **macOS 26.0**，使用原生 AppKit / SwiftUI，未使用 Mac Catalyst。

Mac 工作区左侧导入，右侧显示节点摘要及“二维码 / Clash YAML”标签页。摘要字段共用标签列和值列，服务器、端口、账号和密码按列对齐，长值按可用宽度换行。YAML 随 UDP 开关即时更新，可选择复制并按窗口宽度换行；保存内容始终使用原始文本。默认窗口内容为 1100×760 pt，最小内容为 760×560 pt；窗口和分栏调整保留会话，每个新窗口拥有独立输入、节点和输出选项。

- `⌘↩` 解析，`⇧⌘⌫` 清空，`⌘1` / `⌘2` 切换输出，`⌘N` 新窗口；YAML 标签页中 Escape 返回二维码。
- 使用原生系统保存面板和图片 / 链接分享入口。默认文件名为 `shadowrocket.png`、`clash.yaml`；取消不显示成功提示，也不清除会话。
- `Core` 与共享 `Services` 共用于两平台；平台入口、视图和图片分享按 target membership 隔离，无需平台条件编译。
- Mac 启用 App Sandbox，仅申请用户选择文件的读写权限；会话和凭据不写入持久化存储。

从项目根目录执行：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -destination 'platform=macOS' -derivedDataPath .build/mac \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
./script/build_and_run.sh --verify
```

本地运行脚本使用临时签名，不改变工程的 Team 配置；默认执行停止旧 Mac 进程、构建及启动。另提供 `--debug`、`--logs`、`--telemetry`，Codex 的 Run 按钮调用同一入口。重新运行会结束旧进程的内存会话。构建产物和测试结果位于被忽略的 `.build/`。

实际构建、测试、保存文件及桌面检查证据见 [VALIDATION.md](VALIDATION.md)；macOS 26.0 最低系统运行、第三方客户端兼容性等未完成项单独记录，不由编译结果代替。

## 使用

粘贴 SOCKS 链接 → 解析链接 → 查看节点详情 → 保存或分享 Shadowrocket 二维码，或预览、导出 Clash YAML。

- 支持 `socks://`、`socks5://`、`socks\://…\@…` 转义格式。
- 支持 Base64 / Base64URL 编码的 `username:password`，以及 URL 百分号编码的明文账号密码。
- 支持 IPv4、域名和方括号 IPv6，无认证节点也可导入。
- 检查端口、认证长度和非法字符；拒绝未支持的查询参数，避免静默丢失连接选项。
- 二维码包含四模块白色留边；PNG 和 YAML 都可存入“文件”。
- Clash 默认所有进入客户端的流量走节点；策略组提供 `DIRECT`，UDP 默认关闭。
- 示例节点使用虚构域名和账号，不能用于实际连接。真实账号不会被嵌入工程或测试中。

本应用负责生成配置，不提供 VPN 隧道、不测试节点连通性，也不在后台连接代理。输入只保存在当前内存状态中，退出应用后不保证保留；导出的文件包含认证信息。

## iPhone Duo 适配

- 使用 iOS 27.1 SDK 编译，最低部署版本为 iOS 26.0。
- `NavigationSplitView` 在窄屏折叠为单列导航，宽屏显示导入区和详情区；状态由根视图持有，窗口尺寸变化不会重建输入。
- 不通过 `UIDevice` 型号、横竖屏判断或 `UIScreen.main` 决定布局。
- 系统导航栏、表单和 sheet 处理安全区域，包括 Duo 的非对称区域；交互内容不越过安全区域。
- 支持横竖屏与可调整窗口。二维码按容器缩放；辅助功能大字体下二维码按钮改为纵向排列，正文可滚动。
- 二维码放在详情列，避免在展开时横跨导入区与详情区。

验证设备形态时请在 Xcode Device Hub 中切换外屏、展开、书本式折叠、支架姿态、横竖屏和 Split View。具体已完成的验证见 `VALIDATION.md`。

官方参考：
- [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)
- [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/)
- [Mihomo SOCKS 配置](https://wiki.metacubex.one/en/config/proxies/socks/)

## 代码结构

`ProxyStudio/` 在 Xcode 中使用同步文件夹（`PBXFileSystemSynchronizedRootGroup`），目录结构直接跟随磁盘。两个 app target 共用 `Core`、`Services` 和 `Platforms/Resources`，并通过 membership exceptions 排除另一平台的源码。新增平台专属文件时，需在 File Inspector 中确认 Target Membership 仅勾选所属平台。

- `ProxyStudio/Core`：链接解析、规范化、Clash YAML 生成。
- `ProxyStudio/Services`：平台无关的 Core Image 二维码、PNG 编码与文件文档。
- `ProxyStudio/Platforms/iOS`：iOS 应用入口、导入、节点详情、YAML 快照预览和 UIKit 分享。
- `ProxyStudio/Platforms/macOS`：Mac 应用入口、桌面视图、`Stores/ProxySession` 和 AppKit 图片分享。
- `ProxyStudio/Platforms/Resources`：两平台共享的颜色、图标资源。
- `ProxyStudioTests`：两平台共用的解析边界、IPv6、转义、YAML 和实际 PNG 回验。
- `ProxyStudioMacTests` / `ProxyStudioMacUITests`：Mac 会话和原生桌面流程；不使用移动端旋转或文档选择器标识。
- `ProxyStudioUITests`：示例导入、详情、旋转、大字体与导出界面。

在 Xcode 中按 `⌘U` 执行测试，或：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -destination 'platform=iOS Simulator,name=iPhone Duo' test
```

## 应用图标

已配置 AppIcon 的 Any Appearance、Dark、Tinted 三种外观，均为 1024×1024 PNG。相扣方环表达节点连接和配置转换：默认版为白色、薄荷色主体与青绿背景；深色版为青蓝、翡翠绿主体与透明背景；着色版为标准灰度图，供系统重新着色。正式资源位于 `ProxyStudio/Platforms/Resources/Assets.xcassets/AppIcon.appiconset/`，两个 app target 的 Debug、Release 均引用 AppIcon。Mac 槽位沿用默认图形，补齐 16、32、128、256、512 pt 的 1× / 2× 尺寸；iOS 三种外观资源保持原样。

使用内置 image_gen 工具创作，随后使用系统 sips 缩放，并将 Tinted 转换到 Gray Gamma 2.2。原稿、设计说明与完整提示词见 `Design/`。资源采用静态 PNG 与系统圆角裁切，未制作 Icon Composer 分层文件。


## 代码注释约定

Swift 代码采用 UIKit SDK 式的声明文档风格，并以中文描述行为：类型和成员使用 `///` 简述职责、默认值与可空语义；方法按需说明 `Parameter`、`Returns`、`Throws`；限制和重要行为使用 `Note`、`Important`。使用 `// MARK: -` 划分职责，普通 `//` 注释只解释实现原因和边界条件。测试注释描述验证契约及证据范围，避免将发出旋转请求等同于确认横屏布局。
