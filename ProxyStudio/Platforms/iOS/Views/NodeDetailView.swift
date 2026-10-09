import SwiftUI
import UniformTypeIdentifiers


/// 展示节点信息，并提供二维码分享、Shadowrocket JSON 与 Clash 配置导出操作。
///
/// 导出选项和密码可见性仅属于当前详情视图，不回写到节点模型。
struct NodeDetailView: View {
    // MARK: - 输入与环境

    /// 当前展示的代理节点。
    let node: ProxyNode
    /// 根视图在节点成功解析时创建的稳定身份与时间。
    let identifier: UUID
    let createdAt: Date
    /// 系统文字大小，用于决定二维码操作按钮的排列方向。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - 显示与导出状态

    /// 二维码、JSON 和 Clash 共用的 UDP 选项，初始值来自节点链接。
    @State private var udpEnabled = false
    /// 是否显示完整密码。初始值为 `false`。
    @State private var revealPassword = false
    /// 当前节点的二维码；尚未生成或生成失败时为 `nil`。
    @State private var qrImage: QRCodeImage?
    /// 当前请求呈现的模态内容。一次只呈现一种内容。
    @State private var sheet: Sheet?
    /// 为下一次系统文件导出准备的文档。
    @State private var exportDocument: ExportDocument?
    /// 与待导出数据匹配的内容类型。
    @State private var exportType: UTType = .plainText
    /// 系统文件导出器建议使用的文件名。
    @State private var exportName = "clash.yaml"
    /// 是否呈现系统文件导出器。
    @State private var isExporting = false
    /// 导出结果或准备失败的提示。非 `nil` 时显示提示框。
    @State private var message: String?

    /// 为新节点初始化独立的详情状态；未携带 UDP 参数的节点默认关闭。
    init(node: ProxyNode, identifier: UUID, createdAt: Date) {
        self.node = node
        self.identifier = identifier
        self.createdAt = createdAt
        _udpEnabled = State(initialValue: node.udpEnabled)
    }

    private var shareLink: String { node.shadowrocketLink(udpEnabled: udpEnabled) }

    /// 详情界面支持的模态内容及其展示时的数据快照。
    private enum Sheet: Identifiable {
        // 文本预览保存字符串快照；图片分享保存生成后的图片。
        case yaml(String), json(String), share(QRCodeImage)

        /// 模态内容的类型标识，不随关联数据变化。
        var id: String {
            switch self { case .yaml: "yaml"; case .json: "json"; case .share: "share" }
        }
    }
    /// 由当前节点与 UDP 选项构成的导出配置。
    private var configuration: ClashConfiguration {
        ClashConfiguration(node: node, udpEnabled: udpEnabled)
    }

    /// 当前节点和共享 UDP 状态对应的 JSON 原始字节。
    private var jsonData: Data? {
        try? ShadowrocketConfiguration(node: node, udpEnabled: udpEnabled,
                                       identifier: identifier, createdAt: createdAt).encodedJSON()
    }

    // MARK: - 视图内容

