import SwiftUI

/// 应用入口。每个窗口创建独立的导入会话。
@main
struct ProxyStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(WorkspaceStyle.accent)
                #if DEBUG
                .preferredColorScheme(debugColorScheme)
                .modifier(DebugLayoutDirection(forceRTL: ProcessInfo.processInfo.arguments.contains("-ProxyStudioRTL")))
                #endif
        }
    }
    #if DEBUG
    private var debugColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-AppleInterfaceStyle"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1] == "Dark" ? .dark : .light
    }
    #endif
}

#if DEBUG
/// 调试验收可强制语义 RTL；未指定参数时沿用系统环境，不写入系统偏好。
private struct DebugLayoutDirection: ViewModifier {
    let forceRTL: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if forceRTL { content.environment(\.layoutDirection, .rightToLeft) }
        else { content }
    }
}
#endif
