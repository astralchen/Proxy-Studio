import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 交给系统分享面板的不可变 PNG 快照，保留二维码像素与白色静区。
struct PNGShareItem: Transferable {
    /// 选择分享时对应的原始 PNG 字节。
    let data: Data

    /// 使用 PNG 内容类型导出，不经过有损图片格式转换。
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in item.data }
            .suggestedFileName("shadowrocket.png")
    }
}
