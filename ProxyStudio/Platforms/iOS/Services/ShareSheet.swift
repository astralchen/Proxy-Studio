import SwiftUI
import UIKit

/// 在 SwiftUI 中呈现 UIKit 的图片分享界面。
///
/// 分享项目在控制器创建时确定。需要分享另一张图片时，应重新呈现此视图。
struct ShareSheet: UIViewControllerRepresentable {
    /// 交给系统活动控制器分享的图片。
    let image: QRCodeImage

    /// 创建以当前图片为唯一分享项目的活动控制器。
    ///
    /// - Parameter context: SwiftUI 提供的上下文。
    /// - Returns: 使用系统默认活动列表的分享控制器。
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [UIImage(cgImage: image.cgImage)], applicationActivities: nil)
    }
    /// 接收 SwiftUI 的更新通知；已呈现控制器的分享项目保持不变。
    ///
    /// - Parameters:
    ///   - controller: 当前呈现的活动控制器。
    ///   - context: SwiftUI 提供的更新上下文。
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
