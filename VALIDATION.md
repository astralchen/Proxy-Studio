# 验证记录

验证时间：2026-10-08、2026-10-09。本文按增量保留历史证据；Shadowrocket JSON 的最新结果见文末“Shadowrocket JSON 增量验证”。此前双平台结果见“原生 macOS 交付验证”与“本次 iOS 回归”。以下首张表是早期 iOS 验证记录。完整测试套件在 YAML 预览换行修正前通过；核心解析、二维码与导出逻辑此后未变。换行修正后的最终源码已通过 iOS 26.5 和 27.1 SDK 编译；最终界面回归在模拟器启动与事件监控阶段被环境阻塞。

| 项目 | 结果 | 证据与边界 |
| --- | --- | --- |
| Xcode 27.1 / iOS 27.1 Simulator SDK 编译 | 通过 | App、单元测试、UI 测试目标均成功构建 |
| Xcode 26.6 / iOS 26.5 Simulator SDK 编译 | 通过 | 验证 iOS 26 API 基线可编译；最低部署版本 26.0 |
| iPhone Duo / iOS 27.1 单元测试 | 通过 | 8 项：Base64、Base64URL、转义链接、IPv6、认证回环、非法输入、YAML 转义、二维码解码回验 |
| iPhone Duo / iOS 27.1 UI 测试 | 通过 | 2 项：辅助功能最大字号，以及示例导入→详情→YAML 预览→保存 YAML→成功回执 |
| 完整测试套件汇总（换行修正前） | 通过 | 10 passed / 0 failed / 0 skipped；结果包为 outputs 下的 ProxyStudio-TestResults.zip |
| 最后换行修正后的 UI 回归 | 被环境阻塞 | 第一次启动返回 Busy；重启后出现 Unable to monitor event loop / animations，无法可靠完成自动化；未将这次运行计为通过 |
| 外屏可视检查 | 通过 | 已查看外屏详情、大字体和系统导出面板；内容避让右侧系统栏 |
| 横屏实际布局 | 未执行 | 测试发送了 landscapeLeft 事件且后续流程通过，但模拟器截图仍为 466×678 pt 竖屏，不能据此认定真实横屏已验证 |
| 内屏展开、书本式/支架式折叠、Split View | 被环境阻塞 | Device Hub 已安装并运行，但通过当前 UI 自动化连接多次超时；未完成这些姿态的交互与可视检查 |
| iOS 26 真机、iPad、RTL、深色模式 | 未执行 | 不以模拟器编译或 Duo 外屏测试代替这些检查 |
| 真实代理连通性与 Shadowrocket/Clash 实机导入 | 未执行 | 本应用为本地配置工具；测试仅使用虚构节点 |

## 已解决的问题

- 为 FileDocument 显式声明 YAML 类型，修复系统导出类型不匹配。
- YAML 预览改为按安全区域内可用宽度换行，避免长行延伸到 Duo 右侧系统栏下方；导出文件仍保留原始文本。
- 使用文档保存面板的稳定控件标识，验证实际保存成功，避免依赖本地化按钮名称。
- 二维码回验使用兼容的 Vision 检测 revision，避开当前模拟器新模型缺失的错误。

## 后续设备验证

用 Xcode 27.1 打开工程，在 Device Hub 中逐一检查：外屏横屏、内屏展开、半折书本、半折支架、两侧 Split View。关注：输入和已解析节点持续存在；二维码位于完整可用区域；按钮可达；系统 sheet 不被摄像头或折叠区域遮挡。

截图目录：`Preview/`。保留的截图对应未受最后换行修正影响的外屏详情、大字体和系统保存面板。所有截图均使用虚构账号。YAML 预览的最终换行效果尚待再次可视核验。


## 三种应用图标外观（2026-10-08）

- 通过：Any Appearance、Dark、Tinted 三个槽位均有正式 1024×1024 PNG 引用。
- 通过：默认图标不透明；Dark 的 alpha 通道包含透明背景；Tinted 为单通道灰度（Gray Gamma 2.2）。
- 通过：小尺寸图片人工检查，相扣方环轮廓可辨识。
- 通过：Xcode 27.1，Debug，generic iOS Simulator 构建成功，编译后的 CFBundleIcons 指向 AppIcon。
- 未执行：本次图标增量未重跑业务/UI 测试，未在主屏幕上切换三种外观进行设备检查。
- 构建日志：Design/BUILD_ICONS.log。


## 中文 SDK 风格注释（2026-10-08）

- 通过：为全部 9 个 Swift 文件（应用源码、单元测试与 UI 测试）添加中文声明文档和必要的实现注释。
- 通过：与修改前快照逐文件比较，排除注释和空行后代码完全一致，字符串常量与行为保持不变。
- 通过：Xcode 27.1，Debug，generic iOS Simulator 构建成功。
- 未执行：本次仅修改注释，未重跑单元测试和 UI 测试。

## 原生 macOS 交付验证（2026-10-08）

实现采用独立 `ProxyStudioMac` target / Scheme；iOS 保留 `ProxyStudio`。Mac 窗口会话类型为 `ProxySession`，平台文件按 `Platforms/iOS`、`Platforms/macOS` 及 target membership 隔离，业务源码不再使用 `#if os(...)` 或 `Mac` 类型前缀。核心解析、YAML、CGImage 二维码与 ImageIO PNG 编码共用。

本次主机为 macOS 27.0.1（26A434），Xcode 27.1（27A9269），Mac SDK 27.0；最低部署版本为 macOS 26.0。代码版本为基础提交 `1da130c` 加当前未提交变更；源码、工程、Scheme 和 entitlements 的 SHA256 清单在 `.build/validation/source-snapshot.json`，组合摘要为 `56cdcd8eab8563b532a160cbb93510da69c91e3d4439ec0e9c6c2c7c04820712`。文档随后更新，不计入该源码摘要。最终 Mac 套件于 18:29:57 +0800 完成，原生交互检查至 18:37 +0800；只使用虚构凭据。

