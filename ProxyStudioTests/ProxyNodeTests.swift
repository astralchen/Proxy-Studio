import XCTest
import Vision
import ImageIO
import CoreImage
@testable import ProxyStudio

/// 验证链接解析、配置序列化与二维码内容的一致性。
final class ProxyNodeTests: XCTestCase {
    // MARK: - 链接解析

    /// 验证内置 Base64 示例可还原全部节点字段。
    func testBase64Example() throws {
        let node = try ProxyNode.parse(ProxyNode.exampleLink)
        XCTAssertEqual(node.name, "示例节点")
        XCTAssertEqual(node.host, "proxy.example.com")
        XCTAssertEqual(node.username, "demo")
        XCTAssertEqual(node.password, "example-password")
        XCTAssertEqual(node.port, 1080)
    }

    /// 使用独立的虚构契约样本验证整体 Base64、remarks 和 UDP 类型。
    func testShadowrocketLinkContract() throws {
        let node = try ProxyNode.parse(ProxyNode.exampleLink)
        let expected = "socks://" + Data("demo:example-password@proxy.example.com:1080".utf8).base64EncodedString()
            + "?remarks=%E7%A4%BA%E4%BE%8B%E8%8A%82%E7%82%B9&udp=1"
        XCTAssertEqual(node.shadowrocketLink(udpEnabled: true), expected)
        let parsed = try ProxyNode.parse(expected)
        XCTAssertEqual(parsed.name, node.name)
        XCTAssertEqual(parsed.host, node.host)
        XCTAssertEqual(parsed.port, node.port)
        XCTAssertEqual(parsed.username, node.username)
        XCTAssertEqual(parsed.password, node.password)
        XCTAssertTrue(parsed.udpEnabled)
        XCTAssertEqual(parsed.shareLink, expected)
        XCTAssertFalse(try ProxyNode.parse(node.shareLink).udpEnabled)
    }

    /// 验证完整连接信息中的特殊凭据与查询名称不会被二次转义或错误拆分。
    func testShadowrocketSpecialCharactersAndAddressBoundaries() throws {
        for (host, port) in [("proxy.example.com", 1), ("127.0.0.1", 65535), ("[2001:db8::1]", 1080)] {
            for authenticated in [false, true] {
                let node = ProxyNode(name: "中文 +&?#=\"\\节点", host: host, port: port,
                                     username: authenticated ? "用@户/名%+" : nil,
                                     password: authenticated ? "密:码@?/#%+\"\\" : nil, udpEnabled: true)
                XCTAssertEqual(try ProxyNode.parse(node.shareLink), node)
                XCTAssertEqual(try ProxyNode.parse(node.shareLink).shareLink, node.shareLink)
                XCTAssertFalse(node.shareLink.contains("#"))
                XCTAssertTrue(node.shareLink.contains("%2B%26%3F%23%3D"))
            }
        }
    }

