import XCTest
import CoreFoundation
@testable import ProxyStudio

/// 验证单节点 JSON 的字段、类型及确定性；所有凭据均为虚构数据。
final class ShadowrocketConfigurationTests: XCTestCase {
    /// 固定节点身份，避免随机 UUID 影响编码结果比较。
    private let identifier = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    /// 包含小数秒的固定时间，用于验证时间类型及权重的整数截取。
    private let createdAt = Date(timeIntervalSince1970: 1_791_426_634.125)

    /// 验证完整的 41 键集合及字段类型，包括整数与布尔值的区别。
    func testCompleteObjectSchemaAndFieldTypes() throws {
        let node = try ProxyNode.parse(ProxyNode.exampleLink)
        let data = try configuration(node).encodedJSON()
        let object = try object(data)
        let emptyKeys = ["obfsParam", "alpn", "cert", "mode", "mtu", "flag", "tlsProfile", "hpkp", "path",
                         "downmbps", "privateKey", "ech", "plugin", "method", "data", "filter", "protoParam",
                         "reserved", "alterId", "upmbps", "keepalive", "dns", "publicKey", "peer", "shortId", "chain", "ip"]
        let valueKeys = ["host", "created", "updated", "uuid", "ping", "type", "user", "udp", "port", "obfs",
                         "weight", "title", "proto", "password"]
        XCTAssertEqual(Set(object.keys), Set(emptyKeys + valueKeys))
        XCTAssertEqual(object.count, 41)
        for key in emptyKeys { XCTAssertEqual(object[key] as? String, "", key) }
        for key in ["host", "uuid", "type", "user", "port", "obfs", "title", "proto", "password"] {
            XCTAssertTrue(object[key] is String, key)
        }
        for key in ["udp", "ping", "weight", "created", "updated"] {
            let number = try XCTUnwrap(object[key] as? NSNumber, key)
            XCTAssertNotEqual(CFGetTypeID(number), CFBooleanGetTypeID(), key)
            let isFloatingPoint = ["d", "f"].contains(String(cString: number.objCType))
            XCTAssertEqual(isFloatingPoint, ["created", "updated"].contains(key), key)
        }
        XCTAssertEqual(object["type"] as? String, "Socks5")
        XCTAssertEqual(object["port"] as? String, "1080")
        XCTAssertEqual(object["user"] as? String, "demo")
        XCTAssertEqual(object["password"] as? String, "example-password")
        XCTAssertEqual(object["title"] as? String, node.name)
        XCTAssertEqual(object["obfs"] as? String, "none")
        XCTAssertEqual(object["proto"] as? String, "none")
        XCTAssertEqual(object["ping"] as? Int, 0)
        XCTAssertEqual(object["weight"] as? Int, 1_791_426_634)
        XCTAssertEqual(object["created"] as? Double, createdAt.timeIntervalSince1970)
        XCTAssertEqual(object["updated"] as? Double, createdAt.timeIntervalSince1970)
        XCTAssertEqual(object["uuid"] as? String, identifier.uuidString)
    }

    /// 验证免认证节点、地址格式和端口边界，IPv6 输出不携带外层方括号。
    func testUnauthenticatedAddressesAndPortBoundaries() throws {
        for (link, host, port) in [("socks://192.0.2.1:1", "192.0.2.1", "1"),
                                  ("socks://proxy.example.com:65535", "proxy.example.com", "65535"),
                                  ("socks://[2001:db8::1]:1080", "2001:db8::1", "1080")] {
            let output = try object(configuration(ProxyNode.parse(link)).encodedJSON())
            XCTAssertEqual(output["host"] as? String, host)
            XCTAssertEqual(output["port"] as? String, port)
            XCTAssertEqual(output["user"] as? String, "")
            XCTAssertEqual(output["password"] as? String, "")
        }
    }

    /// 验证中文、引号、反斜杠与特殊凭据经 JSON 编码后可完整还原。
    func testUnicodeAndCredentialEscapingRoundTrip() throws {
        let node = ProxyNode(name: "中文 \"节点\" / \\ DIRECT", host: "proxy.example.com", port: 1080,
                             username: "虚构\"用户\\", password: "示例:p@ss/\"\\🔑")
        let output = try object(configuration(node).encodedJSON())
        XCTAssertEqual(output["title"] as? String, node.name)
        XCTAssertEqual(output["user"] as? String, node.username)
        XCTAssertEqual(output["password"] as? String, node.password)
    }

    /// 验证 UDP 使用整数 0/1，切换时保持 UUID、时间和权重。
    func testUDPUsesIntegersAndPreservesMetadata() throws {
        var config = configuration(try ProxyNode.parse(ProxyNode.exampleLink))
        let disabled = try object(config.encodedJSON())
        config.udpEnabled = true
        let enabled = try object(config.encodedJSON())
        XCTAssertEqual(disabled["udp"] as? Int, 0)
        XCTAssertEqual(enabled["udp"] as? Int, 1)
        for key in ["uuid", "created", "updated", "weight"] {
            XCTAssertEqual(disabled[key] as? NSObject, enabled[key] as? NSObject, key)
        }
    }

    /// 验证相同输入的字节确定性、缩进、排序键、末尾换行及 JSON 文档类型。
    func testRepeatedEncodingIsStableAndFormatted() throws {
        let config = configuration(try ProxyNode.parse(ProxyNode.exampleLink))
        let first = try config.encodedJSON()
        XCTAssertEqual(first, try config.encodedJSON())
        XCTAssertEqual(first.last, 10)
        let text = String(decoding: first, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("{\n"))
        XCTAssertTrue(text.contains("  \"host\""))
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "\"alpn\"")).lowerBound,
                          try XCTUnwrap(text.range(of: "\"host\"")).lowerBound)
        XCTAssertTrue(ExportDocument.readableContentTypes.contains(.json))
    }

    /// 验证非有限、负值及超出整数范围的时间抛出错误，避免 weight 转换崩溃。
    func testInvalidTimestampThrowsWithoutIntegerConversionTrap() throws {
        let node = try ProxyNode.parse(ProxyNode.exampleLink)
        for value in [Double.nan, .infinity, -1, Double(Int.max)] {
            let config = ShadowrocketConfiguration(node: node, identifier: identifier,
                                                   createdAt: Date(timeIntervalSince1970: value))
            XCTAssertThrowsError(try config.encodedJSON())
        }
    }

    /// 使用固定 UUID 和时间创建配置，使重复编码结果可直接比较。
    /// - Parameter node: 使用虚构凭据的测试节点。
    /// - Returns: 默认关闭 UDP 的单节点配置。
    private func configuration(_ node: ProxyNode) -> ShadowrocketConfiguration {
        ShadowrocketConfiguration(node: node, identifier: identifier, createdAt: createdAt)
    }

    /// 独立解析 JSON 并要求顶层为对象，用于检查编码器的输出契约。
    /// - Parameter data: 待验证的 JSON 字节。
    /// - Returns: 解析后的字段字典。
    /// - Throws: JSON 无效或顶层类型不符合预期时产生测试错误。
    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
