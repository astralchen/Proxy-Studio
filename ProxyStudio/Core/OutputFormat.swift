import Foundation

/// 工作区支持的输出格式。顺序与 Mac 的 ⌘1 至 ⌘4 快捷键一致。
enum OutputFormat: String, CaseIterable, Identifiable {
    case qr = "二维码"
    case yaml = "Clash YAML"
    case json = "Shadowrocket JSON"
    case url = "Shadowrocket URL"

    var id: Self { self }
    var compactTitle: String {
        switch self { case .qr: "二维码"; case .yaml: "YAML"; case .json: "JSON"; case .url: "URL" }
    }
    var exportTitle: String {
        switch self { case .qr: "保存 PNG"; case .yaml: "导出 YAML"; case .json: "导出 JSON"; case .url: "导出 URL" }
    }
    var exportIdentifier: String {
        switch self { case .qr: "exportPNG"; case .yaml: "exportYAML"; case .json: "exportJSON"; case .url: "exportURL" }
    }
}
