import Observation
import SwiftUI
import UniformTypeIdentifiers

/// 一个 Mac 窗口的内存会话。关闭窗口后不保留节点或凭据。
@MainActor
@Observable
final class ProxySession {
    /// 输出工作区的两个标签。
    enum Output: String, CaseIterable, Identifiable {
        case qr = "二维码"
        case yaml = "Clash YAML"
        var id: Self { self }
    }

    /// 当前输入；修改后立即使旧节点和解析错误失效。
    var input = "" {
        didSet {
            guard input != oldValue else { return }
            node = nil
            parseError = nil
            qrImage = nil
            revealPassword = false
            udpEnabled = false
        }
    }
    /// 最近一次成功解析的节点。
    private(set) var node: ProxyNode?
    /// 当前解析错误，不包含原始链接或密码。
    private(set) var parseError: String?
    /// 当前节点生成的二维码，编码失败时为 `nil`。
    private(set) var qrImage: QRCodeImage?
    /// 是否显示密码；切换节点后重置。
    var revealPassword = false
    /// Clash UDP 选项；切换节点后重置。
    var udpEnabled = false
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

    /// 用当前输入解析节点，并在新节点出现时重置详情选项。
    func parse() {
        guard canParse else { return }
        do {
            let parsed = try ProxyNode.parse(input)
            if parsed != node {
                revealPassword = false
                udpEnabled = false
                output = .qr
            }
            node = parsed
            parseError = nil
            qrImage = QRCodeRenderer.image(for: parsed.shareLink)
        } catch {
            node = nil
            qrImage = nil
            parseError = error.localizedDescription
        }
    }

    /// 清除当前窗口的输入、节点、选项及结果提示。
    func clear() {
        guard canClear else { return }
        input = ""
        node = nil
        parseError = nil
        qrImage = nil
        revealPassword = false
        udpEnabled = false
        output = .qr
        message = nil
    }

    /// 捕获当前 YAML 的字节快照并打开系统保存面板。
    func exportYAML() {
        guard canUseOutput else { return }
        prepareExport(data: Data(yaml.utf8), type: UTType(filenameExtension: "yaml") ?? .plainText, name: "clash.yaml")
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
