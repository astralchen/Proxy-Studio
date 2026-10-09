# 验证记录

验证时间：2026-10-08。本文按增量保留历史证据；当前双平台交付结果见“原生 macOS 交付验证”与“本次 iOS 回归”。以下首张表是早期 iOS 验证记录。完整测试套件在 YAML 预览换行修正前通过；核心解析、二维码与导出逻辑此后未变。换行修正后的最终源码已通过 iOS 26.5 和 27.1 SDK 编译；最终界面回归在模拟器启动与事件监控阶段被环境阻塞。

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