| 项目 | 结果 | 证据与边界 |
| --- | --- | --- |
| 原生 destination、Debug / Release 构建 | 通过 | `ProxyStudioMac` 的 `platform=macOS`；Debug 可启动、Release `BUILD SUCCEEDED`。应用为 `Proxy Studio.app`，arm64 / x86_64 Mach-O 的 minos 均为 26.0，不启用 Catalyst；日志见 `.build/validation/proxy-mac-release-complete.log` 及运行日志 |
| 本地脚本、窗口与 Dock 图标 | 通过 | `./script/build_and_run.sh --verify` 构建、启动并确认进程；原生窗口及 Dock 相扣方环图标已实际检查。应用产物 `.build/run/Build/Products/Debug/Proxy Studio.app`；日志 `.build/validation/proxy-share-run.log` |
| App Sandbox 与文件权限 | 通过 | 本地运行 app 的签名 entitlements 包含 `app-sandbox=true`、`files.user-selected.read-write=true`；Debug 另含 `get-task-allow=true`。不改变工程 Team / Bundle Identifier |
| 共享单元测试 | 通过 | 10 项：Base64 / Base64URL、转义和明文凭据、往返、IPv6、非法输入、UTF-8 长度边界、YAML 转义与名称冲突、实际 PNG 回读及四边 40 px 白色静区 |
| 窗口会话单元测试 | 通过 | 6 项：输入失效、新节点重置、窗口独立、导出快照、保存结果与用户取消处理 |
| Mac UI 测试 | 通过 | 6 项：示例导入、密码与即时 UDP YAML / Escape、编辑失效和快捷键清空、独立新窗口、两种保存取消、浅色附件、实际窗口拖动及侧栏恢复。最终共 22 passed / 0 failed；结果 `.build/results/Mac-Delivery-Final.xcresult`，日志 `.build/validation/proxy-mac-delivery-final.log` |
| PNG / YAML 实际保存与文件回读 | 通过 | 原生保存面板分别写入 `/private/tmp/ProxyStudioValidation/shadowrocket.png`、`clash.yaml`；两次均显示“文件已保存。”。PNG 510×510，可由 Vision 回读且载荷等于 shareLink；YAML 426 bytes，逐字节等于当前 UDP=true 配置并含末尾换行。回读结果 `.build/qa/export-verification.txt` |
| PNG / YAML 实际写入失败 | 通过 | 原生面板分别保存到 chmod 555 的 `/private/tmp/ProxyStudioValidation/ReadOnly`，实际显示“保存失败：你没有将文件…保存到文件夹‘ReadOnly’中的权限。”；关闭提示后节点、密码显示及 UDP=true 保留，目录无输出文件。检查后目录恢复 755；此项是实际文件写入失败检查，另有结果回调单元测试 |
| PNG / YAML 保存取消 | 通过 | 两次原生面板使用 Escape 取消，不显示成功或失败，节点仍存在；系统面板优先响应 Escape，YAML 标签未被切换。最终 UI 结果包含对应断言和面板附件 |
| 图片系统分享界面 | 通过 | `NSSharingServicePicker` 从实际按钮 mouseDown 锚定，原生菜单可持续显示服务及“拷贝”。检查时发现 mouseUp 行为导致菜单不保留，已改为 NSButton 的 leftMouseDown action 并重新运行最终套件；分享对象由按钮 Coordinator 持有 |
| 导入链接分享界面与载荷 | 通过 | 实际打开 ShareLink 系统菜单，选择“拷贝”，在输入区粘贴所得完整链接与示例节点规范化 shareLink 一致 |
| 外部服务实际发送图片或链接 | 未执行 | 已检查原生入口、链接复制载荷及保存 PNG 的可解码内容，未向邮件、消息等外部目标发送 |
| 默认 / 最小 / 宽窗口、侧栏及滚动 | 通过 | 默认内容 1100×760 pt；实际拖至最小窗口外框 760×612 pt（内容 760×560 pt），再扩至 1260×612 pt；密码与 UDP 保留。隐藏 / 显示侧栏不重置；最小窗口中滚动可到完整二维码和操作按钮 |
| 分栏调整与两窗口独立 | 通过 | 原生分隔器由 300 调至 380 pt，输入、节点、密码和 UDP 保留；Cmd-N 的两个窗口输入和选项独立，最终 UI 测试覆盖 |
| 系统文本编辑与键盘 | 通过 | 实际输入区 Cmd-A 选择、链接复制 / 粘贴、编辑使旧节点消失；Cmd-Z 恢复原输入、Shift-Cmd-Z 重做恢复替换文本，再解析恢复节点。UI 测试覆盖 Cmd-Return、Shift-Cmd-Delete、Cmd-2、Escape、Cmd-N 及空输入解析禁用；菜单通过 FocusedSceneValue 路由当前窗口 |
| 浅色 / 深色、YAML 换行 | 通过 | 人工查看最终窗口附件；浅色 / 深色文字、二维码与按钮可见。最小窗口 YAML 长行按宽度视觉换行，实际文件字节保持原文。截图见下面目录；DEBUG 测试参数仅对被测 app 设置外观，无参数时跟随系统 |
| 工程与交付检查 | 通过 | `plutil -lint ProxyStudio.xcodeproj/project.pbxproj`、`bash -n script/build_and_run.sh`、最终 `git diff --check`；源码摘要与当前文件逐项一致，资源目录文档已同步 |
| macOS 26.0 最低系统运行、Intel 实机 | 未执行 | 构建确认部署版本与双架构；本机实际运行环境为 macOS 27.0.1 / Apple Silicon，不能替代最低系统或 Intel 运行 |
| Mac VoiceOver / RTL、第三方客户端导入 | 未执行 | 有中文辅助功能名称及虚构凭据二维码，但未完成读屏、RTL 或 Shadowrocket / Clash 的实际导入 |

保留的应用窗口截图：`Preview/mac-light-qr.png`、`mac-light-yaml.png`、`mac-dark-qr.png`、`mac-dark-yaml.png`、`mac-minimum-yaml.png`、`mac-wide-yaml.png`、`mac-save-png.png`、`mac-save-yaml.png`。原始 XCTest 附件在结果包及 `.build/qa/mac-complete/`，不截取其他应用或用户桌面。

可复现的最终构建与测试命令：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/mac \
  -resultBundlePath .build/results/Mac-Delivery-Final.xcresult \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -configuration Release -destination 'platform=macOS' -derivedDataPath .build/mac-release \
  CODE_SIGNING_ALLOWED=NO build
./script/build_and_run.sh --verify
```

结果包路径须在再次运行时换为不存在的新目录。`.build/` 及临时回读文件为本地证据，不进入源码提交；发行签名、公证及商店上传未执行。

## 本次 iOS 回归（2026-10-08）

当前二维码服务及源码目录调整后重新执行，以下结果不引用前面的历史通过记录。模拟器为 iPhone Duo / iOS 27.1；另尝试 iPhone 17 Pro / iOS 26.5 的 UI 回归。

| 项目 | 结果 | 证据与边界 |
| --- | --- | --- |
| iOS Simulator Debug 最终构建 | 通过 | `ProxyStudio` / generic iOS Simulator，最新 `BUILD SUCCEEDED`；`.build/validation/proxy-ios-build-delivery.log` |
| 当前共享单元测试 | 通过 | 10 passed / 0 failed，实际 PNG 编码、载荷回读、静区及解析 / YAML 均重新运行；`.build/results/iOS-Duo-Final.xcresult`，`.build/validation/proxy-ios-test-final.log` |
| 最大辅助功能字号 | 通过 | 最终 UI 回归中大字体测试通过；`.build/results/iOS-Duo-Scoped-UI.xcresult` |
| 导入→详情→YAML 预览→保存成功回执 | 失败 | 最新 Duo UI 回归在 `ProxyStudioUITests.swift:52` 等待成功 alert 失败；此前导入、详情、预览与原生保存面板已到达，保存后系统 FileProvider 显示“进行中”，未验证完成写入。最终 UI 为 1 passed / 1 failed；日志 `.build/validation/proxy-ios-scoped.log`，不能视为整套回归通过 |
| 模拟器结果汇总延迟 | 被环境阻塞 | Xcode 反复报告版本解析 `invalidDigitCount(94401)` / `invalidDigitCount(94403)`，结果汇总延迟约 11 分钟；iOS 26.5 尝试亦出现。结果包最终已生成，此工具问题不改写上述失败断言为通过；未确定保存卡住的根因 |
| 最低 iOS 26 真机、实际横屏及其他 Duo 姿态 | 未执行 | 当前编译及单元测试不代替这些实际设备检查；历史 Duo 外屏及 Device Hub 限制见上文 |

最新 UI 驱动使用窗口内 collection view 滚动，启动时恢复标准字号 / 竖屏基线，并对文件名输入执行双击聚焦；这些测试调整没有证明系统保存已经完成。当前 iOS 保存成功路径需在可完成 FileProvider 操作的设备或模拟器上继续检查。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -destination 'platform=iOS Simulator,name=iPhone Duo' -derivedDataPath .build/ios \
  -only-testing:ProxyStudioTests -resultBundlePath .build/results/iOS-Duo-Final.xcresult test
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -destination 'platform=iOS Simulator,name=iPhone Duo' -derivedDataPath .build/ios \
  -only-testing:ProxyStudioUITests -resultBundlePath .build/results/iOS-Duo-Scoped-UI.xcresult test
```

