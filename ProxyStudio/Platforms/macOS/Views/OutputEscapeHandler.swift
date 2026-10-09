import AppKit
import SwiftUI

/// 在当前窗口中处理文本输出的 Escape，同时保留原生面板的取消操作。
struct OutputEscapeHandler: NSViewRepresentable {
    let session: ProxySession

    func makeNSView(context: Context) -> EscapeView {
        EscapeView(session: session)
    }

    func updateNSView(_ view: EscapeView, context: Context) {
        view.session = session
    }

    static func dismantleNSView(_ view: EscapeView, coordinator: ()) {
        view.stopMonitoring()
    }

    /// 事件监听随视图进入、离开窗口安装和移除，不改变文本编辑器的焦点。
    final class EscapeView: NSView {
        var session: ProxySession
        private var monitor: Any?

        init(session: ProxySession) {
            self.session = session
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window,
                      window.attachedSheet == nil, event.keyCode == 53,
                      event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                        .subtracting([.capsLock, .numericPad, .function]).isEmpty,
                      self.session.canUseOutput, self.session.message == nil,
                      self.session.output != .qr else { return event }
                self.session.output = .qr
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
