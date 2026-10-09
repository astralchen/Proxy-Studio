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
                WorkspaceEmptyView()
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .focusedSceneValue(\.proxySession, session)
        .background(OutputEscapeHandler(session: session))
        .toolbar {
            ToolbarItem {
                Button("清空", systemImage: "trash") { session.clear() }
                    .disabled(!session.canClear)
                    .help("清空当前窗口（⇧⌘⌫）")
                    .accessibilityIdentifier("clearInput")
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                if session.node != nil {
                    Button(session.output.exportTitle, systemImage: "square.and.arrow.down") { session.exportCurrent() }
                        .buttonStyle(.glassProminent)
                        .disabled(!session.canExportCurrent)
                        .accessibilityIdentifier(session.output.exportIdentifier)
                }
            }
            ToolbarItem {
                if session.node != nil {
                    if session.output == .qr {
                        OutputShareButton(image: session.qrImage, link: session.shareLink,
                                          isEnabled: session.canUseOutput)
                    } else {
                        Button("复制文本", systemImage: "doc.on.doc") {
                            guard let text = session.outputText else { return }
                            NSPasteboard.general.clearContents()
                            if NSPasteboard.general.setString(text, forType: .string) {
                                session.copyFeedback = "已复制。"
                            }
                        }
                        .disabled(!session.canUseOutput || session.outputText == nil)
                        .accessibilityIdentifier("copyOutput")
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let feedback = session.copyFeedback {
                Text(feedback).font(.callout).padding(12)
                    .background(WorkspaceStyle.surface, in: Capsule())
                    .padding(16).accessibilityIdentifier("copyFeedback")
            }
        }
        .task(id: session.copyFeedback) {
            guard session.copyFeedback != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            session.copyFeedback = nil
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
