import SwiftUI

/// Proxy Studio 的应用入口。
///
/// 每个窗口创建独立的导入界面，并使用统一的青绿色强调色。
@main
struct ProxyStudioApp: App {
    /// 应用支持的窗口场景。
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.teal)
        }
    }
}
