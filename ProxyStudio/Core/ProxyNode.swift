import Foundation

/// 表示一个 SOCKS5 代理节点的连接信息。
///
/// 使用 `parse(_:)` 从分享链接创建节点。解析过程仅处理字符串，不连接服务器，
/// 也不验证账号是否可用。账号信息保存在内存中，并会包含在分享链接与导出配置中。
struct ProxyNode: Equatable, Sendable {
    // MARK: - 节点信息

    /// 节点的显示名称，同时用作分享链接的片段标识符。
    var name: String
    /// 服务器主机名或 IP 地址。解析得到的 IPv6 地址可能包含方括号。
    let host: String
    /// 服务器端口。`parse(_:)` 接受的范围为 `1...65535`。
    let port: Int
    /// 认证用户名。无需认证时为 `nil`。
    let username: String?
    /// 认证密码。无需认证时为 `nil`。
    let password: String?

    /// 用于界面演示和测试的链接，其中的地址与凭据不对应实际代理服务。
    static let exampleLink = "socks://ZGVtbzpleGFtcGxlLXBhc3N3b3Jk@proxy.example.com:1080#%E7%A4%BA%E4%BE%8B%E8%8A%82%E7%82%B9"

    // MARK: - 生成分享链接

    /// 使用 `socks` 协议表示节点的规范化分享链接。
    ///
    /// 当用户名和密码均存在时，将二者以冒号连接后进行 Base64 编码。
    /// 名称及 URL 中需要转义的字符由 `URLComponents` 编码。
    /// 如果无法构造 URL，则返回空字符串。
    ///
    /// - Important: Base64 编码不提供加密保护。此链接包含可恢复的认证信息。
    var shareLink: String {
        var components = URLComponents()
        components.scheme = "socks"
        components.host = host
        components.port = port
        if let username, let password {
            components.user = Data("\(username):\(password)".utf8).base64EncodedString()
        }
        components.fragment = name
        return components.string ?? ""
    }

    // MARK: - 解析分享链接

    /// 解析 SOCKS 分享链接，并检查本工具支持的字段格式。
    ///
    /// 支持 `socks`、`socks5` 协议，以及明文或 Base64 编码的认证字段。
    /// 解析前会移除首尾空白，并还原冒号和 @ 符号前的反斜杠。
    /// 不接受查询参数，也不接受空路径与根路径以外的路径。
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
        guard let url = URLComponents(string: text),
              ["socks", "socks5"].contains(url.scheme?.lowercased() ?? "") else {
            throw ParseError.scheme
        }
        guard let host = url.host, !host.isEmpty,
              !host.contains(where: { $0.isWhitespace }),
              !host.contains("%"), host != "." else { throw ParseError.address }
        guard let port = url.port, (1...65535).contains(port) else { throw ParseError.port }
        guard url.path.isEmpty || url.path == "/", url.query == nil else {
            throw ParseError.unsupportedOptions
        }
        var username: String?
        var password: String?
        if let rawUser = url.percentEncodedUser {
            guard let user = rawUser.removingPercentEncoding else { throw ParseError.credentials }
            if let rawPassword = url.percentEncodedPassword {
                username = user
                password = rawPassword.removingPercentEncoding
            } else {
                // 将 URL 安全 Base64 字母表还原，并补齐可省略的填充字符。
                var encoded = user.replacingOccurrences(of: "-", with: "+")
                    .replacingOccurrences(of: "_", with: "/")
                encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
                guard let data = Data(base64Encoded: encoded),
                      let credentials = String(data: data, encoding: .utf8),
                      let colon = credentials.firstIndex(of: ":") else { throw ParseError.credentials }
                username = String(credentials[..<colon])
                // 仅以第一个冒号分隔账号和密码，保留密码内的其余冒号。
                password = String(credentials[credentials.index(after: colon)...])
            }
            // 长度按 SOCKS5 认证字段的字节数校验，而非按可见字符数校验。
            guard let username, let password,
                  (1...255).contains(username.utf8.count),
                  (1...255).contains(password.utf8.count),
                  !username.contains(":"),
                  !username.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !password.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ParseError.credentials
            }
        }
        let name = (url.fragment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.utf8.count <= 256,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw ParseError.name
        }
        return ProxyNode(name: name.isEmpty ? "SOCKS5 节点" : name,
                         host: host, port: port, username: username, password: password)
    }

    // MARK: - 解析错误

    /// 分享链接不符合受支持格式时产生的错误。
    ///
    /// 错误说明可直接显示在导入界面中；说明文本不包含输入链接或认证信息。
    enum ParseError: LocalizedError {
        // 依次表示空输入、输入过长、协议、地址、端口、认证、附加选项和名称错误。
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
