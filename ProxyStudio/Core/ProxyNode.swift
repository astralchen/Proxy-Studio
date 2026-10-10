import Foundation

/// 表示一个 SOCKS5 代理节点的连接信息。
///
/// 使用 `parse(_:)` 从分享链接创建节点。解析过程仅处理字符串，不连接服务器，
/// 也不验证账号是否可用。账号信息保存在内存中，并会包含在分享链接与导出配置中。
struct ProxyNode: Equatable, Sendable {
    // MARK: - 节点信息

    /// 节点的显示名称，同时用作 Shadowrocket 分享链接的 `remarks` 参数。
    var name: String
    /// 服务器主机名或 IP 地址。解析得到的 IPv6 地址可能包含方括号。
    let host: String
    /// 服务器端口。`parse(_:)` 接受的范围为 `1...65535`。
    let port: Int
    /// 认证用户名。无需认证时为 `nil`。
    let username: String?
    /// 认证密码。无需认证时为 `nil`。
    let password: String?
    /// 分享链接携带的 UDP 初始选项；未提供时为 `false`。
    var udpEnabled = false

    /// 用于界面演示和测试的链接，其中的地址与凭据不对应实际代理服务。
    static let exampleLink = "socks://ZGVtbzpleGFtcGxlLXBhc3N3b3Jk@proxy.example.com:1080#%E7%A4%BA%E4%BE%8B%E8%8A%82%E7%82%B9"

    // MARK: - 生成分享链接

    /// 使用节点的 UDP 初始选项生成 Shadowrocket 分享链接。
    /// - Important: Base64 编码不提供加密保护。此链接包含可恢复的认证信息。
    var shareLink: String { shadowrocketLink(udpEnabled: udpEnabled) }

    /// 将完整连接信息编码为 Base64，并通过查询参数携带名称与 UDP。
    ///
    /// - Parameter udpEnabled: 当前导出选项；不会修改节点的初始状态。
    /// - Returns: 与 Shadowrocket 导出样本相同结构的 `socks` 链接。
    /// - Important: 凭据保留原始 UTF-8 字符；只对 `remarks` 进行 URL 百分号编码。
    func shadowrocketLink(udpEnabled: Bool) -> String {
        let address = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let endpoint = "\(address.contains(":") ? "[\(address)]" : address):\(port)"
        let credentials = username.flatMap { user in password.map { "\(user):\($0)@" } } ?? ""
        let encoded = Data((credentials + endpoint).utf8).base64EncodedString()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let remarks = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return "socks://\(encoded)?remarks=\(remarks)&udp=\(udpEnabled ? 1 : 0)"
    }

    // MARK: - 解析分享链接

