import AppKit
import SwiftUI

/// 通过原生菜单选择图片或链接，并将分享面板锚定到当前窗口按钮。
struct OutputShareButton: NSViewRepresentable {
    /// 当前二维码像素；为 `nil` 时禁用图片菜单项，链接入口仍可用。
    let image: QRCodeImage?
    /// 当前规范化分享链接，包含当前 UDP 选项；空字符串不会触发链接分享。
    let link: String
    /// 分享按钮整体是否可用，默认 `true`；保存期间由窗口会话置为不可用。
    var isEnabled = true

    // MARK: - AppKit 视图桥接

    /// 创建当前按钮专用的分享协调器。
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 创建原生下拉按钮，并提供分享菜单的辅助功能名称。
    /// - Parameter context: 包含此按钮协调器的 SwiftUI 上下文。
    /// - Returns: 当前窗口中用于锚定分享面板的按钮。
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.bezelStyle = .rounded
        button.setAccessibilityIdentifier("shareMenu")
        button.setAccessibilityLabel("分享")
        context.coordinator.button = button
        return button
    }

    /// 将最新像素、链接及可用性写入协调器，并重建两项分享菜单。
    /// - Parameters:
    ///   - button: 当前窗口已创建的原生按钮。
    ///   - context: 包含此按钮协调器的 SwiftUI 更新上下文。
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

    /// 关闭仍显示的分享选择器并解除代理和按钮引用。
    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        coordinator.picker?.delegate = nil
        coordinator.picker?.close()
        coordinator.picker = nil
        coordinator.button = nil
    }

    /// 每个按钮拥有自己的分享状态，选择菜单项时捕获不可变内容。
    @MainActor
    final class Coordinator: NSObject, @preconcurrency NSSharingServicePickerDelegate {
        /// 分享面板的锚点；弱引用避免协调器延长原生按钮的生命周期。
        weak var button: NSPopUpButton?
        /// 最近一次 SwiftUI 更新提供的二维码像素；不存在时为 `nil`。
        var image: QRCodeImage?
        /// 最近一次 SwiftUI 更新提供的规范化分享链接。
        var link = ""
        /// 当前系统分享选择器；服务选择回调或视图销毁时释放。
        var picker: NSSharingServicePicker?

        /// 根据菜单项创建分享对象，并在所属窗口按钮下方显示系统分享选择器。
        ///
        /// - Parameter sender: 标签为 `0` 时分享图片，其余标签分享非空链接。
        /// - Note: 选择此菜单项时捕获内容；呈现选择器不代表已向外部服务发送完成。
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

        /// 在系统报告服务选择结果时释放当前选择器；不把该回调作为发送成功回执。
        /// - Parameters:
        ///   - sharingServicePicker: 报告选择结果的系统选择器。
        ///   - service: 被选中的服务；没有选择服务时可为 `nil`。
        func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
            picker = nil
        }
    }
}
