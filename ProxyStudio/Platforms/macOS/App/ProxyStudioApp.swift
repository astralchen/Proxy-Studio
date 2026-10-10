import SwiftUI

/// 应用入口。每个窗口创建独立的导入会话。
@main
struct ProxyStudioApp: App {
    /// 创建默认 1100×760 pt 的窗口，并为当前焦点窗口注册节点菜单。
    ///
    /// 最小内容尺寸由 `ContentView` 约束；新窗口各自创建内存会话。
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(WorkspaceStyle.accent)
                #if DEBUG
                .preferredColorScheme(debugColorScheme)
                #endif
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        .commands { ProxyCommands() }
    }

    #if DEBUG
    /// 仅在 Debug 中响应测试进程的外观参数，不修改系统偏好或 Release 行为。
    ///
    /// 接受 `Light` 或 `Dark`；参数缺失或值不受支持时为 `nil`，由系统决定外观。
    private var debugColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-AppleInterfaceStyle"),
              arguments.indices.contains(index + 1) else { return nil }
        switch arguments[index + 1] {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    #endif
}