    /// 解析 SOCKS 分享链接，并检查本工具支持的字段格式。
    ///
    /// 支持 `socks`、`socks5` 协议，以及明文或 Base64 编码的认证字段。
    /// 解析前会移除首尾空白，并还原冒号和 @ 符号前的反斜杠。
    /// 同时接受 Shadowrocket 完整连接信息 Base64 格式及 `remarks`、`udp=0/1`。
    /// 不接受其他查询参数，也不接受空路径与根路径以外的路径。
    ///
    /// - Parameter input: 单条分享链接。预处理后最多允许 4096 个 UTF-8 字节。
    /// - Returns: 通过格式校验的节点。名称为空时使用“SOCKS5 节点”。
    /// - Throws: 字段不符合要求时抛出对应的 `ParseError`。
    /// - Note: 格式校验不包含 DNS 解析、连通性检查或服务器认证。
    static func parse(_ input: String) throws -> ProxyNode {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\:", with: ":")
            .replacingOccurrences(of: "\\@", with: "@")
        guard !text.isEmpty else { throw ParseError.empty }
        guard text.utf8.count <= 4096 else { throw ParseError.tooLong }
        guard let separator = text.range(of: "://"),
              ["socks", "socks5"].contains(text[..<separator.lowerBound].lowercased()) else {
            throw ParseError.scheme
        }
        let body = text[separator.upperBound...]
        let suffixIndex = body.firstIndex(where: { $0 == "?" || $0 == "#" }) ?? body.endIndex
        let authority = String(body[..<suffixIndex])
        let suffix = String(body[suffixIndex...])
        var packedCredentials: (String, String)?
        var normalized = text
        // Base64 的标准字母表可包含 /，因此必须先解码完整连接信息，再交给 URLComponents。
        if !authority.contains("@"), let endpoint = decodeBase64(authority) {
            var address = endpoint
            if let at = endpoint.lastIndex(of: "@") {
                let credentials = endpoint[..<at]
                guard let colon = credentials.firstIndex(of: ":") else { throw ParseError.credentials }
                packedCredentials = (String(credentials[..<colon]), String(credentials[credentials.index(after: colon)...]))
                address = String(endpoint[endpoint.index(after: at)...])
            }
            guard !address.contains(where: { "/?#@".contains($0) || $0.isWhitespace }),
                  !address.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ParseError.address
            }
            normalized = "socks://" + address + suffix
        }
        // 先转义原始 Unicode，同时保留已有的 %HH，避免 Foundation 将混合名称中的 % 再次编码。
        let uriCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%")
        guard let encodedURL = normalized.addingPercentEncoding(withAllowedCharacters: uriCharacters),
              let url = URLComponents(string: encodedURL) else { throw ParseError.address }
        guard let host = url.host, !host.isEmpty,
              !host.contains(where: { $0.isWhitespace }),
              !host.contains("%"), host != "." else { throw ParseError.address }
        guard let port = url.port, (1...65535).contains(port) else { throw ParseError.port }
        guard url.path.isEmpty || url.path == "/" else {
            throw ParseError.unsupportedOptions
        }
        let items = url.queryItems ?? []
        guard items.allSatisfy({ ["remarks", "udp"].contains($0.name) && $0.value != nil }),
              Set(items.map(\.name)).count == items.count,
              url.query == nil || !items.isEmpty else { throw ParseError.unsupportedOptions }
        let udp = items.first(where: { $0.name == "udp" })?.value
        guard udp == nil || udp == "0" || udp == "1" else { throw ParseError.unsupportedOptions }
        let remarks = items.first(where: { $0.name == "remarks" })?.value
        guard remarks == nil || url.fragment == nil else { throw ParseError.unsupportedOptions }
        var username = packedCredentials?.0
        var password = packedCredentials?.1
        if let rawUser = url.percentEncodedUser {
            guard let user = rawUser.removingPercentEncoding else { throw ParseError.credentials }
            if let rawPassword = url.percentEncodedPassword {
                username = user
                password = rawPassword.removingPercentEncoding
            } else {
                guard let credentials = decodeBase64(user),
                      let colon = credentials.firstIndex(of: ":") else { throw ParseError.credentials }
                username = String(credentials[..<colon])
                // 仅以第一个冒号分隔账号和密码，保留密码内的其余冒号。
                password = String(credentials[credentials.index(after: colon)...])
            }
        }
        if username != nil || password != nil {
            // 两种链接格式共用认证校验，长度按 SOCKS5 字节数计算。
            guard let username, let password,
                  (1...255).contains(username.utf8.count),
                  (1...255).contains(password.utf8.count),
                  !username.contains(":"),
                  !username.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !password.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ParseError.credentials
            }
        }
        let name = (remarks ?? url.fragment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.utf8.count <= 256,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw ParseError.name
        }
        return ProxyNode(name: name.isEmpty ? "SOCKS5 节点" : name,
                         host: host, port: port, username: username, password: password, udpEnabled: udp == "1")
    }

    /// 使用标准或 URL 安全 Base64 字母表解码 UTF-8 文本。
    ///
    /// - Parameter text: 可省略末尾填充字符的 Base64 文本。
    /// - Returns: 解码后的文本；Base64 无效或字节不是有效 UTF-8 时为 `nil`。
    private static func decodeBase64(_ text: String) -> String? {
        var encoded = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - 解析错误

    /// 分享链接不符合受支持格式时产生的错误。
    ///
    /// 错误说明可直接显示在导入界面中；说明文本不包含输入链接或认证信息。
    enum ParseError: LocalizedError {
        /// 输入为空、超过字节上限，或协议、地址、端口、认证、附加选项、名称不受支持。
        case empty, tooLong, scheme, address, port, credentials, unsupportedOptions, name

        /// 面向用户的中文错误说明。
        var errorDescription: String? {
            switch self {
            case .empty: "请先粘贴一条 SOCKS 链接。"
            case .tooLong: "链接过长，请检查是否粘贴了多条链接。"
            case .scheme: "支持 socks:// 和 socks5:// 链接。"
            case .address: "服务器地址无效，请检查主机名或 IP 地址。"
            case .port: "请输入 1–65535 之间的端口号。"
            case .credentials: "账号信息无效。请使用 Base64 编码的账号:密码，或 username:password 格式；每项限 1–255 字节，账号不能包含冒号。"
            case .unsupportedOptions: "链接包含暂不支持的路径或查询参数，请确认配置后移除。"
            case .name: "节点名称过长或包含无效字符。"
            }
        }
    }
}
