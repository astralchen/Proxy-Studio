import CoreImage.CIFilterBuiltins

/// 使用 Core Image 生成可显示和导出的二维码图片。
///
/// 此类型在主执行器上使用，并在多次渲染之间复用图像上下文。
@MainActor
enum QRCodeRenderer {
    /// 复用的渲染上下文，避免每次生成二维码时重新创建渲染资源。
    private static let context = CIContext()

    /// 将字符串编码为带白色静区的二维码。
    ///
    /// 使用 UTF-8 编码和 M 级纠错。二维码每个模块按 10 倍整数比例放大，
    /// 四周额外保留四个模块宽的白色静区，导出的 PNG 也包含该区域。
    ///
    /// - Parameter text: 要编码的完整文本。
    /// - Returns: 生成的二维码；滤镜无法编码输入或渲染失败时返回 `nil`。
    static func image(for text: String) -> QRCodeImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // 将静区合成到图片本身，确保脱离界面背景后仍保留可扫描的留白。
        let bounds = output.extent.insetBy(dx: -4, dy: -4)
        let background = CIImage(color: .white).cropped(to: bounds)
        let result = output.composited(over: background)
            .transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(result, from: result.extent) else { return nil }
        return QRCodeImage(cgImage: cgImage)
    }
}
