import XCTest
import Vision
import ImageIO
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
        XCTAssertGreaterThan(cgImage.width, 200)
        XCTAssertEqual(cgImage.width, cgImage.height)
        XCTAssertEqual(cgImage.width, image.cgImage.width)
    }

    /// 验证实际编码 PNG 的四边均保留四模块（40 像素）白色静区。
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
