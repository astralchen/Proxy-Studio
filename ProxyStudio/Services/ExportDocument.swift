import SwiftUI
import UniformTypeIdentifiers

/// 供系统文件导出器读取和写入的内存文档。
///
/// 文档按原样保存字节，不解析 YAML，也不对图片进行重新编码。
/// 调用方应确保传给文件导出器的内容类型与 `data` 的实际格式一致。
struct ExportDocument: FileDocument {
    /// 可读取的内容类型。系统未注册 YAML 类型时，使用纯文本类型作为后备。
    static var readableContentTypes: [UTType] { [.data, .plainText, .png, UTType(filenameExtension: "yaml") ?? .plainText] }
    /// 文档的完整内容。
    var data: Data

    /// 使用已编码的文件内容创建文档。
    ///
    /// - Parameter data: 要保存的原始字节，例如 UTF-8 YAML 或 PNG 数据。
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

/// 在 SwiftUI 中呈现 UIKit 的图片分享界面。
///
/// 分享项目在控制器创建时确定。需要分享另一张图片时，应重新呈现此视图。
struct ShareSheet: UIViewControllerRepresentable {
    /// 交给系统活动控制器分享的图片。
    let image: UIImage

    /// 创建以当前图片为唯一分享项目的活动控制器。
    ///
    /// - Parameter context: SwiftUI 提供的上下文。
    /// - Returns: 使用系统默认活动列表的分享控制器。
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    /// 接收 SwiftUI 的更新通知；已呈现控制器的分享项目保持不变。
    ///
    /// - Parameters:
    ///   - controller: 当前呈现的活动控制器。
    ///   - context: SwiftUI 提供的更新上下文。
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