## Xcode 同步文件夹修复（2026-10-08）

本次仅修复工程目录与 target membership：将 `ProxyStudio` 从普通 `PBXGroup` 改为 `PBXFileSystemSynchronizedRootGroup`，移除迁移后残留的 `Views/Mac` 与 `Views` 目录；`Views` 中仅剩的 Finder `.DS_Store` 已移至被忽略的 `.build/folder-sync/Views.DS_Store`。两平台共享核心、服务和资源，通过相对根目录的 membership exceptions 排除另一平台源码，并恢复 iOS 平台源码参与编译。未修改业务实现。

| 项目 | 结果 | 证据与边界 |
| --- | --- | --- |
| 工程格式与目录结构 | 通过 | `plutil -lint ProxyStudio.xcodeproj/project.pbxproj`、`git diff --check`；确认同步根目录、旧目录已清理，以及 membership exceptions 指向现存文件 |
| iOS Debug / generic iOS Simulator 构建 | 通过 | Xcode 27.1（27A9269）；`ProxyStudio` Scheme，`CODE_SIGNING_ALLOWED=NO`；arm64 / x86_64 编译文件清单均包含 9 个应用源码，含 iOS 入口和视图，不含 macOS 源码；日志 `.build/folder-sync/ios-build.log` 为 `BUILD SUCCEEDED` |
| macOS Debug 构建 | 通过 | Xcode 27.1；`ProxyStudioMac` Scheme，`platform=macOS`，`CODE_SIGNING_ALLOWED=NO`；arm64 / x86_64 编译文件清单均包含 12 个应用源码，含 Mac 入口和视图，不含 iOS 源码；日志 `.build/folder-sync/mac-build.log` 为 `BUILD SUCCEEDED` |
| 单元测试、UI 测试及运行检查 | 未执行 | 本次为工程结构修复，验证范围为目录、源码归属及两平台编译；未将构建结果作为交互通过证据 |
| Xcode 界面重新打开与目录显示 | 未执行 | 工程文件已经配置为同步文件夹；未通过 Xcode UI 操作重复执行转换或检查导航器显示 |

构建命令（先设置 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`）：

```sh
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/folder-sync/ios CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/folder-sync/mac CODE_SIGNING_ALLOWED=NO build
```

首次受限沙箱构建因 `sandbox-exec: sandbox_apply: Operation not permitted` 导致 Swift 宏插件失败；获准在沙箱外按上述命令重试后，两平台均构建成功。日志中仅有未依赖 AppIntents 时跳过元数据提取的警告。

## Mac 节点摘要字段对齐（2026-10-09）

将摘要中独立布局的 `LabeledContent` 改为共享列宽的 `Grid` / `GridRow`：标签列靠右、值列靠左，行内采用首行文字基线对齐。服务器、端口、账号、密码使用相同值列；长文本按可用宽度换行，密码眼睛按钮保留固有尺寸。仅修改 Mac 详情布局及相关测试基线，未修改解析、二维码、YAML 或 iOS 视图。

| 项目 | 结果 | 证据与边界 |
| --- | --- | --- |
| Mac Debug 构建 | 通过 | Xcode 27.1，`ProxyStudioMac` / `platform=macOS`，本地临时签名；`.build/validation/alignment-20261009/build.log` 为 `BUILD SUCCEEDED` |
| 本次相关 UI 回归 | 通过 | 详情密码 / 即时 YAML / Escape、窗口缩放 / 侧栏 / 状态保留共 2 passed / 0 failed；`.build/results/Mac-Alignment-Delivery-20261009.xcresult`、`.build/validation/alignment-20261009/delivery-test.log` |
| 窗口测试基线调整前 | 失败 | 首次系统恢复最小高度 612 pt，缩小高度断言失败；后续恢复宽度 1260 pt，宽窗大于起始宽度的断言失败。结果分别为 `.build/results/Mac-Alignment-20261009.xcresult`、`Mac-Alignment-Verified-20261009.xcresult`。最终先固定窗口外框为 1100×812 pt，再缩到 760×612 pt、扩到 1260×612 pt；最新两项测试通过，不把旧断言失败归为环境阻塞 |
| 字段对齐与多行长文本 | 通过 | 实际启动新构建，查看虚构示例的隐藏 / 可见密码；服务器、端口、账号和密码的值起点一致。另输入长服务器、192 字节用户名和 238 字节密码，实际查看多行换行、首行基线及密码按钮未被挤出 |
| 最小窗口视觉检查 | 通过 | 查看最终 UI 附件，最小内容宽度 760 pt 时字段仍按列对齐；截图 `Preview/mac-summary-aligned-minimum.png`，普通摘要截图 `Preview/mac-summary-aligned.png` |
| 最终差异检查 | 通过 | `git diff --check`；本次两份 Swift 文件 SHA256 清单 `.build/validation/alignment-20261009/source.sha256` |
| 全套业务 / iOS / 保存分享回归 | 未执行 | 本次为 Mac 摘要布局修复，仅运行上述两项相关 UI 测试；前一天的 22 项测试及保存分享结果为历史记录，不作为当前增量重新运行证据 |

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/alignment \
  -resultBundlePath .build/results/Mac-Alignment-Delivery-20261009.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:ProxyStudioMacUITests/ProxyStudioMacUITests/testImportPasswordAndLiveYAML \
  -only-testing:ProxyStudioMacUITests/ProxyStudioMacUITests/testWindowResizeAndSidebarPreserveSession \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
```

截图仅包含被测 app 窗口和虚构凭据；结果包路径再次运行时应换为不存在的新目录。


## Shadowrocket JSON 增量验证（2026-10-09）

