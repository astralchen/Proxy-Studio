import Observation
import SwiftUI
import UniformTypeIdentifiers

/// 一个 Mac 窗口的内存会话。关闭窗口后不保留节点或凭据。
@MainActor
@Observable
final class ProxySession {
    /// 输出格式沿用原菜单接口，具体格式由两平台共享。
    typealias Output = OutputFormat
    /// 节点完整字段是否展开；新节点默认收起。
    var detailsExpanded = false
    /// 复制操作的短暂反馈；不影响导出结果。
    var copyFeedback: String?

    /// 当前输入；修改后立即使旧节点和解析错误失效。
    var input = "" {
        didSet {
            guard input != oldValue else { return }
            node = nil
            nodeIdentifier = nil
            nodeCreatedAt = nil
            parseError = nil
            qrImage = nil
            revealPassword = false
            detailsExpanded = false
            copyFeedback = nil
            udpEnabled = false
        }
    }
    /// 最近一次成功解析的节点。
    private(set) var node: ProxyNode?
    /// 当前节点的稳定身份；无节点时为 `nil`。
    private(set) var nodeIdentifier: UUID?
    /// 当前节点成功解析的时间；无节点时为 `nil`。
    private(set) var nodeCreatedAt: Date?
    /// 当前解析错误，不包含原始链接或密码。
    private(set) var parseError: String?
    /// 当前节点生成的二维码，编码失败时为 `nil`。
    private(set) var qrImage: QRCodeImage?
    /// 是否显示密码；切换节点后重置。
    var revealPassword = false
    /// 二维码、URL、JSON 与 Clash 共用的 UDP 选项；新节点使用链接中的初始值。
    var udpEnabled = false {
        didSet {
            guard udpEnabled != oldValue else { return }
            qrImage = node.flatMap { QRCodeRenderer.image(for: $0.shadowrocketLink(udpEnabled: udpEnabled)) }
        }
    }
    /// 当前导出选项对应的链接；与二维码载荷完全一致。
    var shareLink: String { node?.shadowrocketLink(udpEnabled: udpEnabled) ?? "" }
    /// 当前输出标签；调整布局不会重置。
    var output: Output = .qr
    /// 当前导出的不可变内容快照。
    private(set) var exportDocument: ExportDocument?
    /// 待导出快照的文件类型。
    private(set) var exportType: UTType = .plainText
    /// 待导出快照的建议文件名。
    private(set) var exportName = "clash.yaml"
    /// 是否显示系统保存面板。
    var isExporting = false
    /// 导出结果提示；取消不产生提示。
    var message: String?

    /// 输入非空且未显示保存面板时允许解析。
    var canParse: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isExporting }
    /// 当前窗口有可清除内容且未显示保存面板时允许清空。
    var canClear: Bool { (!input.isEmpty || node != nil || parseError != nil) && !isExporting }
    /// 有节点且未显示保存面板时允许操作输出。
    var canUseOutput: Bool { node != nil && !isExporting }
    /// 根据当前 UDP 选项生成原始 YAML，不包含视觉换行。
    var yaml: String { node.map { ClashConfiguration(node: $0, udpEnabled: udpEnabled).yaml } ?? "" }

    /// 当前 JSON 的原始字节；无节点或编码失败时为 `nil`。
    var jsonData: Data? {
        guard let node, let nodeIdentifier, let nodeCreatedAt else { return nil }
        return try? ShadowrocketConfiguration(node: node, udpEnabled: udpEnabled,
                                              identifier: nodeIdentifier, createdAt: nodeCreatedAt).encodedJSON()
    }
    /// 当前 JSON 文本，不包含视觉换行；编码失败时为 `nil`。
    var json: String? { jsonData.map { String(decoding: $0, as: UTF8.self) } }

    /// 用当前输入解析节点，并在新节点出现时重置详情选项。
    func parse() {
        guard canParse else { return }
        do {
            let parsed = try ProxyNode.parse(input)
            if parsed != node {
                nodeIdentifier = UUID()
                nodeCreatedAt = Date()
                revealPassword = false
                detailsExpanded = false
                copyFeedback = nil
                udpEnabled = parsed.udpEnabled
                output = .qr
            }
            node = parsed
            parseError = nil
            qrImage = QRCodeRenderer.image(for: shareLink)
        } catch {
            node = nil
            nodeIdentifier = nil
            nodeCreatedAt = nil
            qrImage = nil
            parseError = error.localizedDescription
        }
    }

    /// 清除当前窗口的输入、节点、选项及结果提示。
    func clear() {
        guard canClear else { return }
        input = ""
        node = nil
        nodeIdentifier = nil
        nodeCreatedAt = nil
        parseError = nil
        qrImage = nil
        revealPassword = false
        detailsExpanded = false
        copyFeedback = nil
        udpEnabled = false
        output = .qr
        message = nil
    }

    /// 当前输出可保存；二维码及 JSON 生成失败不影响其他格式。
    var canExportCurrent: Bool {
        guard canUseOutput else { return false }
        switch output { case .qr: return qrImage != nil; case .yaml, .url: return true; case .json: return jsonData != nil }
    }

    /// 当前文本格式的原始内容；二维码没有文本复制操作。
    var outputText: String? {
        switch output { case .qr: nil; case .yaml: yaml; case .json: json; case .url: node == nil ? nil : shareLink }
    }

    /// 使用当前格式捕获快照并打开系统面板。
    func exportCurrent() {
        switch output { case .qr: exportPNG(); case .yaml: exportYAML(); case .json: exportJSON(); case .url: exportURL() }
    }

    /// 捕获当前 YAML 的字节快照并打开系统保存面板。
    func exportYAML() {
        guard canUseOutput else { return }
        prepareExport(data: Data(yaml.utf8), type: UTType(filenameExtension: "yaml") ?? .plainText, name: "clash.yaml")
    }

    /// 捕获当前 JSON 的字节快照，编码成功后打开系统保存面板。
    func exportJSON() {
        guard canUseOutput else { return }
        guard let data = jsonData else {
            message = "无法生成 JSON 文件。"
            return
        }
        prepareExport(data: data, type: .json, name: "shadowrocket.json")
    }

    /// 捕获当前导入链接的 UTF-8 字节快照，不添加 BOM 或末尾换行。
    func exportURL() {
        guard canUseOutput else { return }
        prepareExport(data: Data(shareLink.utf8), type: ExportDocument.shadowrocketURLType, name: "shadowrocket.url")
    }

    /// 编码当前二维码，成功后打开系统保存面板。
    func exportPNG() {
        guard canUseOutput, let qrImage else { return }
        guard let data = qrImage.pngData() else {
            message = "无法生成 PNG 文件。"
            return
        }
        prepareExport(data: data, type: .png, name: "shadowrocket.png")
    }

    /// 处理系统文件写入结果，用户取消错误按取消处理。
    func finishExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            message = "文件已保存。"
        case .failure(let error):
            let error = error as NSError
            message = error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
                ? nil : "保存失败：\(error.localizedDescription)"
        }
        releaseExport()
    }

    /// 结束取消的导出，保留节点及所有详情选项。
    func cancelExport() {
        message = nil
        releaseExport()
    }

    private func prepareExport(data: Data, type: UTType, name: String) {
        message = nil
        exportDocument = ExportDocument(data: data)
        exportType = type
        exportName = name
        isExporting = true
    }

    private func releaseExport() {
        isExporting = false
        exportDocument = nil
    }
}
