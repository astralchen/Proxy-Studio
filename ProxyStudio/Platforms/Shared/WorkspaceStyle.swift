import SwiftUI

/// 两平台共用的冰青视觉语义；内容底色不依赖玻璃采样。
enum WorkspaceStyle {
    static let background = Color("WorkspaceBackground")
    static let surface = Color("WorkspaceSurface")
    static let accent = Color("AccentColor")
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

/// 按实际控件固有宽度选择完整标签、短标签或菜单。
struct OutputPicker: View {
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

    private func picker(compact: Bool) -> some View {
        Picker("输出格式", selection: $selection) {
            ForEach(OutputFormat.allCases) { output in
                Text(compact ? output.compactTitle : output.rawValue)
                    .accessibilityLabel(output.rawValue).tag(output)
            }
        }
        .pickerStyle(.segmented).labelsHidden()
    }

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
    let node: ProxyNode
    @Binding var isExpanded: Bool
    @Binding var revealPassword: Bool
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
            Text("同时用于二维码、JSON 和 YAML；请确认服务端支持。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkspaceStyle.surface, in: RoundedRectangle(cornerRadius: 24))
    }

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

    private func stackedField(_ title: String, text: String, identifier: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            value(text).accessibilityIdentifier(identifier)
        }
    }

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

    private func value(_ text: String) -> some View {
        Text(text).textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 当前格式的即时预览。视觉换行不改变底层文本或导出字节。
struct OutputPreview: View {
    let output: OutputFormat
    let nodeName: String
    let image: QRCodeImage?
    let yaml: String
    let json: String?
    /// 显示宽度上限；窄容器按内容宽度缩小，滚动位置不影响尺寸，原始 PNG 像素不变。
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
                                           description: Text("仍可分享导入链接或导出 JSON、YAML。"))
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
            }
            Label("二维码和配置包含账号信息，请妥善保存。", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
