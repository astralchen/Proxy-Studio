import SwiftUI
import UIKit

/// 即时输出工作区；导航返回不会清除根视图持有的会话。
struct NodeDetailView: View {
    @Bindable var session: ProxySession
    let node: ProxyNode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsShareOptions = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NodeSummary(node: node, isExpanded: $session.detailsExpanded,
                                revealPassword: $session.revealPassword, udpEnabled: $session.udpEnabled)
                        .disabled(session.isExporting)
                    OutputPicker(selection: $session.output).disabled(session.isExporting)
                    // 只按内容宽度约束图片；导航栏随滚动改变高度时，二维码尺寸保持稳定。
                    OutputPreview(output: session.output, nodeName: node.name,
                                  image: session.qrImage, yaml: session.yaml, json: session.json)
                }
                .frame(maxWidth: 1000).padding(20).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("nodeDetails")
            .clipped()
            actions
        }
        .background(WorkspaceStyle.background)
        .navigationTitle("输出工作区")
        .navigationBarTitleDisplayMode(.inline)
        .popover(isPresented: $showsShareOptions) {
            shareOptions
                .padding(20)
                .presentationCompactAdaptation(.popover)
        }
        .task(id: session.copyFeedback) {
            guard session.copyFeedback != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            session.copyFeedback = nil
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if let feedback = session.copyFeedback {
                Text(feedback).font(.caption).accessibilityIdentifier("copyFeedback")
            }
            GlassEffectContainer(spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: 16) { buttons }.fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(spacing: 12) { buttons }
                }
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    @ViewBuilder
    private var buttons: some View {
        Button(session.output.exportTitle, systemImage: "square.and.arrow.down") { session.exportCurrent() }
            .buttonStyle(.glassProminent)
            .disabled(!session.canExportCurrent)
            .accessibilityIdentifier(session.output.exportIdentifier)
        if session.output == .qr {
            Button {
                showsShareOptions = true
            } label: {
                HStack(spacing: 8) {
                    Label("分享", systemImage: "square.and.arrow.up")
                    Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
                }
            }
            .buttonStyle(.glass).foregroundStyle(WorkspaceStyle.foregroundAccent)
            .disabled(!session.canUseOutput)
            .accessibilityIdentifier("shareMenu")
        } else {
            Button("复制文本", systemImage: "doc.on.doc") {
                guard let text = session.outputText else { return }
                UIPasteboard.general.string = text
                session.copyFeedback = "已复制。"
                UIAccessibility.post(notification: .announcement, argument: "已复制。")
            }
            .buttonStyle(.glass).foregroundStyle(WorkspaceStyle.foregroundAccent)
            .disabled(!session.canUseOutput || session.outputText == nil)
            .accessibilityIdentifier("copyOutput")
        }
    }
    /// 标准 popover 中直接提供系统分享入口，避免菜单跟踪阻塞呈现。
    private var shareOptions: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let image = session.qrImage, let data = image.pngData() {
                ShareLink(item: PNGShareItem(data: data),
                          preview: SharePreview(node.name, image: Image(uiImage: UIImage(cgImage: image.cgImage)))) {
                    Label("分享图片", systemImage: "photo")
                }
                .accessibilityIdentifier("sharePNG")
            } else {
                Button("分享图片", systemImage: "photo") {}.disabled(true)
            }
            ShareLink(item: session.shareLink) { Label("分享导入链接", systemImage: "link") }
                .accessibilityIdentifier("shareLink")
        }
        .buttonStyle(.plain)
    }

}
