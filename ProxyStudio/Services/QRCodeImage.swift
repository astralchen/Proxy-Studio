import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// 持有带静区的二维码像素，并按原始尺寸编码 PNG。
struct QRCodeImage {
    /// 可用于 SwiftUI、UIKit、AppKit 和 Vision 的共享像素。
    let cgImage: CGImage

    /// 将共享像素按原始尺寸编码为 PNG。
    ///
    /// - Returns: 包含二维码及白色静区的 PNG 字节；无法创建或完成编码器时为 `nil`。
    func pngData() -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