本次实现 iOS 与原生 macOS 当前单个 SOCKS5 节点的 JSON 预览和系统文件导出。格式契约来自已确认的单节点分享 / 导出样本：顶层对象、41 个字段，未改为数组。原文件仅用于检查字段与类型，示例、测试、截图及客户端验证均重新使用虚构节点 `proxy.example.com:1080` / `demo` / `example-password`。不增加 JSON 输入、批量节点或持久化。

JSONEncoder 使用 UTF-8、缩进、排序键及末尾换行；UUID 和创建时间由新节点所属详情 / 窗口会话生成，同一节点的预览、UDP 切换和重复导出保留元数据。预览与保存使用相同编码器，保存前捕获不可变字节快照。两平台共享 UDP 默认关闭；文件名为 `shadowrocket.json`、类型为 `.json`。Mac 的 Escape 由当前窗口的窄 AppKit 适配处理，原生保存面板和结果提示优先响应。

本机使用 Xcode 27.1（27A9269）、macOS 27.0.1（26A434）。iPhone Duo 运行 iOS 27.1；iPad Pro 11-inch (M5) 使用本机可用的 iOS 26.5。基础提交为 `13251d2`，本次为未提交变更。源码、工程和测试摘要保存在 `.build/validation/json-20261009/source-snapshot.json`；日志和原始附件位于同目录，结果包位于 `.build/results/JSON-*.xcresult`。`.build/` 与临时回读文件为本地证据，不提交。

| 项目 | 结果 | 证据与边界 |
| --- | --- | --- |
| iOS Simulator Debug 构建 | 通过 | generic iOS Simulator，`.build/validation/json-20261009/ios-build.log`，`BUILD SUCCEEDED` |
| iOS 共享单元测试与 JSON UI 最终增量套件 | 通过 | 16 项共享单元测试与 3 项 JSON UI 测试全部通过，0 failed；`JSON-iOS-Complete-20261009.xcresult`、`ios-complete.log`。原有 YAML 保存 / 旋转 UI 测试不在本次增量套件中，其历史失败记录保留 |
| JSON 字段、类型与确定性 | 通过 | JSONSerialization 验证顶层对象、完整键集合、字符串 / 整数 / 浮点类型，覆盖认证和免认证、IPv4 / 域名 / IPv6、1 / 65535 端口、中文及特殊凭据、UDP 0 / 1、固定元数据、重复编码及非法时间抛错 |
| iPhone Duo 最大辅助功能字号预览 | 通过 | `testJSONPreviewAtAccessibilityTextSize`；可见等宽文本按可用宽度换行，“完成”可点击；原始附件见 `ios-attachments/` |
| iPhone Duo JSON 实际保存与回读 | 通过 | `testJSONSaveSuccess` 到达系统保存面板并收到“文件已保存。”；File Provider Storage 的实际文件为 821 bytes，与 xcresult 内“iOS-JSON-预览原始字节”附件逐字节相等，也与当前编码器重建结果相等；`file-readback.txt`、`ios-file-readback.json`；最终套件另外写入唯一文件名的 821-byte 文件，再与本次预览附件逐字节比较，记录 `ios-file-readback-final.json` |
| Mac 实际保存与实际写入失败 | 通过 | `testJSONActualSaveAndReadOnlyFailure`：系统面板写入文件与预览字节一致；chmod 555 的独立测试目录写入失败，实际显示保存失败提示且未生成文件，节点与 JSON 保留；测试结束恢复目录权限。`JSON-Mac-Complete-20261009.xcresult` 与 `mac-complete.log` |
| Mac 本地构建与启动 | 通过 | 最终 `./script/build_and_run.sh --verify` 返回 0；`mac-run-final.log` 包含 `BUILD SUCCEEDED`，原生 app 已启动并实际通过 ⌘↩ / ⌘3 显示虚构示例 JSON |
| Mac 原生构建及单元测试 | 通过 | 最终源码完成 26 项单元测试（共享 16、窗口会话 10）；`JSON-Mac-Complete-20261009.xcresult`，`mac-complete.log` |
| Mac JSON 快捷键、共享 UDP、取消与多窗口 | 通过 | 最终功能版本 JSON 即时预览 / 稳定 UUID、⌘3、JSON / YAML 共享 UDP、保存面板 Escape 优先及关闭后 Escape 返回二维码均通过；最终完整套件 7 项 UI 通过；尺寸测试的高度拖动未生效，窗口仍为 812 pt，该次完整套件为 33 passed / 1 failed。JSON 及 Escape 功能断言均通过，尺寸检查独立重验记录见下一行 |
| Mac 最小窗口布局 | 通过 | 窗口外框 760×612 pt，侧栏恢复到 380 pt 时 JSON 标签简写以容纳三项输出；辅助功能名称保留全称。预览、标签和导出按钮的水平范围均位于窗口内，UDP、密码和节点不变；`JSON-Mac-Resize-Verified-20261009.xcresult`、`mac-resize-verified.log`；最后仅调整测试窗口初始位置，避免底边不可达，实际宽高变化及全部范围断言通过 |
| iPhone Duo JSON / YAML 共享 UDP 与保存取消 | 通过 | `JSON-iOS-Complete-20261009.xcresult`，`ios-complete.log`；取消不显示提示，重开预览与原快照逐字相同 |
| iPad JSON 预览、大字体与保存取消 | 通过 | 最大辅助功能字号在 `JSON-iPad-Delivery-20261009.xcresult` 中通过；标准字号取消流程在 `JSON-iPad-Verified-20261009.xcresult` 中通过。使用实际左右滚动容器，iOS 26.5 的保存按钮使用观察到的“保存”名称查询；未以只到面板认定保存成功 |
| Shadowrocket 2.2.92 “数据 → 导入节点” | 失败 | 本机版本 2.2.92 / 3445，选中实际生成的 821-byte `shadowrocket.json` 后，原生 `OKButton` 仍禁用；双击只显示 JSON 预览，不导入。文件选择阶段未把内容交给解析器，不能推断是单对象结构被拒绝。取消后未添加节点或改变连接状态；`shadowrocket-compatibility.json` |
| 客户端节点字段核对 | 未执行 | 上述入口未完成导入，无法核对客户端名称、协议、地址、端口、凭据与 UDP；保持单对象契约，不改为数组或其他扩展名 |
| iOS 真机、其他 Duo 姿态、RTL / VoiceOver、macOS 26 / Intel | 未执行 | 当前模拟器和本机检查不代替上述验收 |

首轮 iOS JSON / YAML 共享 UDP 测试点击了 SwiftUI 开关整行的中心，UDP 未开启，已改为点击右侧控件并断言开关值。随后一次 Duo 测试在等待保存面板时断言失败；测试补充等待预览退出，后续完整 JSON 流程通过，此项不据此认定失败的唯一原因。Mac 的测试还发现保存面板关闭后 Escape 的焦点路由缺口和最小窗口横向溢出：新增当前窗口键盘适配及容器宽度约束，并补充按钮 / 预览处于窗口水平范围内的断言。系统设置窗口遮挡的 UI 失败独立保留，不记作功能通过。

