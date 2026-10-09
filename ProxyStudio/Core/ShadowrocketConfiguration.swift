import Foundation

/// 根据单个 SOCKS5 节点生成 Shadowrocket 单节点 JSON 文件。
///
/// 字段及类型遵循单节点导出格式。身份与时间由调用方持有，重复编码不生成新元数据。
/// 本类型只生成文件内容，不连接代理服务器，也不推断地区或测速结果。
struct ShadowrocketConfiguration: Sendable {
    /// 要导出的代理节点。
    let node: ProxyNode
    /// 是否启用 UDP。默认值为 `false`。
    var udpEnabled = false
    /// 当前节点的稳定标识。
    let identifier: UUID
    /// 当前节点成功解析的时间，同时用作初始创建和更新时间。
    let createdAt: Date

    /// 编码一个包含 41 个字段的 JSON 对象。
    ///
    /// - Returns: UTF-8 JSON，包含缩进、排序键和末尾换行。
    /// - Throws: 时间无法编码或 JSON 编码失败时抛出编码错误。
    /// - Important: 返回的数据以明文包含节点的账号和密码。
    func encodedJSON() throws -> Data {
        let timestamp = createdAt.timeIntervalSince1970
        guard timestamp.isFinite, timestamp >= 0, timestamp < Double(Int.max) else {
            throw EncodingError.invalidValue(createdAt, .init(codingPath: [], debugDescription: "节点时间无法编码。"))
        }
        let record = Record(
            host: node.host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")),
            created: timestamp, updated: timestamp, uuid: identifier.uuidString,
            user: node.username ?? "", udp: udpEnabled ? 1 : 0, port: String(node.port),
            weight: Int(timestamp), title: node.name, password: node.password ?? ""
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(record)
        data.append(0x0A)
        return data
    }

    /// 明确声明单节点格式中的字段类型；未使用的协议选项保留为空字符串。
    private struct Record: Encodable {
        let host: String
        let obfsParam = ""
        let alpn = ""
        let cert = ""
        let created: Double
        let updated: Double
        let mode = ""
        let mtu = ""
        let flag = ""
        let tlsProfile = ""
        let ping = 0
        let hpkp = ""
        let uuid: String
        let path = ""
        let downmbps = ""
        let type = "Socks5"
        let privateKey = ""
        let user: String
        let ech = ""
        let plugin = ""
        let method = ""
        let data = ""
        let udp: Int
        let filter = ""
        let protoParam = ""
        let reserved = ""
        let alterId = ""
        let upmbps = ""
        let keepalive = ""
        let port: String
        let obfs = "none"
        let dns = ""
        let publicKey = ""
        let peer = ""
        let weight: Int
        let title: String
        let proto = "none"
        let password: String
        let shortId = ""
        let chain = ""
        let ip = ""
    }
}
