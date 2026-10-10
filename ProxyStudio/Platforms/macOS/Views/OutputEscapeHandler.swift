import AppKit
import SwiftUI

/// 在当前窗口中处理文本输出的 Escape，同时保留原生面板的取消操作。
struct OutputEscapeHandler: NSViewRepresentable {
    /// 此适配视图所属窗口的会话，不访问其他窗口的输出状态。
    let session: ProxySession

    /// 创建不获取键盘焦点的事件适配视图；进入窗口后才安装监听。
    /// - Parameter context: SwiftUI 提供的视图上下文。
    /// - Returns: 绑定当前会话的 AppKit 视图。
    func makeNSView(context: Context) -> EscapeView {
        EscapeView(session: session)
    }

    /// 更新被监听的会话引用，不改变文本编辑器的第一响应者。
    /// - Parameters:
    ///   - view: SwiftUI 已创建的事件适配视图。
    ///   - context: SwiftUI 提供的更新上下文。
    func updateNSView(_ view: EscapeView, context: Context) {
        view.session = session
    }

    /// 在适配视图销毁时移除事件监听，释放 AppKit 注册的回调。
    static func dismantleNSView(_ view: EscapeView, coordinator: ()) {
        view.stopMonitoring()
    }

    /// 事件监听随视图进入、离开窗口安装和移除，不改变文本编辑器的焦点。
    final class EscapeView: NSView {
        /// 当前处理输出切换的窗口会话。
        var session: ProxySession
        /// 已注册的本地事件监听句柄；未进入窗口或停止监听时为 `nil`。
        private var monitor: Any?

        /// 创建零尺寸事件视图，不占用工作区布局空间。
        /// - Parameter session: 所属窗口的会话。
        init(session: ProxySession) {
            self.session = session
            super.init(frame: .zero)
        }

        /// 不支持通过归档恢复；会话必须由所属 SwiftUI 窗口提供。
        required init?(coder: NSCoder) { nil }

        /// 随窗口归属变化重新安装监听，仅消费当前窗口中可返回二维码的 Escape。
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // 附属面板、导出状态及结果提示优先处理取消；带修饰键的 Escape 原样传递。
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

        /// 移除当前监听；重复调用不会产生额外操作。
        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