iPad 首次自动化因手势落在另一侧分栏及查询未进入视口的控件而失败；已按左右容器滚动。其原生保存按钮的标识与 Duo 不同，面板实际存在但旧断言失败，改用观察到的“保存”按钮后取消流程通过。Mac 最小分栏中系统 segmented picker 的固有宽度仍超过分栏，隐藏重复标签并仅在窄分栏简写 JSON 名称后，范围断言与截图检查通过。新增 AppKit 文件显式排除 iOS target，修复初次未设置 membership 时的 iOS 编译失败。

iOS 27.1 的 Xcode 测试结束后仍可能因 `invalidDigitCount(94401/94403)` 和模拟器诊断收集超时，延迟约 10 分钟才完成结果包。以实际 XCTest 日志和生成后的结果包记录结论，不把诊断延迟视为业务通过或失败。2026-10-08 的 YAML FileProvider “进行中”保存失败记录保持原文，本次 JSON 文件确实保存成功不覆盖该历史记录。

复现命令（再次运行须为结果包使用新路径）：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -destination 'platform=macOS' -derivedDataPath .build/json-mac \
  -resultBundlePath .build/results/JSON-Mac-Complete-20261009.xcresult \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
  -destination 'platform=macOS' -derivedDataPath .build/json-mac \
  -resultBundlePath .build/results/JSON-Mac-Resize-Verified-20261009.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:ProxyStudioMacUITests/ProxyStudioMacUITests/testWindowResizeAndSidebarPreserveSession \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -destination 'platform=iOS Simulator,name=iPhone Duo' -derivedDataPath .build/json-ios \
  -resultBundlePath .build/results/JSON-iOS-Complete-20261009.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:ProxyStudioTests \
  -only-testing:ProxyStudioUITests/ProxyStudioUITests/testJSONPreviewSharedUDPAndCancelExport \
  -only-testing:ProxyStudioUITests/ProxyStudioUITests/testJSONPreviewAtAccessibilityTextSize \
  -only-testing:ProxyStudioUITests/ProxyStudioUITests/testJSONSaveSuccess test
```

本次截图：`Preview/ios-shadowrocket-json.png`、`ios-shadowrocket-json-accessibility.png`、`ipad-shadowrocket-json.png`、`ipad-shadowrocket-json-accessibility.png`、`mac-shadowrocket-json.png`、`mac-shadowrocket-json-minimum.png`。截图经过实际查看，仅含应用窗口及虚构示例节点。


## 2026-10-09 — Shadowrocket 二维码格式对齐

本轮在已有 JSON 实现上调整二维码与分享链接，保留前文历史验证记录。输入范围仍为单条 SOCKS 链接，未增加图片识别或 JSON 输入。

- 分享链接采用 `socks://Base64(用户名:密码@服务器:端口)?remarks=百分号编码名称&udp=0/1`；免认证时只编码服务器与端口，IPv6 使用方括号。旧的 Base64 认证字段、明文认证和片段名称仍可解析。整体 Base64 / Base64URL、特殊凭据、中文混合百分号名称及参数拒绝规则由单元测试覆盖。
- 二维码改为 H 级纠错。导出选项在二维码、JSON、YAML 间共享，Mac 所有标签页均显示 UDP。新节点按链接参数初始化；缺省关闭。修改选项不刷新 JSON UUID 与时间，保存面板使用不可变 PNG 快照。
- 与用户原图的脱敏比较 **通过**：链接载荷逐字节相同（116 字节）；纠错 H、版本 10、57×57 模块、掩码 7 一致。新输出 670×670 像素，每模块 10 像素、四边 50 像素白色静区；原图 1280×1280、四边 22 像素。保留足够静区，未复制原图的窄留边。真实节点仅在内存中用于比较，报告、测试与截图不保存其凭据。
- Mac 最终共享/会话单元测试 **通过**：30 个、0 失败。包括解析兼容、PNG Vision 回读、H 纠错、UDP 实时更新、快照、取消及窗口会话隔离。
- iOS 最终共享单元测试 **通过**：19 个、0 失败。JSON UDP 预览/取消及辅助功能最大字号两项 UI 回归 **通过**。
- 实际 iOS PNG 保存与取消在首轮 UI 流程 **通过**，主机回读确认 14,271 字节、670×670、H 纠错，虚构节点载荷与预期相同。最终批次中的 PNG UI 测试在首次保存面板显示空弹出层、未找到系统保存按钮，记为 **失败**；单独复测 `QR-iOS-PNG-Final-20261009.xcresult` **通过**（1 项、0 失败），最终保存文件再次回读通过。不以重跑成功删除该历史失败记录。
- 本机 Shadowrocket 2.2.92（3445）“扫描二维码 → 打开相册”验证 **被环境阻塞**：原生文件选择器选中了上述实际 PNG，但“打开”被禁用，双击没有导入。已取消，未创建测试节点或修改已有连接。客户端字段与导入完成验收 **未执行**；这不构成格式被客户端拒绝的结论。JSON 的历史入口失败记录继续保留。

证据位于忽略目录 `.build/validation/qr-alignment-20261009/`：`comparison.json`、`ios-file-readback-initial.json`、`mac-file-readback.json`、`shadowrocket-client.json` 和构建/测试日志。首轮 `QR-Mac-Units-20261009.xcresult` 与 `QR-iOS-20261009.xcresult` 暴露中文与 `%2B` 混合名称二次编码失败，已修复并通过两平台最终单元测试；`QR-Mac-Verified-20261009.xcresult` 的 PNG UI 停在屏外开关值查询，手动中止（退出 75），修正测试后实际保存回读通过。最终结果包与截图在本节追加实际结论。

- iOS 最终证据：`QR-iOS-Verified-20261009.xcresult` 为 19 单元 + 2 UI 通过、1 PNG UI 失败；`QR-iOS-PNG-Final-20261009.xcresult` 为 PNG UI 单独复测 1 项通过、0 失败。最终文件 `-qr-validation-8A482771.png` 回读 14,271 字节、H、670×670，报告 `ios-file-readback-final.json`。
- Mac 实际 PNG 文件回读 **通过**：`mac-file-readback.json`。与最终 iOS 文件 SHA-256 相同（`0261d2eb5f790ae676732fd0f553da0af5fcdac41107098d005d740a3c7ff543`），逐字节相等，详见 `cross-platform-png.json`。已回读的虚构 PNG 在 `Preview/shadowrocket-example-qr.png`。
- `QR-Mac-Final-20261009.xcresult` 中 30 单元及 JSON/Escape、PNG 实际保存两项 UI 已通过；窗口用例在缺失边栏文本框查询停滞，手动中止（退出 75）。截图发现 UI runner 的“文稿文件夹访问”系统提示遮挡，未授予额外权限。新增恢复前的存在性检查与单次点击重试，并将测试产物复制到 `/private/tmp/ProxyStudioQRValidation-20261009/Products` 从临时目录运行，避免文稿权限依赖。该次中止不能写为完整测试套件通过。

