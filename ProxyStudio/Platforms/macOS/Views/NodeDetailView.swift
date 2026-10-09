import SwiftUI

/// 显示节点摘要及二维码、即时 YAML 两种输出。
struct NodeDetailView: View {
    @Bindable var session: ProxySession
    let node: ProxyNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary
                Divider()
                Picker("输出格式", selection: $session.output) {
                    ForEach(ProxySession.Output.allCases) { output in
                        Text(output.rawValue).tag(output)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!session.canUseOutput)
                .accessibilityIdentifier("outputPicker")
                if session.output == .qr {
                    qrOutput
                } else {
                    yamlOutput
                }
            }
            .padding(28)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("节点工作区")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(node.name).font(.title2.bold())
                    .textSelection(.enabled)
                Spacer(minLength: 12)
                Text("SOCKS5").font(.caption.bold()).foregroundStyle(.teal)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.teal.opacity(0.10), in: Capsule())
                    .accessibilityIdentifier("protocolRow")
            }
            .accessibilityElement(children: .contain)
            // 所有字段共用列宽，避免每行 LabeledContent 分别居中造成错位。
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow(alignment: .firstTextBaseline) {
                    Text("服务器").gridColumnAlignment(.trailing)
                    summaryValue(node.host)
                }
                GridRow(alignment: .firstTextBaseline) {
                    Text("端口")
                    summaryValue(String(node.port))
                }
                if let username = node.username, let password = node.password {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("账号")
                        summaryValue(username)
                    }
                    GridRow(alignment: .firstTextBaseline) {
                        Text("密码")
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(session.revealPassword ? password : "••••••••")
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("密码")
                                .accessibilityValue(session.revealPassword ? password : "••••••••")
                                .accessibilityIdentifier("nodePassword")
                            Button(session.revealPassword ? "隐藏密码" : "显示密码",
                                   systemImage: session.revealPassword ? "eye.slash" : "eye") {
                                session.revealPassword.toggle()
                            }
                            .labelStyle(.iconOnly)
                            .fixedSize()
                            .disabled(!session.canUseOutput)
                            .accessibilityIdentifier("togglePassword")
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .contain)
                    }
                    .accessibilityElement(children: .contain)
                } else {
                    GridRow(alignment: .firstTextBaseline) {
                        Text("认证")
                        summaryValue("无需账号")
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    /// 值列按可用宽度换行，所有行保持相同的起始位置。
    private func summaryValue(_ value: String) -> some View {
        Text(value)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var qrOutput: some View {
        VStack(spacing: 20) {
            if let image = session.qrImage {
                Image(image.cgImage, scale: 1, label: Text("\(node.name) 的 Shadowrocket 导入二维码"))
                    .interpolation(.none).resizable().scaledToFit()
                    .frame(maxWidth: 320)
                    .accessibilityLabel("\(node.name) 的 Shadowrocket 导入二维码")
                    .accessibilityIdentifier("qrImage")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { imageActions(image) }
                    VStack(spacing: 12) { imageActions(image) }
                }
            } else {
                ContentUnavailableView("二维码生成失败", systemImage: "qrcode",
                                       description: Text("链接可能超过二维码容量，仍可分享链接或导出 YAML。"))
            }
            ShareLink(item: node.shareLink) {
                Label("分享导入链接", systemImage: "link")
            }
            .disabled(!session.canUseOutput)
            .accessibilityIdentifier("shareLink")
            Text("在 Shadowrocket 中扫描二维码，或识别保存的图片。\n二维码包含节点账号和密码。")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func imageActions(_ image: QRCodeImage) -> some View {
        Button("保存 PNG…", systemImage: "square.and.arrow.down") { session.exportPNG() }
            .disabled(!session.canUseOutput)
            .accessibilityIdentifier("exportPNG")
        ImageShareButton(image: image, isEnabled: session.canUseOutput)
            .fixedSize()
    }

    private var yamlOutput: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Toggle("启用 UDP", isOn: $session.udpEnabled)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("udpToggle")
                    .disabled(!session.canUseOutput)
                Spacer()
                Button("导出 Clash 配置…", systemImage: "square.and.arrow.down") { session.exportYAML() }
                    .disabled(!session.canUseOutput)
                    .accessibilityIdentifier("exportYAML")
            }
            Text("UDP 默认关闭，确认服务端支持后再开启。配置提供“代理选择”与 DIRECT；进入 Clash 的流量按所选策略转发。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(session.yaml)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Clash YAML 配置")
                .accessibilityValue(session.yaml)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("yamlPreview")
        }
    }
}
