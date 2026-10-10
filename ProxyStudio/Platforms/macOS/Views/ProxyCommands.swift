import SwiftUI

/// 当前拥有焦点的 Mac 窗口会话。
private struct ProxySessionKey: FocusedValueKey {
    typealias Value = ProxySession
}

extension FocusedValues {
    /// 菜单操作只访问当前窗口，不共享各窗口的节点。
    var proxySession: ProxySession? {
        get { self[ProxySessionKey.self] }
        set { self[ProxySessionKey.self] = newValue }
    }
}

/// 提供与当前窗口按钮一致的菜单操作和快捷键。
struct ProxyCommands: Commands {
    @FocusedValue(\.proxySession) private var session

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
