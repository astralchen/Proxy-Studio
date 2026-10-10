import Foundation

/// 工作区支持的输出格式。顺序与 Mac 的 ⌘1 至 ⌘4 快捷键一致。
enum OutputFormat: String, CaseIterable, Identifiable {
    /// 将规范化分享链接编码为二维码，可保存为 PNG 或分享图片和链接。
    case qr = "二维码"
    /// 生成包含单节点、策略组及全局匹配规则的 Clash 配置。
    case yaml = "Clash YAML"
    /// 生成携带稳定节点身份和创建时间的 Shadowrocket 单节点对象。
    case json = "Shadowrocket JSON"
    /// 显示与二维码载荷一致的规范化链接，并按原始 UTF-8 字节保存。
    case url = "Shadowrocket URL"

    // MARK: - 界面标识

    /// 格式本身的稳定标识，用于枚举列表和选择器。
    var id: Self { self }
    /// 宽度不足时使用的简写；辅助功能名称仍使用完整的 `rawValue`。
    var compactTitle: String {
        switch self { case .qr: "二维码"; case .yaml: "YAML"; case .json: "JSON"; case .url: "URL" }
    }
    /// 当前格式对应的保存按钮标题。
    var exportTitle: String {
        switch self { case .qr: "保存 PNG"; case .yaml: "导出 YAML"; case .json: "导出 JSON"; case .url: "导出 URL" }
    }
    /// 当前格式保存按钮的辅助功能标识，供两端界面及 UI 测试共用。
    var exportIdentifier: String {
        switch self { case .qr: "exportPNG"; case .yaml: "exportYAML"; case .json: "exportJSON"; case .url: "exportURL" }
    }
}