- 从临时目录运行的最终 `QR-Mac-Temp-Verified-20261009.xcresult` **全部通过**：30 个单元测试、3 个 UI 测试、0 失败。UI 覆盖二维码标签修改 UDP、JSON 共享状态、系统 PNG 保存/取消及 Vision 回读、JSON 保存面板 Escape、760×560 最小内容窗口、文本换行和边栏恢复。最终截图无文稿权限遮挡，系统设置窗口仍被 XCTest 记录为短暂干扰，但本批次全部完成。
- 本轮未重新执行 iPad、iOS 横屏/RTL/VoiceOver、最低 macOS 26 或 Intel 运行、真机相机扫码；这些项目为 **未执行**，不沿用旧记录作为二维码格式修改后的通过证据。

- 最终原生 Mac 构建与启动 **通过**：`./script/build_and_run.sh --verify` 退出 0，日志 `mac-run-final.log` 为 `BUILD SUCCEEDED`；Computer Use 确认最终 `.build/run/Build/Products/Debug/Proxy Studio.app` 中示例节点、二维码、共享 UDP 关闭状态及 PNG 按钮可见。工程 plist 校验与 `git diff --check` **通过**。
- 新增已检查的截图：`Preview/mac-shadowrocket-qr.png`、`Preview/mac-shadowrocket-shared-udp-minimum.png`。iOS 保存测试截图保留在结果附件，截图时二维码上缘滚动到可视区域之外，不将该截图作为完整二维码可见性通过证据；实际 PNG 完整性由保存回读核验。
- 本次没有扩大系统文件夹权限，没有改动 Shadowrocket 已有节点或连接。源码哈希快照：`.build/validation/qr-alignment-20261009/source-snapshot.json`。

## 2026-10-09 — 液态玻璃工作区改版

本次使用冰青视觉资源与原生玻璃操作控件，保留独立 iOS / Mac target。共享工作区提供常驻摘要、可展开字段、宽度自适应的输出选择与即时文本预览。iOS 根视图持有独立会话，解析后自动进入工作区；返回、输出切换与布局变化不重新生成节点身份。辅助功能字号下字段上下排列，操作区与滚动内容分开布局，玻璃按钮不遮挡二维码或正文。iOS 图片分享在原生 popover 中使用 ShareLink 的不可变 PNG 数据表示；Mac 分享菜单仍锚定到所属窗口的原生按钮。保存面板继续使用不可变字节快照。

以下只记录本次实际证据，历史记录不替代改版验收。结果包与 `.build/validation/glass-20261009/` 中的日志保留在本机；截图存入 `Preview/glass-*.png`。

| 检查 | 状态 | 本次证据与边界 |
| --- | --- | --- |
| iOS / Mac Debug 应用及测试编译 | 通过 | 两平台 build-for-testing 包含 Debug 应用编译；最终语义 RTL 与配置正文构建日志为 `.build/validation/glass-20261009/proxy-glass-ios-rtl-test-final-build.log`、`proxy-glass-mac-rtl-final-build.log` |
| Mac 原生启动 | 通过 | `./script/build_and_run.sh --verify` 返回 0，完成构建、启动和进程检查；交付版本再次运行并返回 0，日志 `proxy-glass-delivery-native-launch.log` |
| iOS 共享及会话单元测试 | 通过 | iPhone 17 Pro / iOS 26.5，25 项、0 失败，包含元数据、导航持有的会话、输入失效、JSON / YAML / PNG 不可变快照及结果反馈；`.build/results/Glass-iPhone-Delivery-Final-20261009.xcresult`、`proxy-glass-iphone-delivery-final.log` |
| Mac 共享及会话单元测试 | 通过 | 共享核心及会话 36 项、0 失败，包含独立 PNG 快照载荷回读；`.build/results/Glass-Mac-Units-Final-20261009.xcresult`、`proxy-glass-mac-units-final.log` |
| Mac 已执行的工作区 UI 回归 | 通过 | `.build/results/Glass-Mac-Final-20261009.xcresult` 中 35 单元及 10 UI 通过：取消、复制原文、输入失效、密码、即时 YAML / JSON、快捷键、独立窗口、PNG 实际保存与 Vision 回读、JSON 实际保存及只读失败、分享菜单；窗口用例中止，结果包整体仍为失败，不能写成完整套件通过 |
| Mac 最小 / 宽窗口及侧栏恢复 | 通过 | 最终窗口尺寸用例通过，实际拖动至最小窗口与宽窗口，检查预览、格式切换、导出控件范围以及 UDP、密码、节点保留；`.build/results/Glass-Mac-WindowYAML-Final-20261009.xcresult`、`proxy-glass-mac-window-yaml-final.log`。最小窗口截图无遮挡，宽窗口附件被系统提示遮挡，后者不作为无干扰视觉通过 |
| Mac 默认窗口与图片 / 链接分享面板 | 通过 | 重新启动最终原生 app 后通过 CUA 实际检查默认深色窗口，二维码完整，摘要收起且三种全称切换可见；图片与链接分别实际呈现锚定到当前按钮的 `ShareSheet.Popover`，关闭后节点保留。没有发送给联系人；交互截图在本次工具记录中 |
| Mac 宽窗口无干扰视觉复核 | 被环境阻塞 | XCTest Runner 的“访问文稿文件夹”提示遮挡宽窗口附件；未授予额外文稿权限。宽度 / 状态断言已通过，干净宽窗口截图仍待补齐 |
| Mac YAML 实际保存 | 通过 | 最终独立用例使用系统面板写入临时目录，实际 `clash.yaml` 与当前 UDP 预览的原始 UTF-8 字节一致；与窗口用例合计 2 项 UI、0 失败，`Glass-Mac-WindowYAML-Final-20261009.xcresult` |
| iPhone 窄屏返回、复制、深色分享及最大字号 | 通过 | `Glass-iPhone-Delivery-Final-20261009.xcresult` 中 3 UI、0 失败：返回后 JSON、UDP、密码状态保留，主动粘贴核对复制原文，输入修改使旧结果失效；原生图片分享面板实际打开；最大字号短标签菜单和导出 / 复制可达。最终视口二维码在 `Glass-iPhone-Pixels-Final-20261009.xcresult` 再通过首屏水平 / 垂直范围断言与原生深色分享，共 2 项 UI、0 失败 |
| Duo 自动导航与即时输出 | 通过 | `.build/results/Glass-Duo-UI-20261009.xcresult`，1 UI 通过，验证三格式入口、共用 UDP、稳定 UUID 与 JSON 保存取消；最终原生分享与操作区布局另行重验 |
| Duo 辅助功能字号详情与会话交互 | 通过 | `proxy-glass-duo-verified-test.log` 记录最大字号展开密码、返回保留 / 原文复制、原生深色分享、三格式 UDP / UUID / 取消等 6 项 UI 通过；该运行随后被系统同名文件确认页阻塞，未完整生成结果包，不将其记为整套通过 |
| iPad 宽分栏、最大字号及实时文本 | 通过 | `Glass-iPad-Verified-20261009.xcresult` 中 2 UI、0 失败，检查 UDP、稳定 UUID、三格式切换和取消；最后修正菜单显示短标签后 `Glass-iPad-Menu-Final-20261009.xcresult` 再通过 1 项最大字号用例，截图确认 JSON 标签完整可见 |
| iOS PNG / JSON / YAML 实际保存与回读 | 通过 | iPad / iOS 26.5，`Glass-iPad-Save-Final-20261009.xcresult` 中 3 UI、0 失败；File Provider Storage 实际 JSON 821 bytes、YAML 426 bytes 与本次预览原始附件逐字节一致，PNG 14271 bytes / 670×670 经独立 Vision CPU 解码后与启用 UDP 的完整导入链接一致；`ios-file-readback.json`、`ios-png-readback.json` |
| Duo / iOS 27.1 实际保存回归 | 被环境阻塞 | 已中止导出留下独立文件服务的同名确认 / 进行中状态，重启同一设备后仍未完成该环境的最终保存回读；没有替换已有文件，也不引用 iPad 成功结果认定 Duo 保存通过 |
| 最终二维码完整显示与像素截图 | 通过 | `Glass-iPhone-Pixels-Final-20261009.xcresult` 中首屏范围断言通过；`Glass-Duo-Pixels-RTL-Final-20261009.xcresult` 中二维码像素场景通过，并实际检查白色静区和完整二维码，最终截图内的缩小二维码亦由独立 Vision 解出 UDP 关闭的正确链接，见 `duo-display-qr-readback.json`。Duo 前轮 `nodeDetails.frame` 查询停滞，已中止，未认定其几何断言通过 |
| iOS 强制语义 RTL | 通过 | `Glass-Duo-SemanticRTL-Final-20261009.xcresult` 中 1 UI、0 失败，实际截图确认标题、摘要、UDP 控件、格式顺序及操作组镜像，UDP 为 1 且 JSON 原文可读；配置正文保持协议定义的 LTR。首轮阿拉伯语参数回退中文 LTR，未作为 RTL 证据；最终使用不写入系统偏好的 Debug `-ProxyStudioRTL` 参数 |
| Mac RTL、VoiceOver 实际朗读、减少透明度及减少动态效果系统检查 | 未执行 | 源码保留语义布局与系统材质，展开动画读取减少动态效果；不以源码审查代替实际系统验收 |
| Duo 展开、书本式、支架、iPad 窄窗、最低系统及第三方导入 | 未执行 | 不沿用旧截图或旧客户端验证作为改版通过证据 |

