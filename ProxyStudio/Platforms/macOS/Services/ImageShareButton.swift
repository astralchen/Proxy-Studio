import AppKit
import SwiftUI

/// 将当前二维码交给锚定在按钮上的 Mac 原生分享选择器。
struct ImageShareButton: NSViewRepresentable {
    let image: QRCodeImage
    var isEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator(image: image) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "分享图片", target: context.coordinator, action: #selector(Coordinator.share(_:)))
        button.bezelStyle = .rounded
        // AppKit 要求分享选择器在 mouseDown 中呈现，mouseUp 会立即结束菜单跟踪。
        button.sendAction(on: .leftMouseDown)
        button.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "分享图片")
        button.imagePosition = .imageLeading
        button.setAccessibilityIdentifier("sharePNG")
        button.setAccessibilityLabel("分享二维码图片")
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.image = image
        button.target = context.coordinator
        button.action = #selector(Coordinator.share(_:))
        button.isEnabled = isEnabled
    }

    static func dismantleNSView(_ button: NSButton, coordinator: Coordinator) {
        button.target = nil
        coordinator.picker?.delegate = nil
        coordinator.picker?.close()
        coordinator.picker = nil
    }

    /// 分享选择器仅属于该按钮，避免跨窗口复用 AppKit 对象。
    @MainActor
    final class Coordinator: NSObject, @preconcurrency NSSharingServicePickerDelegate {
        var image: QRCodeImage
        var picker: NSSharingServicePicker?

        init(image: QRCodeImage) { self.image = image }

        @objc func share(_ sender: NSButton) {
            guard sender.window != nil else { return }
            let nativeImage = NSImage(cgImage: image.cgImage,
                                      size: NSSize(width: image.cgImage.width, height: image.cgImage.height))
            let picker = NSSharingServicePicker(items: [nativeImage])
            picker.delegate = self
            self.picker = picker
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }

        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            picker = nil
        }
    }
}
