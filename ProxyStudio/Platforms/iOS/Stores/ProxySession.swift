import Observation
import SwiftUI
import UniformTypeIdentifiers

/// 一个 iOS 窗口的内存会话。关闭窗口后不保留节点或凭据。
@MainActor
@Observable
final class ProxySession {
    // MARK: - 会话状态

    /// 两平台共用的输出格式；保留窗口菜单使用的 `Output` 类型名。
    typealias Output = OutputFormat
    /// 节点完整字段是否展开；新节点默认收起。
    var detailsExpanded = false
    /// 最近一次复制操作的反馈；无反馈时为 `nil`，显示时长由所属视图控制。
    var copyFeedback: String?

    /// 待解析的单条链接，默认为空字符串。
    ///
    /// 赋予不同文本时立即清除旧节点、元数据、二维码及解析错误，并重置详情和 UDP。
    /// 赋予相同文本不改变状态；输出格式保留到新节点解析成功或主动清空。
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
    /// 当前成功解析的节点；初始、输入变更或解析失败时为 `nil`。
    private(set) var node: ProxyNode?
    /// 当前节点的稳定身份；无节点时为 `nil`。
    private(set) var nodeIdentifier: UUID?
    /// 当前节点成功解析的时间；无节点时为 `nil`。
    private(set) var nodeCreatedAt: Date?
    /// 当前解析错误，不包含原始链接或密码。
    private(set) var parseError: String?
    /// 当前节点生成的二维码，编码失败时为 `nil`。
    private(set) var qrImage: QRCodeImage?
    /// 是否在展开的字段中显示密码，默认 `false`；输入变更或新节点解析成功后重置。
    var revealPassword = false
    /// 二维码、URL、JSON 与 Clash 共用的 UDP 选项；新节点使用链接中的初始值。
    var udpEnabled = false {
        didSet {
            guard udpEnabled != oldValue else { return }
            qrImage = node.flatMap { QRCodeRenderer.image(for: $0.shadowrocketLink(udpEnabled: udpEnabled)) }
        }
    }
    // MARK: - 即时输出

    /// 当前 UDP 选项对应的规范化 Shadowrocket 链接；无节点时为空字符串。
    ///
    /// 与二维码载荷一致，由节点重新生成，不直接返回原始 `input`。
    var shareLink: String { node?.shadowrocketLink(udpEnabled: udpEnabled) ?? "" }
    /// 当前输出格式，默认 `.qr`；布局变化或重复解析同一节点不会重置。
    var output: Output = .qr
    // MARK: - 文件导出状态

    /// 保存面板使用的字节快照；尚未准备导出或导出结束后为 `nil`。
    ///
    /// 面板显示期间即使实时输出发生变化，也不会重新编码该文档。
    private(set) var exportDocument: ExportDocument?
    /// 待导出快照的文件类型。
    private(set) var exportType: UTType = .plainText
    /// 待导出快照的建议文件名。
    private(set) var exportName = "clash.yaml"
    /// 是否显示系统保存面板。
    var isExporting = false
    /// 导出结果提示；取消不产生提示。
    var message: String?

    // MARK: - 操作可用性与文本生成

    /// 输入去除首尾空白后非空，且未处于导出状态时为 `true`；不预先校验链接格式。
    var canParse: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isExporting }
    /// 当前窗口有可清除内容且未显示保存面板时允许清空。
    var canClear: Bool { (!input.isEmpty || node != nil || parseError != nil) && !isExporting }
    /// 有节点且未显示保存面板时允许操作输出。
    var canUseOutput: Bool { node != nil && !isExporting }
    /// 根据当前 UDP 选项生成原始 YAML；无节点时为空字符串，预览换行不写入内容。
    var yaml: String { node.map { ClashConfiguration(node: $0, udpEnabled: udpEnabled).yaml } ?? "" }

    /// 当前 JSON 的原始字节；无节点或编码失败时为 `nil`。
    var jsonData: Data? {
        guard let node, let nodeIdentifier, let nodeCreatedAt else { return nil }
        return try? ShadowrocketConfiguration(node: node, udpEnabled: udpEnabled,
                                              identifier: nodeIdentifier, createdAt: nodeCreatedAt).encodedJSON()
    }
    /// 当前 JSON 文本，不包含视觉换行；编码失败时为 `nil`。
    var json: String? { jsonData.map { String(decoding: $0, as: UTF8.self) } }

    // MARK: - 解析与清空

    /// 解析当前输入并更新节点和二维码；解析不可用时不执行操作。
    ///
    /// 解析结果与当前节点不同时创建 UUID 和时间，重置详情、复制反馈和输出格式，
    /// 并采用链接中的 UDP 初始值。同一节点重复解析保留元数据及当前显示选项。
    /// 失败时清除节点、元数据和二维码，将本地化错误写入 `parseError`，不向调用方抛出错误。
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

    /// 清除当前窗口的输入、节点、显示选项及结果提示，并返回二维码格式。
    ///
    /// - Note: `canClear` 为 `false` 时不执行操作，保存面板显示期间不会清除会话。
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

    // MARK: - 导出与结果处理

    /// 当前输出是否可保存；需要有效节点且未处于导出状态。
    ///
    /// 二维码需要已有图像，JSON 需要编码成功；PNG 最终编码是否成功由 `exportPNG()` 检查。
    var canExportCurrent: Bool {
        guard canUseOutput else { return false }
        switch output { case .qr: return qrImage != nil; case .yaml, .url: return true; case .json: return jsonData != nil }
    }

    /// 当前文本格式的原始内容，不包含预览的视觉换行。
    ///
    /// 二维码或 JSON 编码失败时为 `nil`；无节点时 YAML 为空字符串、JSON 与 URL 为 `nil`。
    /// 界面还需使用 `canUseOutput` 判断复制操作是否可用。
    var outputText: String? {
        switch output { case .qr: nil; case .yaml: yaml; case .json: json; case .url: node == nil ? nil : shareLink }
    }

    /// 按当前格式调用对应导出方法，准备字节快照并请求显示系统保存面板。
    ///
    /// - Note: 准备文档不代表写入完成；最终结果由 `finishExport(_:)` 或 `cancelExport()` 处理。
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

    /// 捕获当前规范化分享链接的 UTF-8 字节快照，并请求显示系统保存面板。
    ///
    /// 默认文件名为 `shadowrocket.url`，不添加 BOM、末尾换行或额外包装。
    /// 内容与当前二维码载荷一致，不保留原始输入的转义或编码形式。
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

    /// 处理系统文件导出器的完成回调，并释放待保存文档。
    ///
    /// - Parameter result: 系统报告的保存 URL 或错误；本方法不再自行读写文件。
    /// - Note: 成功显示保存提示，失败显示错误；`NSUserCancelledError` 不显示提示。
    ///   三种结果均保留节点、UDP 和当前显示选项。
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

    /// 保存原始字节及文件描述，清除旧提示并请求显示系统保存面板。
    ///
    /// - Parameters:
    ///   - data: 已完成编码的字节；不会随实时预览重新生成。
    ///   - type: 与字节实际格式一致的系统内容类型。
    ///   - name: 保存面板建议使用的文件名，包含扩展名。
    private func prepareExport(data: Data, type: UTType, name: String) {
        message = nil
        exportDocument = ExportDocument(data: data)
        exportType = type
        exportName = name
        isExporting = true
    }

    /// 结束导出状态并释放字节快照；保留会话及上次建议的文件类型和名称。
    private func releaseExport() {
        isExporting = false
        exportDocument = nil
    }
}