回归中发现并修正了端口被本地化显示为 `1,080`、最大字号滚动手势落在操作区、返回按钮位于 Duo 侧边而非 navigation bar、输入控件被 UIKit 分类为不同类型、中文输入法可能将测试路径 `/` 转为 `、`、以及窗口标题栏拖动被系统提示遮挡的问题。测试路径改用粘贴并逐字断言，系统保存取消兼容下拉关闭，截图与导出均只使用虚构示例节点。

部分中止的 XCTest 会话停留在诊断收集，随后清理了本次测试进程。未完整生成 Info.plist 的结果目录不作为有效结果包；相应命令与诊断日志保留在 `.build/validation/glass-20261009/`。原生图片分享的旧 UIKit 呈现路径未完成面板显示，最终采用 popover 内的系统 ShareLink，并在 iPhone 与 Duo 实际打开原生分享面板。

上述初版按视口及摘要高度缩放二维码，只影响屏幕展示、不重新编码 PNG。该策略随后被发现会随滚动改变尺寸，已由下方“二维码滚动尺寸修复”替代；旧首屏范围断言与静态回读不覆盖滚动稳定性。独立操作区仍占用真实布局空间，图片相关操作由二维码生成状态单独决定。

最终截图：`Preview/glass-iphone-qr.png`、`glass-iphone-dark-share.png`、`glass-iphone-json-accessibility.png`、`glass-duo-qr.png`、`glass-duo-rtl-json.png`、`glass-ipad-json.png`、`glass-ipad-json-accessibility.png`、`glass-mac-minimum-yaml.png`、`glass-mac-minimum-json.png`。窗口遮挡及未完成项仍按表中边界记录；不以多轮通过项合并成某个完整测试包通过。


## 2026-10-09 — 二维码滚动尺寸修复

用户在 Duo 紧凑视口观察到滚动后二维码变大。此前 iOS 工作区将可用视口高度减去摘要高度作为二维码上限；导航栏随滚动改变可用高度时，图片上限也随之变化。现移除高度测量，以内容宽度约束二维码，最大 320 pt。竖向空间不足时滚动查看，滚动和详情展开不参与图片尺寸计算；PNG 原始像素、编码与导出路径不变。

新增 `testQRCodeSizeRemainsStableWhileScrolling`，验证内容实际上移、二维码宽高不变、底部保存操作可达，再反向滚动验证尺寸仍一致。完整可见性用例改为滚动后检查，短视口不再要求摘要与完整二维码同时挤入首屏。

| 检查 | 状态 | 本次证据与边界 |
| --- | --- | --- |
| iOS Debug 应用及 UI 测试编译 | 通过 | `build-for-testing` 返回 0，`proxy-qr-scroll-build.log` 为 `TEST BUILD SUCCEEDED` |
| Duo 上下滚动尺寸回归与截图回读 | 通过 | iPhone Duo / iOS 27.1，`QR-Scroll-Duo-20261009.xcresult` 中 1 项 UI、0 失败；实际向上 / 向下滚动，宽高差不超过 1 pt，保存按钮可达。独立 Vision 从滚动后截图解出完整示例链接，`duo-readback.json` 为 `payloadMatchesExample: true` |
| iPhone 上下滚动及完整可见性 | 通过 | iPhone 17 Pro / iOS 26.5，`QR-Scroll-iPhone-20261009.xcresult` 中 2 项 UI、0 失败；向上 / 向下滚动宽高不变，滚动后图片四边均在可视范围内；独立 Vision 回读完整示例链接通过，`iphone-readback.json` 为 `payloadMatchesExample: true` |
| PNG 重新保存、Mac / iPad / RTL / 大字体 | 未执行 | 本次为 iOS 展示尺寸修复，未以旧结果代替本轮执行 |

本轮日志与附件保留在 `.build/validation/qr-scroll-20261009/`，Duo 新截图为 `Preview/glass-duo-qr-before-scroll.png`（初始位置）与 `Preview/glass-duo-qr.png`（滚动后完整二维码）；`Preview/glass-iphone-qr.png` 亦替换为本轮 iPhone 滚动后截图。`git diff --check` 通过。

## 2026-10-09 — Shadowrocket URL 导出

两端新增第四种输出“Shadowrocket URL”，提供即时链接预览、复制原文和 `.url` 导出；Mac 支持 `⌘4`、显示 / 导出菜单以及文本输出的 Escape 返回二维码。格式选择沿用完整标签、简写与菜单的宽度自适应行为。URL、二维码、JSON、YAML 共用 UDP，切换格式不刷新节点身份与创建时间。URL 文件使用当前分享链接的 UTF-8 字节，不添加 BOM、末尾换行或其他包装；默认名为 `shadowrocket.url`，系统面板打开前捕获不可变字节快照。

