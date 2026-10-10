import SwiftUI

/// 将当前场景的窗口会话接入 SwiftUI 焦点值系统的键。
private struct ProxySessionKey: FocusedValueKey {
    /// 焦点值保存窗口会话对象，由根视图通过 `focusedSceneValue` 发布。
    typealias Value = ProxySession
}

extension FocusedValues {
    /// 当前场景发布的窗口会话；没有相应焦点值时为 `nil`。
    ///
    /// 菜单操作由此路由到当前窗口，各窗口节点及导出状态独立。
    var proxySession: ProxySession? {
        get { self[ProxySessionKey.self] }
        set { self[ProxySessionKey.self] = newValue }
    }
}

/// 提供与当前窗口按钮一致的菜单操作和快捷键。
struct ProxyCommands: Commands {
    /// 当前获得焦点的会话；无会话时菜单操作禁用。
    @FocusedValue(\.proxySession) private var session

    /// 创建解析、清空、四种输出切换及导出命令，复用会话的操作可用性。
    var body: some Commands {
        CommandMenu("节点") {
            Button("解析链接") { session?.parse() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(session?.canParse != true)
            Button("清空") { session?.clear() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(session?.canClear != true)
            Divider()
            Button("显示二维码") { session?.output = .qr }
                .keyboardShortcut("1")
                .disabled(session?.canUseOutput != true)
            Button("显示 Clash YAML") { session?.output = .yaml }
                .keyboardShortcut("2")
                .disabled(session?.canUseOutput != true)
            Button("显示 Shadowrocket JSON") { session?.output = .json }
                .keyboardShortcut("3")
                .disabled(session?.canUseOutput != true)
            Button("显示 Shadowrocket URL") { session?.output = .url }
                .keyboardShortcut("4")
                .disabled(session?.canUseOutput != true)
            // 与当前窗口键盘适配共用返回二维码的操作。
            Button("返回二维码") { session?.output = .qr }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(session?.canUseOutput != true || session?.output == .qr || session?.message != nil)
            Divider()
            Button("保存 PNG…") { session?.exportPNG() }
                .disabled(session?.canUseOutput != true || session?.qrImage == nil)
            Button("导出 Clash 配置…") { session?.exportYAML() }
                .disabled(session?.canUseOutput != true)
            Button("导出 Shadowrocket JSON…") { session?.exportJSON() }
                .disabled(session?.canUseOutput != true)
            Button("导出 Shadowrocket URL…") { session?.exportURL() }
                .disabled(session?.canUseOutput != true)
        }
    }
}