    /// 保留 Base64URL 输入兼容性，并拒绝重复、冲突或未知连接选项。
    func testShadowrocketBase64URLAndInvalidOptions() throws {
        let encoded = Data("user:pass?~@[2001:db8::2]:65535".utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let base = "socks5://" + encoded
        let node = try ProxyNode.parse(base + "?remarks=中文%2B节点&udp=1")
        XCTAssertEqual(node.name, "中文+节点")
        XCTAssertEqual(node.password, "pass?~")
        XCTAssertTrue(node.udpEnabled)
        XCTAssertFalse(try ProxyNode.parse(base).udpEnabled)
        XCTAssertEqual(try ProxyNode.parse(base + "?remarks=").name, "SOCKS5 节点")
        for suffix in ["?tls=true", "?udp=true", "?udp=2", "?udp=", "?udp", "?udp=0&udp=1",
                       "?remarks=a&remarks=b", "?remarks=a#b", "?", "?remarks=bad%0Aname"] {
            XCTAssertThrowsError(try ProxyNode.parse(base + suffix))
        }
        for endpoint in ["user:@host:1080", ":pass@host:1080", "user:pass@host:0", "host:65536",
                         "user:pass@host:1080/path", "user:pass@bad host:1080", "user:pass\n@host:1080"] {
            XCTAssertThrowsError(try ProxyNode.parse("socks://" + Data(endpoint.utf8).base64EncodedString()))
        }
    }

    /// 验证转义的冒号和 @ 符号不改变链接的解析结果。
    func testEscapedLink() throws {
        let link = ProxyNode.exampleLink.replacingOccurrences(of: "://", with: "\\://")
            .replacingOccurrences(of: "@", with: "\\@")
        XCTAssertEqual(try ProxyNode.parse(link), try ProxyNode.parse(ProxyNode.exampleLink))
    }

    /// 验证明文凭据中的转义字符可保留，并可通过分享链接完成往返转换。
    func testPlainCredentialsAndRoundTrip() throws {
        let node = try ProxyNode.parse("socks5://user:p%40ss%3Aword%23%5C@127.0.0.1:1080#%E6%B5%8B%E8%AF%95")
        XCTAssertEqual(node.password, "p@ss:word#\\")
        XCTAssertEqual(try ProxyNode.parse(node.shareLink), node)
    }

    /// 验证解析器接受省略填充字符的 URL 安全 Base64 凭据。
    func testBase64URLSafeWithoutPadding() throws {
        let credentials = "user:pass?~" // 解析器同时兼容标准与 URL 安全 Base64 字母表。
        let encoded = Data(credentials.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(try ProxyNode.parse("socks://\(encoded)@localhost:1080").password, "pass?~")
    }

    /// 验证免认证 IPv6 链接的往返转换及 YAML 地址格式。
    func testIPv6WithoutAuthentication() throws {
        let node = try ProxyNode.parse("socks5://[2001:db8::1]:1080")
        XCTAssertNil(node.username)
        XCTAssertEqual(try ProxyNode.parse(node.shareLink), node)
        XCTAssertTrue(ClashConfiguration(node: node).yaml.contains("server: \"2001:db8::1\""))
        XCTAssertFalse(ClashConfiguration(node: node).yaml.contains("username:"))
    }

    /// 验证无效协议、端口、凭据、路径、查询参数及控制字符均被拒绝。
    func testRejectMalformedInputs() {
        for link in ["", "https://example.com:1080", "socks://host", "socks://host:0",
                     "socks://host:65536", "socks://bad@host:1080", "socks://:pass@host:1080",
                     "socks://user:@host:1080", "socks://host:1080/path", "socks://host:1080?tls=true",
                     "socks://host:1080#bad%0Aname", "socks://user:pass%00@host:1080"] {
            XCTAssertThrowsError(try ProxyNode.parse(link), "Accepted invalid link: \(link)")
        }
    }

    // MARK: - 配置与二维码

    /// 验证 YAML 字符转义、名称冲突处理及 UDP 选项的输出。
    func testYAMLQuotesAndReservedNames() throws {
        var node = try ProxyNode.parse("socks://user:p%22ass%5Cword@localhost:1080#DIRECT")
        let yaml = ClashConfiguration(node: node, udpEnabled: true).yaml
        XCTAssertTrue(yaml.contains("name: \"DIRECT · SOCKS5\""))
        XCTAssertTrue(yaml.contains("      - \"DIRECT · SOCKS5\""))
        XCTAssertTrue(yaml.contains("password: \"p\\\"ass\\\\word\""))
        XCTAssertTrue(yaml.contains("udp: true"))
        node.name = "代理选择"
        XCTAssertTrue(ClashConfiguration(node: node).yaml.contains("name: \"代理选择 · SOCKS5\""))
    }

    /// 使用 Vision 回读二维码，验证图片中的载荷与分享链接完全一致。
    @MainActor
    func testQRCodeRoundTrip() throws {
        let node = try ProxyNode.parse(ProxyNode.exampleLink)
        let image = try XCTUnwrap(QRCodeRenderer.image(for: node.shareLink))
        let png = try XCTUnwrap(image.pngData())
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        // 部分模拟器运行时未提供最新 Vision 模型，指定较早的修订版本进行回读。
        request.revision = VNDetectBarcodesRequestRevision1
        request.usesCPUOnly = true
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        XCTAssertEqual(request.results?.first?.payloadStringValue, node.shareLink)
        let descriptor = try XCTUnwrap(request.results?.first?.barcodeDescriptor as? CIQRCodeDescriptor)
        XCTAssertEqual(descriptor.errorCorrectionLevel, .levelH)
        XCTAssertGreaterThan(cgImage.width, 200)
        XCTAssertEqual(cgImage.width, cgImage.height)
        XCTAssertEqual(cgImage.width, image.cgImage.width)
    }

    /// 验证实际编码 PNG 的四边至少保留四模块（40 像素）不透明白色静区。
    @MainActor
    func testPNGQuietZone() throws {
        let image = try XCTUnwrap(QRCodeRenderer.image(for: ProxyNode.exampleLink))
        let data = try XCTUnwrap(image.pngData())
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let width = decoded.width
        let height = decoded.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(decoded, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        for y in 0..<height {
            for x in 0..<width where x < 40 || x >= width - 40 || y < 40 || y >= height - 40 {
                let offset = (y * width + x) * 4
                guard pixels[offset...offset + 3].allSatisfy({ $0 == 255 }) else {
                    XCTFail("PNG 静区不是不透明白色：\(x), \(y)")
                    return
                }
            }
        }
    }

    /// 验证 UTF-8 字节边界以及名称默认值不依赖平台。
    func testInputByteBoundaries() throws {
        let acceptedUser = String(repeating: "a", count: 255)
        XCTAssertEqual(try ProxyNode.parse("socks://\(acceptedUser):password@localhost:1080").username, acceptedUser)
        XCTAssertThrowsError(try ProxyNode.parse("socks://\(acceptedUser)a:password@localhost:1080"))
        XCTAssertThrowsError(try ProxyNode.parse("socks://user:\(String(repeating: "中", count: 86))@localhost:1080"))
        XCTAssertThrowsError(try ProxyNode.parse("socks://localhost:1080#\(String(repeating: "a", count: 257))"))
        XCTAssertThrowsError(try ProxyNode.parse(String(repeating: "a", count: 4097)))
        XCTAssertEqual(try ProxyNode.parse("socks://localhost:1080#%20").name, "SOCKS5 节点")
    }
}
