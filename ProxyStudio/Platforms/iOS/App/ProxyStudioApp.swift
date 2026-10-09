import SwiftUI

/// 应用入口。每个窗口创建独立的导入会话。
@main
struct ProxyStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.teal)
        }
    }
}
