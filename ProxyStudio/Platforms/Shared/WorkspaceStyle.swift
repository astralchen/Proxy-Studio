import SwiftUI

/// 两平台共用的冰青视觉语义；内容底色不依赖玻璃采样。
enum WorkspaceStyle {
    /// 工作区整体底色，随资源中的浅色与深色外观切换。
    static let background = Color("WorkspaceBackground")
    /// 输入卡片、节点摘要及文本预览的稳定内容底色。
    static let surface = Color("WorkspaceSurface")
    /// 应用控件的主题色，以及说明区域渐变使用的颜色。
    static let accent = Color("AccentColor")
    /// 图标和次要操作文字使用的强调色。
    static let foregroundAccent = Color("WorkspaceAccent")
}

/// 简短的导入说明，渐变只出现在说明区域。
struct ImportIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 30)).foregroundStyle(WorkspaceStyle.foregroundAccent)
                .accessibilityHidden(true)
            Text("一条链接，多种导出。").font(.title2.bold())
            Text("粘贴 SOCKS 链接，在本机生成二维码与配置。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [WorkspaceStyle.accent.opacity(0.12), .clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

/// 无节点时提示用户主动导入；不读取剪贴板。
struct WorkspaceEmptyView: View {
    var body: some View {
        ContentUnavailableView("准备好你的下一条连接", systemImage: "qrcode",
                               description: Text("在导入区粘贴链接并解析，即可预览和导出。"))
            .background {
                LinearGradient(colors: [WorkspaceStyle.accent.opacity(0.06), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
    }
}

/// 按可用宽度选择完整标签、短标签或菜单的输出格式控件。
///
/// 辅助功能字号直接使用菜单；各布局编辑同一绑定，并保留格式的完整辅助功能名称。
struct OutputPicker: View {
    /// 当前格式，由所属窗口会话持有；切换布局不会创建新的选择状态。
    @Binding var selection: OutputFormat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize { menu }
            else {
                ViewThatFits(in: .horizontal) {
                    picker(compact: false).fixedSize(horizontal: true, vertical: false)
                    picker(compact: true).fixedSize(horizontal: true, vertical: false)
                    menu
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("outputPicker")
    }

    /// 创建分段选择器，使用固有宽度参与 `ViewThatFits` 的布局选择。
    /// - Parameter compact: 为 `true` 时使用简写标题，否则使用完整标题。
    /// - Returns: 与 `selection` 绑定的分段选择器。
    private func picker(compact: Bool) -> some View {
        Picker("输出格式", selection: $selection) {
            ForEach(OutputFormat.allCases) { output in
                Text(compact ? output.compactTitle : output.rawValue)
                    .accessibilityLabel(output.rawValue).tag(output)
            }
        }
        .pickerStyle(.segmented).labelsHidden()
    }

    /// 窄容器或辅助功能字号下的菜单，当前值仍以完整名称供辅助功能读取。
    private var menu: some View {
        Menu {
            Picker("输出格式", selection: $selection) {
                ForEach(OutputFormat.allCases) { output in
                    Text(output.rawValue).tag(output)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Text(selection.compactTitle).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.up.chevron.down").font(.caption).accessibilityHidden(true)
            }
        }
        .buttonStyle(.glass)
        .accessibilityLabel("输出格式")
        .accessibilityValue(selection.rawValue)
    }
}

/// 常驻摘要与可展开的完整字段。显示状态由窗口会话持有。
struct NodeSummary: View {
    // MARK: - 节点与窗口绑定

    /// 当前节点；只读取字段，UDP 导出选项由独立绑定控制。
    let node: ProxyNode
    /// 是否展开完整字段；初始值由窗口会话决定。
    @Binding var isExpanded: Bool
    /// 是否显示原始密码；收起详情不改变此选项。
    @Binding var revealPassword: Bool
    /// 四种输出共用的 UDP 选项，不表示已检查服务器能力。
    @Binding var udpEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(node.name).font(.title2.bold()).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(node.host) · \(String(node.port))")
                .font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                Label(isExpanded ? "收起节点详情" : "节点详情",
                      systemImage: isExpanded ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.plain).foregroundStyle(WorkspaceStyle.foregroundAccent)
            .accessibilityValue(isExpanded ? "已展开" : "已收起")
            .accessibilityIdentifier("nodeDisclosure")
            if isExpanded {
                if dynamicTypeSize.isAccessibilitySize { stackedFields }
                else { fields }
            }
            Divider()
            Toggle("启用 UDP", isOn: $udpEnabled)
                .toggleStyle(.switch).accessibilityIdentifier("udpToggle")
            Text("同时用于二维码、URL、JSON 和 YAML；请确认服务端支持。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkspaceStyle.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - 字段布局

    /// 辅助功能字号使用上下排列，让长值获得完整可用宽度。
    private var stackedFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            stackedField("协议", text: "SOCKS5", identifier: "protocolRow")
            stackedField("服务器", text: node.host)
            stackedField("端口", text: String(node.port))
            if let username = node.username, let password = node.password {
                stackedField("账号", text: username)
                VStack(alignment: .leading, spacing: 8) {
                    Text("密码").font(.caption).foregroundStyle(.secondary)
                    value(revealPassword ? password : "••••••••")
                        .accessibilityLabel("密码")
                        .accessibilityValue(revealPassword ? password : "••••••••")
                        .accessibilityIdentifier("nodePassword")
                    Button(revealPassword ? "隐藏密码" : "显示密码",
                           systemImage: revealPassword ? "eye.slash" : "eye") { revealPassword.toggle() }
                        .accessibilityIdentifier("togglePassword")
                }
            } else { stackedField("认证", text: "无需账号") }
        }
    }

    /// 创建标签在上、可选择值在下的字段，供辅助功能字号布局使用。
    /// - Parameters:
    ///   - title: 字段名称。
    ///   - text: 原始显示值。
    ///   - identifier: 值视图的辅助功能标识，默认为空字符串。
    /// - Returns: 按可用宽度换行的字段视图。
    private func stackedField(_ title: String, text: String, identifier: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            value(text).accessibilityIdentifier(identifier)
        }
    }

    /// 标准字号的共享标签列和值列；首行基线对齐，长值按列宽换行。
    private var fields: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow(alignment: .firstTextBaseline) {
                Text("协议").gridColumnAlignment(.trailing)
                value("SOCKS5").accessibilityIdentifier("protocolRow")
            }
            GridRow(alignment: .firstTextBaseline) { Text("服务器"); value(node.host) }
            GridRow(alignment: .firstTextBaseline) { Text("端口"); value(String(node.port)) }
            if let username = node.username, let password = node.password {
                GridRow(alignment: .firstTextBaseline) { Text("账号"); value(username) }
                GridRow(alignment: .firstTextBaseline) {
                    Text("密码")
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        value(revealPassword ? password : "••••••••")
                            .accessibilityLabel("密码")
                            .accessibilityValue(revealPassword ? password : "••••••••")
                            .accessibilityIdentifier("nodePassword")
                        Button(revealPassword ? "隐藏密码" : "显示密码",
                               systemImage: revealPassword ? "eye.slash" : "eye") { revealPassword.toggle() }
                            .labelStyle(.iconOnly).fixedSize()
                            .accessibilityIdentifier("togglePassword")
                    }
                }
            } else {
                GridRow(alignment: .firstTextBaseline) { Text("认证"); value("无需账号") }
            }
        }
        .font(.subheadline)
    }

    /// 创建可选择且保留完整高度的值文本。
    /// - Parameter text: 要显示的原始文本，不插入额外换行字符。
    /// - Returns: 填充值列宽度、沿语义起始边对齐的文本。
    private func value(_ text: String) -> some View {
        Text(text).textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 当前格式的即时预览。视觉换行不改变底层文本或导出字节。
struct OutputPreview: View {
    // MARK: - 预览输入

    /// 当前要呈现的格式；本视图不修改窗口选择。
    let output: OutputFormat
    /// 用于二维码辅助功能说明的节点名称。
    let nodeName: String
    /// 已渲染的共享二维码像素；为 `nil` 时在二维码格式下显示失败说明。
    let image: QRCodeImage?
    /// 原始 Clash 配置，由调用方生成。
    let yaml: String
    /// 原始 Shadowrocket JSON；为 `nil` 时在 JSON 格式下显示失败说明。
    let json: String?
    /// 当前规范化分享链接，与二维码载荷一致。
    let url: String
    /// 二维码显示宽度上限，默认 320 pt；窄容器按内容宽度缩小。
    ///
    /// 滚动位置和可用高度不参与尺寸计算，原始 PNG 像素不变。
    var qrMaximumDimension: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(output.rawValue).font(.headline)
            switch output {
            case .qr:
                if let image {
                    Image(image.cgImage, scale: 1, label: Text("\(nodeName) 的 Shadowrocket 导入二维码"))
                        .interpolation(.none).resizable().scaledToFit()
                        .frame(maxWidth: qrMaximumDimension)
                        .accessibilityIdentifier("qrImage")
                        .frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView("二维码生成失败", systemImage: "qrcode",
                                           description: Text("仍可分享导入链接或导出 URL、JSON、YAML。"))
                }
                Text("在 Shadowrocket 中扫描二维码，或识别保存的图片。")
                    .font(.subheadline).foregroundStyle(.secondary)
            case .yaml:
                Text("配置包含“代理选择”与 DIRECT，进入 Clash 的流量按所选策略转发。")
                    .font(.caption).foregroundStyle(.secondary)
                textPreview(yaml, identifier: "yamlPreview")
            case .json:
                Text("使用 Shadowrocket 单节点格式，请确认目标客户端的导入入口支持。")
                    .font(.caption).foregroundStyle(.secondary)
                if let json { textPreview(json, identifier: "jsonPreview") }
                else { ContentUnavailableView("无法生成 JSON 文件。", systemImage: "doc.badge.ellipsis") }
            case .url:
                Text("将当前导入链接保存为 .url 文件，内容与二维码一致。")
                    .font(.caption).foregroundStyle(.secondary)
                textPreview(url, identifier: "urlPreview")
            }
            Label("二维码和配置包含账号信息，请妥善保存。", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 显示可选择的等宽正文，并通过辅助功能提供未添加视觉换行的完整文本。
    /// - Parameters:
    ///   - text: 调用方生成的原始链接或配置。
    ///   - identifier: 当前格式预览的辅助功能标识。
    /// - Returns: 按可用宽度换行、保持协议正文从左到右阅读的文本视图。
    private func textPreview(_ text: String, identifier: String) -> some View {
        Text(text).font(.system(.callout, design: .monospaced))
            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(WorkspaceStyle.surface, in: RoundedRectangle(cornerRadius: 16))
            // 配置采用协议约定的从左到右语法，界面 RTL 不反转正文缩进或阅读方向。
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(output.rawValue + " 配置")
            .accessibilityValue(text).accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier(identifier)
    }
}