    /// 节点信息、二维码和配置导出操作组成的表单。
    var body: some View {
        Form {
            Section("节点信息") {
                LabeledContent("名称", value: node.name)
                LabeledContent("协议", value: "SOCKS5").accessibilityIdentifier("protocolRow")
                LabeledContent("服务器", value: node.host)
                    .textSelection(.enabled)
                LabeledContent("端口", value: String(node.port))
                if let username = node.username, let password = node.password {
                    LabeledContent("账号", value: username).textSelection(.enabled)
                    LabeledContent("密码") {
                        HStack {
                            Text(revealPassword ? password : "••••••••")
                                .textSelection(.enabled)
                            Button(revealPassword ? "隐藏密码" : "显示密码",
                                   systemImage: revealPassword ? "eye.slash" : "eye") {
                                revealPassword.toggle()
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                } else {
                    LabeledContent("认证", value: "无需账号")
                }
            }
            Section {
                Toggle("启用 UDP", isOn: $udpEnabled)
                    .accessibilityIdentifier("udpToggle")
            } header: {
                Text("导出选项")
            } footer: {
                Text("UDP 用于 Shadowrocket 二维码、JSON 和 Clash YAML。未指定时默认关闭，确认服务端支持后再开启。")
            }
            Section {
                VStack(spacing: 14) {
                    if let qrImage {
                        Image(qrImage.cgImage, scale: 1, label: Text("\(node.name) 的 Shadowrocket 导入二维码"))
                            .interpolation(.none).resizable().scaledToFit()
                            .frame(maxWidth: 300)
                            .accessibilityLabel("\(node.name) 的 Shadowrocket 导入二维码")
                            .accessibilityIdentifier("qrImage")
                        // 辅助功能字号使用纵向排列，为按钮文字提供足够的可用宽度。
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                        layout {
                            Button("保存 PNG", systemImage: "square.and.arrow.down") { saveQR(qrImage) }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("exportPNG")
                            Button("分享", systemImage: "square.and.arrow.up") { sheet = .share(qrImage) }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        ContentUnavailableView("二维码生成失败", systemImage: "qrcode",
                                               description: Text("链接可能超过二维码容量，仍可分享链接或导出 JSON、YAML。"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                ShareLink(item: shareLink) {
                    Label("分享导入链接", systemImage: "link")
                }
                Button("预览 JSON", systemImage: "doc.text.magnifyingglass") {
                    guard let data = jsonData else { message = "无法生成 JSON 文件。"; return }
                    sheet = .json(String(decoding: data, as: UTF8.self))
                }
                .accessibilityIdentifier("previewJSON")
                Button("导出 JSON", systemImage: "square.and.arrow.down") { saveJSON() }
                    .accessibilityIdentifier("exportJSON")
            } header: {
                Text("Shadowrocket")
            } footer: {
                Text("在 Shadowrocket 中扫描二维码，或识别保存的图片。二维码和 JSON 文件包含节点账号和密码。JSON 使用单节点导出格式，请确认目标客户端的导入入口支持该格式。")
            }
            Section {
                LabeledContent("路由", value: "全部流量通过所选节点")
                Button("预览 YAML", systemImage: "doc.text.magnifyingglass") { sheet = .yaml(configuration.yaml) }
                Button("导出 Clash 配置", systemImage: "square.and.arrow.down") {
                    exportDocument = ExportDocument(data: Data(configuration.yaml.utf8))
                    exportType = UTType(filenameExtension: "yaml") ?? .plainText
                    exportName = "clash.yaml"
                    isExporting = true
                }
                .accessibilityIdentifier("exportYAML")
            } header: {
                Text("Clash 配置")
            } footer: {
                Text("配置包含“代理选择”策略组，可在 Clash 中切换为 DIRECT。")
            }
        }
        .accessibilityIdentifier("nodeDetails")
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
        // 视图出现时生成二维码，分享链接变化时重新执行任务。
        .task(id: shareLink) { qrImage = QRCodeRenderer.image(for: shareLink) }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .yaml(let yaml): ConfigurationPreview(title: "Clash YAML", text: yaml, identifier: "yamlPreview")
            case .json(let json): ConfigurationPreview(title: "Shadowrocket JSON", text: json, identifier: "jsonPreview")
            case .share(let image): ShareSheet(image: image)
            }
        }
        .fileExporter(isPresented: $isExporting, document: exportDocument,
                      contentTypes: [exportType], defaultFilename: exportName,
                      onCompletion: { result in
            switch result {
            case .success: message = "文件已保存。"
            case .failure(let error):
                let error = error as NSError
                message = error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
                    ? nil : "保存失败：\(error.localizedDescription)"
            }
            exportDocument = nil
        }, onCancellation: {
            message = nil
            exportDocument = nil
        })
        .alert("导出", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
    }

    // MARK: - 文件导出

    /// 捕获当前 JSON 快照并准备呈现系统文件导出器。
    private func saveJSON() {
        guard let data = jsonData else { message = "无法生成 JSON 文件。"; return }
        message = nil
        exportDocument = ExportDocument(data: data)
        exportType = .json
        exportName = "shadowrocket.json"
        isExporting = true
    }

    /// 将二维码编码为 PNG，并准备呈现系统文件导出器。
    ///
    /// 编码失败时仅更新提示信息；编码成功后，文件位置由用户在系统界面中选择。
    ///
    /// - Parameter image: 要保存的二维码图片。
    private func saveQR(_ image: QRCodeImage) {
        guard let data = image.pngData() else { message = "无法生成 PNG 文件。"; return }
        exportDocument = ExportDocument(data: data)
        exportType = .png
        exportName = "shadowrocket.png"
        isExporting = true
    }
}

/// 以等宽字体展示可选择复制的配置文本快照。
private struct ConfigurationPreview: View {
    /// 预览的格式名称。
    let title: String
    /// 打开预览时捕获的完整配置文本。
    let text: String
    /// 当前格式的辅助功能标识。
    let identifier: String
    /// 关闭当前预览的系统操作。
    @Environment(\.dismiss) private var dismiss

    /// 带完成按钮的文本预览界面。
    var body: some View {
        NavigationStack {
            ScrollView {
                // 文本在可用宽度内换行，避免窄窗口下内容延伸至可视区域之外。
                Text(text).font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(identifier)
                    .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        }
    }
}

#Preview {
    NavigationStack {
        NodeDetailView(node: try! ProxyNode.parse(ProxyNode.exampleLink), identifier: UUID(), createdAt: Date())
    }
}
