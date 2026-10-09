import SwiftUI
import UniformTypeIdentifiers


/// 提供链接导入与节点详情导航的根视图。
///
/// 使用分栏导航适应可用窗口宽度。紧凑布局默认显示导入栏，
/// 用户选择解析结果后再进入详情栏。
struct ContentView: View {
    // MARK: - 导入状态

    /// 当前编辑的链接文本。更改输入会使已有解析结果失效。
    @State private var input = ""
    /// 最近一次成功解析的节点；尚未解析或解析失败时为 `nil`。
    @State private var node: ProxyNode?
    /// 当前显示的解析错误；无错误时为 `nil`。
    @State private var parseError: String?
    /// 链接输入框是否持有键盘焦点。
    @FocusState private var isEditing: Bool
    /// 分栏折叠为单栏时优先显示的栏目。初始值为导入栏。
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar

    // MARK: - 视图内容

    /// 根据导入状态构建分栏导航、结果入口和节点详情。
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    importCard
                    if let node {
                        Button {
                            compactColumn = .detail
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title).foregroundStyle(.teal)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(node.name).font(.headline)
                                    Text("\(node.host) · \(node.port)")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("查看二维码与配置").font(.caption).foregroundStyle(.teal)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(20)
                            .background(.background, in: RoundedRectangle(cornerRadius: 24))
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Proxy Studio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空", systemImage: "trash") {
                        input = ""; node = nil; parseError = nil
                    }
                    .disabled(input.isEmpty && node == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isEditing = false }
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
            // 输入变化后立即清除旧节点，避免导出与当前文本不一致的配置。
            .onChange(of: input) { _, _ in node = nil; parseError = nil }
        } detail: {
            if let node {
                NodeDetailView(node: node)
                    // 节点变化时重建详情状态，重置密码可见性、UDP 开关和导出状态。
                    .id(node.shareLink)
            } else {
                ContentUnavailableView("准备好你的下一条连接", systemImage: "qrcode",
                                       description: Text("在导入区粘贴链接并解析，即可预览二维码和导出配置。"))
            }
        }
    }

    /// 展示工具用途的说明区域。
    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 34)).foregroundStyle(.teal)
                .frame(width: 68, height: 68)
                .background(.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)
            Text("一条链接，两种配置。")
                .font(.title2.bold())
            Text("将 SOCKS 节点转换为 Shadowrocket 二维码或 Clash 配置文件。")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    /// 包含粘贴、输入、错误说明及解析操作的导入区域。
    private var importCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("导入节点", systemImage: "link").font(.headline)
                Spacer()
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { input = first }
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("粘贴代理链接")
            }
            TextField("socks://账号信息@服务器:端口#名称", text: $input, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(4...7)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($isEditing)
                .padding(14)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("SOCKS 代理链接")
                .accessibilityIdentifier("proxyLinkInput")
            if let parseError {
                Label(parseError, systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("parseError")
            }
            Button(action: parse) {
                Text("解析链接").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("parseButton")
            Button("试用示例节点") {
                input = ProxyNode.exampleLink
            }
            .font(.subheadline)
            Text("支持 socks://、socks5:// 及转义链接；可识别 Base64 或明文账号。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - 用户操作

    /// 结束文本编辑，并用当前输入更新解析结果或错误说明。
    ///
    /// 成功时保留节点并清除错误；失败时清除节点并显示本地化错误说明。
    /// 此操作不主动切换紧凑布局中显示的栏目。
    private func parse() {
        isEditing = false
        do {
            node = try ProxyNode.parse(input)
            parseError = nil
        } catch {
            node = nil
            parseError = error.localizedDescription
        }
    }
}

#Preview { ContentView() }
