import Foundation

/// 工作区支持的输出格式。顺序与 Mac 的 ⌘1、⌘2、⌘3 快捷键一致。
enum OutputFormat: String, CaseIterable, Identifiable {
    case qr = "二维码"
    case yaml = "Clash YAML"
    case json = "Shadowrocket JSON"

    var id: Self { self }
    var compactTitle: String {
        switch self { case .qr: "二维码"; case .yaml: "YAML"; case .json: "JSON" }
    }
    var exportTitle: String {
        switch self { case .qr: "保存 PNG"; case .yaml: "导出 YAML"; case .json: "导出 JSON" }
    }
    var exportIdentifier: String {
        switch self { case .qr: "exportPNG"; case .yaml: "exportYAML"; case .json: "exportJSON" }
    }
}