本轮证据位于 `.build/validation/url-export-20261009/`。附件只在本地内存中进行格式核对；报告不保存原始节点或凭据，测试与截图仅使用虚构示例。

| 检查 | 状态 | 本次证据与边界 |
| --- | --- | --- |
| 用户 `.url` 样本字节核对 | 通过 | 当前 `ProxyNode.parse` 解析后再由 `shadowrocketLink(udpEnabled:)` 生成，与附件 116 字节完全一致；无 BOM、无换行。脱敏报告 `sample-byte-check.json` |
| iOS 应用与测试目标编译 | 通过 | `ios-build.log` 与模拟器重启后的 `ios-restart-build.log` 均为 `TEST BUILD SUCCEEDED`，退出 0；最低部署版本保持 iOS 26.0 |
| Mac 应用与测试目标编译及实际启动 | 通过 | `mac-build.log` 为 `TEST BUILD SUCCEEDED`；最终 `script/build_and_run.sh --verify` 的 `mac-run.log` 为 `BUILD SUCCEEDED`，脚本退出 0 并确认进程启动；最低部署版本保持 macOS 26.0 |
| Mac 核心、会话及选定 UI 回归 | 通过 | `Mac-URL.xcresult`、`mac-test.log`、`mac-summary.json`：38 单元 + 7 UI，共 45 项、0 失败；含 URL 往返、快照、无节点禁用、窗口隔离、原文复制、UDP 同步、菜单 / ⌘4、Escape、四格式取消、最小窗口和现有 PNG / YAML / JSON 保存回归 |
| Mac URL 实际保存与扩展名 | 通过 | `testURLActualSaveAndReadOnlyFailure` 通过原生系统面板写入 `shadowrocket.url`，119 字节与保存前预览原始字节一致；目录断言确认未生成 `.txt`。`Mac-URL-预览原始字节` 附件位于 `mac-attachments/` |
| Mac URL 实际写入失败 | 通过 | 同一 UI 用例在只读目录收到“保存失败：”，确认没有产生文件，预览和节点仍保留；权限仅设置在本轮创建的临时测试目录，并在结束时恢复 |
| Mac 最终窗口及四输出布局复测 | 通过 | 补齐输入法浮层清理后，`Mac-URL-Window-Verified.xcresult`、`mac-window-verified.log`、`mac-window-verified-summary.json`：1 项 UI、0 失败；实际缩小 / 扩大窗口，确认最小窗口的 URL 预览、导出和选择器水平范围在窗口内，操作可达，UDP 与密码状态保留，侧栏隐藏 / 恢复不清空输入；最终截图已检查 |
| iOS 核心与会话测试 | 通过 | 重启后的 iPhone Duo / iOS 27.1，`duo-restart-test.log`：27 项、0 失败；含 IPv6、免认证、中文 / 特殊凭据、UDP、URL 字节与独立 QR 回读一致性、不可变快照及结果处理 |
| iOS URL 实际保存与文件回读 | 通过 | Duo 两次原生保存均完成；File Provider Storage 中两个实际 `.url` 文件均为 119 字节，与各轮保存前预览附件逐字节一致，没有 BOM 或换行；`ios-url-file-readback.json`、`ios-url-file-readback-final.json`。文件名在系统面板中主动修改，扩展名仍为 `.url` |
| Duo URL 复制、返回保留、取消与最大字号 | 通过 | `Duo-URL-Restart.xcresult` 中 URL 的 4 项 UI 均通过；原始复制后主动粘贴核对、节点元数据稳定、UDP 同步、取消保留及最大辅助功能字号操作可达。该批次整体为 33 passed / 1 failed，不能记为完整套件通过 |
| Duo 最终 PNG / URL 保存与 URL 取消复测 | 通过 | 改进 UDP 测试点击方式后，`Duo-URL-Final.xcresult`、`duo-final-test.log`、`duo-final-summary.json`：3 项 UI、0 失败；实际 URL 再次回读与本次快照一致。初轮 PNG 点击后仍为关闭的失败记录保留 |
| iPad 分栏与最大辅助功能字号 | 通过 | iPad Pro 13-inch (M5) / iOS 26.5，`iPad-URL.xcresult`、`ipad-test.log`、`ipad-summary.json`：2 项 UI、0 失败；四输出切换、URL / JSON / YAML 共享 UDP、保存取消、字号下菜单与导出 / 复制可达；截图已检查 |
| 第三方 Shadowrocket `.url` 实际导入 | 未执行 | 本轮未操作目标客户端节点或连接；样本字节一致不等同于客户端实际导入通过 |

首次 Duo 测试在开始 XCTest 前长时间等待，保留 `Duo-URL-Units.xcresult` 和 `duo-units.log` 的 `TEST INTERRUPTED` 记录；iPhone 17 Pro 的后续尝试也在构建 / 测试启动阶段停止，记录为未执行。按用户要求关闭本任务的模拟器并重启 Duo 后，重新构建再运行测试；没有清除模拟器数据，也没有修改系统隐私权限。上述中断不计入通过测试数。

Duo 重启后的批次完成 27 单元及 7 UI，其中 6 UI 通过、PNG 1 项失败：测试按标签行的固定比例点击 UDP 后，开关仍显示 `0`。现改为先点击开关本身，仅在当前值仍关闭时尝试控件一侧，仍断言确实启用；最终 PNG 实际保存和两项 URL 复测全部通过。初轮失败结果包及日志保留。Xcode 在失败后启动 `simctl diagnose --timeout=600`，结果收尾长时间等待；停止该次诊断后成功导出原始结果、截图和预览字节。后续复测关闭自动诊断采集，仍保留全部断言、截图和 xcresult。

最终 Mac 的 UDP 说明文字补充 URL 后，单元测试再次 38 项通过；窗口复测先遇到脚本与测试应用两个同名进程并存，关闭额外实例后仍被系统 `InputSource` 浮层的辅助功能快照中断。`Mac-URL-Final.xcresult` / `mac-final-test.log` 保留中断记录，`Mac-URL-Window-Single.xcresult` / `mac-window-single.log` 保留 120 秒执行超时的失败。测试准备步骤增加第二次 Escape：首次可能由文本输出切回二维码，第二次再交给输入法关闭浮层，随后恢复输出。最终 `Mac-URL-Window-Verified.xcresult` 中窗口用例通过，1 项、0 失败，不覆盖上述历史记录。

本轮截图为 `Preview/shadowrocket-url-duo.png`、`Preview/shadowrocket-url-ipad.png` 和 `Preview/shadowrocket-url-mac.png`，来自实际 XCTest 附件；使用虚构示例节点，URL 视觉换行不改变复制或保存字节。

本轮最终 `git diff --check` 通过；源文件哈希快照为 `source-snapshot.json`。未将真实附件、诊断或构建产物纳入仓库。
