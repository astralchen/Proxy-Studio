import SwiftUI

/// 应用入口。每个窗口创建独立的导入会话。
@main
struct ProxyStudioApp: App {
    /// 创建由系统管理的窗口场景，每个根视图持有自己的内存会话。
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
    /// 读取 Debug 外观参数；未提供有效参数位置时返回 `nil`，由系统决定外观。
    ///
    /// 参数值为 `Dark` 时使用深色，其余已提供的值使用浅色；不写入系统偏好。
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
    /// 是否强制从右到左布局；为 `false` 时不覆盖上游环境。
    let forceRTL: Bool

    /// 仅在明确启用时向内容注入 RTL 环境。
    @ViewBuilder
    func body(content: Content) -> some View {
        if forceRTL { content.environment(\.layoutDirection, .rightToLeft) }
        else { content }
    }
}
#endif
