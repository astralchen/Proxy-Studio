import AppKit
import SwiftUI

/// 原生 Mac 工作区。根视图持有独立会话，子视图只编辑该会话。
struct ContentView: View {
    @State private var session = ProxySession()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ImportView(session: session)
                .navigationTitle("Proxy Studio")
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
        } detail: {
            if let node = session.node {
                NodeDetailView(session: session, node: node)
            } else {
                ContentUnavailableView("准备好你的下一条连接", systemImage: "network",
                                       description: Text("输入一条 SOCKS 链接，即可生成二维码和 Clash 配置。"))
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .focusedSceneValue(\.proxySession, session)
        .toolbar {
            ToolbarItemGroup {
                Button("清空", systemImage: "trash") { session.clear() }
                    .disabled(!session.canClear)
                    .help("清空当前窗口（⇧⌘⌫）")
                    .accessibilityIdentifier("clearInput")
                Menu {
                    Button("保存 PNG…") { session.exportPNG() }
                        .disabled(session.qrImage == nil)
                    Button("导出 Clash 配置…") { session.exportYAML() }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.down")
                }
                .disabled(!session.canUseOutput)
                .help("导出当前节点")
            }
        }
        .onExitCommand {
            if session.canUseOutput, session.output == .yaml, session.message == nil {
                session.output = .qr
            }
        }
        .fileExporter(isPresented: $session.isExporting, document: session.exportDocument,
                      contentTypes: [session.exportType], defaultFilename: session.exportName,
                      onCompletion: { session.finishExport($0) }, onCancellation: { session.cancelExport() })
        .alert("导出", isPresented: Binding(get: { session.message != nil },
                                           set: { if !$0 { session.message = nil } })) {
            Button("好") { session.message = nil }
        } message: {
            Text(session.message ?? "")
        }
    }
}

#Preview { ContentView() }
