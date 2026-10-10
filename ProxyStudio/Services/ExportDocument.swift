import SwiftUI
import UniformTypeIdentifiers

/// 供系统文件导出器读取和写入的内存文档。
///
/// 文档按原样保存字节，不解析链接、YAML 或 JSON，也不对图片进行重新编码。
/// 调用方应确保传给文件导出器的内容类型与 `data` 的实际格式一致。
struct ExportDocument: FileDocument {
    // MARK: - 内容类型与原始字节

    /// Shadowrocket 链接文件的内容类型；无法识别扩展名时使用不附加文本扩展名的数据类型。
    static var shadowrocketURLType: UTType { UTType(filenameExtension: "url") ?? .data }

    /// 可读取的内容类型。系统未注册 YAML 类型时，使用纯文本类型作为后备。
    static var readableContentTypes: [UTType] {
        [.data, .plainText, .png, .json, UTType(filenameExtension: "yaml") ?? .plainText, shadowrocketURLType]
    }
    /// 文档的完整内容；导出前由会话捕获，后续预览更新不改变该快照。
    var data: Data

    // MARK: - 文档读写

    /// 使用已编码的文件内容创建文档。
    ///
    /// - Parameter data: 要保存的原始字节，例如 UTF-8 链接、YAML、JSON 或 PNG 数据。
    init(data: Data) { self.data = data }

    /// 从系统提供的普通文件包装器读取文档。
    ///
    /// - Parameter configuration: 包含待读取文件的配置。
    /// - Throws: 文件包装器不包含普通文件内容时，抛出 `CocoaError.fileReadCorruptFile`。
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    /// 创建包含当前数据的普通文件包装器。
    ///
    /// - Parameter configuration: 系统提供的写入配置；本实现不根据内容类型转换数据。
    /// - Returns: 包含 `data` 的文件包装器，由系统负责写入所选位置。
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
