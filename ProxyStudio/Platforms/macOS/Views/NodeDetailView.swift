import SwiftUI

/// 桌面输出工作区。预览随当前节点与 UDP 选项即时更新。
struct NodeDetailView: View {
    @Bindable var session: ProxySession
    let node: ProxyNode

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NodeSummary(node: node, isExpanded: $session.detailsExpanded,
                                revealPassword: $session.revealPassword, udpEnabled: $session.udpEnabled)
                    OutputPicker(selection: $session.output)
                    OutputPreview(output: session.output, nodeName: node.name,
                                  image: session.qrImage, yaml: session.yaml, json: session.json, url: session.shareLink)
                }
                .disabled(session.isExporting)
                .frame(width: max(0, min(1000, geometry.size.width - 56)), alignment: .leading)
                .padding(28).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("nodeDetails")
        }
        .background(WorkspaceStyle.background)
        .navigationTitle("输出工作区")
    }
}
