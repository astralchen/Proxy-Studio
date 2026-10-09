import SwiftUI
import UniformTypeIdentifiers


/// 提供链接导入与节点详情导航的根视图。
///
/// 使用分栏导航适应可用窗口宽度。紧凑布局默认显示导入栏，
/// 成功解析后自动显示输出栏，返回后保留会话。
struct ContentView: View {
    /// 会话由根视图持有，返回与布局变化不会重建输出状态。
    @State private var session = ProxySession()
    @FocusState private var isEditing: Bool
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - 视图内容

    /// 根据导入状态构建分栏导航、结果入口和节点详情。
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ImportIntroduction()
                    importCard
                    if let node = session.node {
                        Button {
                            compactColumn = .detail
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title).foregroundStyle(.teal)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(node.name).font(.headline)
                                    Text("\(node.host) · \(String(node.port))")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("查看二维码与配置").font(.caption).foregroundStyle(.teal)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(20)
                            .background(WorkspaceStyle.surface, in: RoundedRectangle(cornerRadius: 24))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("nodeResult")
                    }
                    Label("链接仅在本机解析。二维码和导出文件包含账号信息，请妥善保存。", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 680)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("importScroll")
            .background(WorkspaceStyle.background)
            .navigationTitle("Proxy Studio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空", systemImage: "trash") {
                        session.clear()
                    }
                    .disabled(!session.canClear)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isEditing = false }
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)

        } detail: {
            if let node = session.node {
                NodeDetailView(session: session, node: node)
            } else {
                WorkspaceEmptyView()
            }
        }
        .fileExporter(isPresented: $session.isExporting, document: session.exportDocument,
                      contentTypes: [session.exportType], defaultFilename: session.exportName,
                      onCompletion: { session.finishExport($0) }, onCancellation: { session.cancelExport() })
        .alert("导出", isPresented: Binding(get: { session.message != nil },
                                           set: { if !$0 { session.message = nil } })) {
            Button("好") { session.message = nil }
        } message: { Text(session.message ?? "") }
    }

    /// 包含粘贴、输入、错误说明及解析操作的导入区域。
    private var importCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) { importHeading; pasteButton }
            } else {
                HStack { importHeading; Spacer(); pasteButton }
            }
            TextField("socks://账号信息@服务器:端口#名称", text: $session.input, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(4...7)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($isEditing)
                .disabled(session.isExporting)
                .padding(14)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("SOCKS 代理链接")
                .accessibilityIdentifier("proxyLinkInput")
            if let parseError = session.parseError {
                Label(parseError, systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("parseError")
            }
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: parse) {
                        Text("解析链接").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!session.canParse)
                    .accessibilityIdentifier("parseButton")
                    Button("试用示例节点") {
                        session.input = ProxyNode.exampleLink
                    }
                    .buttonStyle(.glass)
                    .font(.subheadline)
                    .disabled(session.isExporting)
                }
            }
            Text("支持 socks://、socks5:// 及转义链接；可识别 Base64 或明文账号。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(WorkspaceStyle.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var importHeading: some View {
        Label("导入节点", systemImage: "link").font(.headline)
    }

    private var pasteButton: some View {
        PasteButton(payloadType: String.self) { strings in
            if let first = strings.first { session.input = first }
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("粘贴代理链接")
        .disabled(session.isExporting)
    }

    // MARK: - 用户操作

    /// 结束文本编辑，并用当前输入更新解析结果或错误说明。
    ///
    /// 成功时保留节点并清除错误；失败时清除节点并显示本地化错误说明。
    /// 成功后自动进入紧凑布局的输出栏目。
    private func parse() {
        isEditing = false
        session.parse()
        if session.node != nil { compactColumn = .detail }
    }
}

#Preview { ContentView() }
