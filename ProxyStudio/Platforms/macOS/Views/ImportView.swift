import SwiftUI

/// 可滚动的桌面导入栏，使用系统文本编辑器保留标准编辑操作。
struct ImportView: View {
    /// 所属窗口的会话；编辑不同文本会立即使旧输出失效。
    @Bindable var session: ProxySession
    /// 系统文本编辑器的焦点，点击解析时结束编辑。
    @FocusState private var isEditing: Bool

    /// 按侧栏可用宽度布局输入、错误及解析结果，允许竖向滚动。
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ImportIntroduction()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("导入节点", systemImage: "link").font(.headline)
                            Spacer()
                            PasteButton(payloadType: String.self) { values in
                                if let first = values.first { session.input = first }
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("粘贴代理链接")
                            .disabled(session.isExporting)
                        }
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $session.input)
                                .font(.system(.body, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .focused($isEditing)
                                .disabled(session.isExporting)
                                .accessibilityLabel("SOCKS 代理链接")
                                .accessibilityIdentifier("proxyLinkInput")
                            if session.input.isEmpty {
                                Text("socks://账号信息@服务器:端口#名称")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5).padding(.top, 2)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(10)
                        .frame(height: 180)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 1) }
                        if let error = session.parseError {
                            Label(error, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("parseError")
                        }
                        GlassEffectContainer(spacing: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                Button {
                                    isEditing = false
                                    session.parse()
                                } label: {
                                    Text("解析链接").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                                .controlSize(.large)
                                .disabled(!session.canParse)
                                .help("解析当前输入（⌘↩）")
                                .accessibilityIdentifier("parseButton")
                                Button("试用示例节点") { session.input = ProxyNode.exampleLink }
                                    .buttonStyle(.glass)
                                    .disabled(session.isExporting)
                            }
                        }
                        Text("支持 socks://、socks5://、转义链接，以及 Base64 或明文账号。")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let node = session.node {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("已解析 · \(node.name)").font(.headline)
                                Text("\(node.host) · \(String(node.port))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal)
                        }
                        .accessibilityIdentifier("nodeResult")
                    }
                    Divider()
                    Label("链接仅在本机解析。二维码和导出文件包含账号信息，请妥善保存。", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: max(0, geometry.size.width - 40), alignment: .leading)
                .padding(20)
            }
        }
    }
}
