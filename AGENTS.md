# Repository Guidelines

## 工程结构与模块职责

`ProxyStudio.xcodeproj` 提供独立 app target 与同名共享 Scheme：`ProxyStudio`（iOS）、`ProxyStudioMac`（原生 macOS）。应用源码位于 `ProxyStudio/`：`Core/` 负责 SOCKS 解析与 Clash YAML 生成；`Services/` 负责平台无关的二维码与文件文档；`Platforms/iOS/`、`Platforms/macOS/` 分别存放平台入口、界面和图片分享适配，两平台各自的窗口会话在所属目录的 `Stores/ProxySession.swift`，通用工作区视图在 `Platforms/Shared/`；`Platforms/Resources/Assets.xcassets/` 存放颜色及图标。共享单元测试在 `ProxyStudioTests/`，iOS UI 测试在 `ProxyStudioUITests/`，Mac 专属测试在 `ProxyStudioMacTests/`、`ProxyStudioMacUITests/`。通过同步目录的 target membership 选择源码，平台专属文件不添加 `Mac` 类型前缀或 `#if os(...)` 包装。设计原稿在 `Design/`，截图在 `Preview/`。开发前阅读 `README.md`、`REQUIREMENTS.md` 和 `VALIDATION.md`。

## 构建、测试与本地运行

在本文件所在目录执行以下命令。Duo 开发流程使用 Xcode 27.1 或更新版本，最低部署版本保持 iOS 26.0；工程仅依赖 Apple 系统框架。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudio \
  -destination 'platform=iOS Simulator,name=iPhone Duo' test
```

先设置 Xcode 路径，再执行构建或测试命令：`build` 无需真机签名，`test` 运行两个测试目标。按本机环境替换模拟器名称。在 Xcode 中按 `⌘R` 运行；真机调试需配置自己的 Team。

## macOS 开发目标与适配约定

原生 Mac 使用独立 `ProxyStudioMac` target 与 Scheme，最低支持 macOS 26.0，iOS target 最低版本保持 26.0。平台源码按目录隔离，共享核心逻辑与资源；验证边界以 `VALIDATION.md` 的实际证据为准。

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

Mac 测试使用本地临时签名，不改动工程的 Team；在 Xcode 中选择 `ProxyStudioMac` / `My Mac` 可运行。运行脚本会重启旧 Mac 进程，其内存会话不保留。

- 沿用 Xcode 27.1 或更新版本，仅依赖 Apple 系统框架；复用 SOCKS 解析和 YAML 生成逻辑，将平台专属图片、界面及分享 API 隔离在服务或视图适配层。
- 按容器可用尺寸布局分栏窗口和可滚动内容，不通过设备型号判断。窗口与分栏调整保持会话状态，每个窗口拥有独立的输入、节点和导出选项。
- 支持标准文本编辑与键盘操作、可选择且按可用宽度换行的 YAML 预览，以及 Mac 原生系统分享和保存面板。
- 验证覆盖原生构建与启动、共享单元测试、PNG 回读、导入与预览、窗口调整、多窗口、键盘、浅色与深色外观、图片及链接分享，以及 PNG/YAML 保存成功、失败和取消路径。
- macOS 未完成验证的项目在 `VALIDATION.md` 中标为“未执行”；只有实际工具或系统限制才标为“被环境阻塞”，不引用旧 iOS 结果作为 Mac 通过证据。平台功能变化时同步更新 README、REQUIREMENTS 与 VALIDATION，所有通过结论附实际验证证据。

## 编码风格与命名约定

使用四空格缩进，类型采用 `UpperCamelCase`，成员采用 `lowerCamelCase`；文件名与主要类型一致。解析和序列化逻辑放在视图之外。中文注释遵循 UIKit SDK 风格：用 `///` 描述职责、默认值、可空语义、参数、返回值与错误；用 `// MARK: -` 分组，普通 `//` 解释实现原因。当前未配置格式化或静态检查工具。

## 测试要求

使用 XCTest，测试方法以 `test` 开头并描述验证行为。修改相关逻辑时，覆盖解析边界、凭据往返转换、YAML 转义和二维码回读；界面变更检查导入、预览、导出及辅助功能字号。当前无覆盖率百分比门槛。在 `VALIDATION.md` 中区分通过、失败、未执行和环境阻塞；发送旋转请求不代表已验证横屏布局。

## 提交与合并请求

当前交付目录没有可供归纳的 Git 历史，后续统一遵循以下约定：

- Git 提交标题与正文必须使用简体中文；API、类型名、文件路径和技术缩写保留原文。
- 标题采用“动作 + 对象 + 具体变化”，保持单行、简短且可独立理解。示例：`修复 IPv6 地址导出时的方括号处理`、`补齐应用图标的深色与着色版本`、`补充链接解析接口的中文文档注释`。避免“更新代码”“优化问题”等含糊描述。
- 简单变更仅写标题；复杂变更在空行后说明修改原因、关键行为变化、验证结果及必要限制。只记录实际完成的工作，不把未执行或被环境阻塞的测试写成通过。
- 每次提交聚焦一个主题。提交前检查暂存区差异，仅纳入本次任务相关文件，保留无关改动；不要提交真实凭据或临时构建产物。
- PR 标题和说明同样使用简体中文，说明问题、修改后的行为、验证命令与结果以及尚存限制；有关联问题时附上链接，视觉变更附上截图。

## 凭据安全与自适应布局

示例、测试、日志和截图仅使用虚构凭据。二维码与 YAML 包含可恢复的账号信息，不得提交真实凭据。保持本地解析；按容器可用尺寸布局，遵循安全区域和动态字体，避免依赖设备型号判断。
