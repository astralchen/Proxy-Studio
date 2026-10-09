import AppKit
import SwiftUI

/// 通过原生菜单选择图片或链接，并将分享面板锚定到当前窗口按钮。
struct OutputShareButton: NSViewRepresentable {
    let image: QRCodeImage?
    let link: String
    var isEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier("shareMenu")
        button.setAccessibilityLabel("分享")
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let coordinator = context.coordinator
        coordinator.image = image
        coordinator.link = link
        let menu = NSMenu()
        menu.addItem(withTitle: "分享", action: nil, keyEquivalent: "")
        for (title, tag, identifier) in [("分享图片", 0, "sharePNG"), ("分享导入链接", 1, "shareLink")] {
            let item = NSMenuItem(title: title, action: #selector(Coordinator.share(_:)), keyEquivalent: "")
            item.target = coordinator
            item.tag = tag
            item.setAccessibilityIdentifier(identifier)
            item.isEnabled = isEnabled && (tag == 1 || image != nil)
            menu.addItem(item)
        }
        menu.autoenablesItems = false
        button.menu = menu
        button.isEnabled = isEnabled
    }

    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        coordinator.picker?.delegate = nil
        coordinator.picker?.close()
        coordinator.picker = nil
        coordinator.button = nil
    }

    /// 每个按钮拥有自己的分享状态，选择菜单项时捕获不可变内容。
    @MainActor
    final class Coordinator: NSObject, @preconcurrency NSSharingServicePickerDelegate {
        weak var button: NSPopUpButton?
        var image: QRCodeImage?
        var link = ""
        var picker: NSSharingServicePicker?

        @objc func share(_ sender: NSMenuItem) {
            guard let button, button.window != nil else { return }
            let items: [Any]
            if sender.tag == 0 {
                guard let image else { return }
                items = [NSImage(cgImage: image.cgImage,
                                 size: NSSize(width: image.cgImage.width, height: image.cgImage.height))]
            } else {
                guard !link.isEmpty else { return }
                items = [link]
            }
            let picker = NSSharingServicePicker(items: items)
            picker.delegate = self
            self.picker = picker
            picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            picker = nil
        }
    }
}
