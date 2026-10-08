# Repository Guidelines

## 工程结构与模块职责

`ProxyStudio.xcodeproj` 提供共享方案 `ProxyStudio`。应用源码位于 `ProxyStudio/`：`Core/` 负责 SOCKS 解析与 Clash YAML 生成；`Services/` 负责二维码、文件与分享；`Views/` 存放 SwiftUI 界面；`Assets.xcassets/` 存放颜色和三种外观图标。单元测试与 UI 测试分别位于 `ProxyStudioTests/`、`ProxyStudioUITests/`。设计原稿在 `Design/`，截图在 `Preview/`。开发前阅读 `README.md`、`REQUIREMENTS.md` 和 `VALIDATION.md`。

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
