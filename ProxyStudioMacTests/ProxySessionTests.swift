import XCTest
import Vision
import ImageIO
@testable import ProxyStudio

/// 验证 Mac 窗口的会话隔离、输入失效及导出快照契约。
final class ProxySessionTests: XCTestCase {
    /// 验证导入 UDP、实时二维码更新、PNG 快照及取消后状态一致性。
    @MainActor
    func testShadowrocketQRUsesSharedUDPAndImmutablePNGSnapshot() throws {
        let session = ProxySession()
        let node = try ProxyNode.parse(ProxyNode.exampleLink)
        session.input = node.shadowrocketLink(udpEnabled: true)
        session.parse()
        XCTAssertTrue(session.udpEnabled)
        XCTAssertEqual(try decodePNG(XCTUnwrap(session.qrImage?.pngData())), session.shareLink)
        let original = session.shareLink
        let identifier = session.nodeIdentifier
        session.exportPNG()
        let snapshot = try XCTUnwrap(session.exportDocument?.data)
        XCTAssertEqual(try decodePNG(snapshot), original)
        session.udpEnabled = false
        XCTAssertNotEqual(session.shareLink, original)
        XCTAssertEqual(try decodePNG(XCTUnwrap(session.qrImage?.pngData())), session.shareLink)
        XCTAssertFalse(try ProxyNode.parse(session.shareLink).udpEnabled)
        XCTAssertTrue(session.yaml.contains("udp: false"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(session.jsonData)) as? [String: Any])
        XCTAssertEqual(json["udp"] as? Int, 0)
        XCTAssertEqual(session.exportDocument?.data, snapshot)
        XCTAssertEqual(session.nodeIdentifier, identifier)
        session.cancelExport()
        XCTAssertFalse(session.udpEnabled)
        XCTAssertNil(session.message)
        session.parse()
        XCTAssertFalse(session.udpEnabled)
        session.input = ProxyNode.exampleLink
        session.parse()
        XCTAssertFalse(session.udpEnabled)
    }

    /// 通过 ImageIO 和 Vision 独立回读 PNG 中的二维码载荷。
    /// - Parameter data: 已编码的 PNG 字节。
    /// - Returns: 检测到的首个二维码文本。
    /// - Throws: 图片解码、条码检测或载荷解包失败时产生测试错误。
    @MainActor
    private func decodePNG(_ data: Data) throws -> String {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        request.revision = VNDetectBarcodesRequestRevision1
        request.usesCPUOnly = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return try XCTUnwrap(request.results?.first?.payloadStringValue)
    }

    /// 验证重复解析和格式切换保持 JSON 元数据，输入变更后生成新的节点身份。
    @MainActor
    func testJSONMetadataIsStableUntilNodeChanges() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        let original = try XCTUnwrap(session.jsonData)
        let identifier = session.nodeIdentifier
        let createdAt = session.nodeCreatedAt
        session.output = .json
        session.output = .yaml
        session.parse()
        XCTAssertEqual(session.jsonData, original)
        XCTAssertEqual(session.nodeIdentifier, identifier)
        XCTAssertEqual(session.nodeCreatedAt, createdAt)
        session.input = "socks://[2001:db8::1]:1080#second"
        XCTAssertNil(session.jsonData)
        session.parse()
        XCTAssertNotEqual(session.nodeIdentifier, identifier)
        XCTAssertFalse(session.udpEnabled)
        XCTAssertEqual(session.output, .qr)
    }

    /// 验证 JSON/YAML 共用 UDP，而两个窗口会话的节点、格式及清空操作独立。
    @MainActor
    func testJSONAndYAMLShareUDPAndWindowsRemainIndependent() throws {
        let first = ProxySession()
        let second = ProxySession()
        for session in [first, second] {
            session.input = ProxyNode.exampleLink
            session.parse()
        }
        XCTAssertNotEqual(first.nodeIdentifier, second.nodeIdentifier)
        first.output = .json
        first.udpEnabled = true
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(first.jsonData)) as? [String: Any])
        XCTAssertEqual(json["udp"] as? Int, 1)
        first.output = .yaml
        XCTAssertTrue(first.yaml.contains("udp: true"))
        XCTAssertFalse(second.udpEnabled)
        XCTAssertEqual(second.output, .qr)
        first.clear()
        XCTAssertNil(first.jsonData)
        XCTAssertNil(first.nodeIdentifier)
        XCTAssertNotNil(second.jsonData)
    }

    /// 验证 JSON 保存快照不随 UDP 更新，并在取消后保留节点与显示选项。
    @MainActor
    func testJSONSnapshotAndCancellationPreserveSession() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        session.output = .json
        session.udpEnabled = true
        session.revealPassword = true
        let expected = try XCTUnwrap(session.jsonData)
        session.exportJSON()
        XCTAssertEqual(session.exportName, "shadowrocket.json")
        XCTAssertEqual(session.exportType, .json)
        XCTAssertEqual(session.exportDocument?.data, expected)
        XCTAssertFalse(session.canParse)
        XCTAssertFalse(session.canUseOutput)
        session.udpEnabled = false
        XCTAssertEqual(session.exportDocument?.data, expected)
        session.udpEnabled = true
        session.cancelExport()
        XCTAssertNil(session.message)
        XCTAssertNil(session.exportDocument)
        XCTAssertNotNil(session.node)
        XCTAssertTrue(session.udpEnabled)
        XCTAssertTrue(session.revealPassword)
        XCTAssertEqual(session.output, .json)
    }

    /// 验证 JSON 导出入口与模拟成功、写入失败及取消回调的反馈；不写入文件。
    @MainActor
    func testJSONSaveSuccessFailureAndUserCancelledFeedback() {
        let session = ProxySession()
        session.exportJSON()
        XCTAssertFalse(session.isExporting)
        session.input = ProxyNode.exampleLink
        session.parse()
        session.exportJSON()
        session.finishExport(.success(URL(fileURLWithPath: "/tmp/shadowrocket.json")))
        XCTAssertEqual(session.message, "文件已保存。")
        session.exportJSON()
        XCTAssertNil(session.message)
        session.finishExport(.failure(CocoaError(.fileWriteNoPermission)))
        XCTAssertTrue(session.message?.hasPrefix("保存失败：") == true)
        XCTAssertNotNil(session.node)
        session.exportJSON()
        session.finishExport(.failure(CocoaError(.userCancelled)))
        XCTAssertNil(session.message)
        XCTAssertNil(session.exportDocument)
    }

    /// 验证不同输入立即使旧节点和错误失效，空输入禁用解析。
    @MainActor
    func testEditingInvalidatesNodeAndError() {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        XCTAssertNotNil(session.node)
        session.input = "invalid"
        XCTAssertNil(session.node)
        XCTAssertNil(session.qrImage)
        session.parse()
        XCTAssertNotNil(session.parseError)
        session.input = ""
        XCTAssertNil(session.parseError)
        XCTAssertFalse(session.canParse)
    }

    /// 验证格式切换保留密码与 UDP，新节点恢复其初始选项和二维码格式。
    @MainActor
    func testNodeChangeResetsOptionsButLayoutSelectionDoesNot() {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        session.revealPassword = true
        session.udpEnabled = true
        session.output = .yaml
        session.output = .qr
        session.output = .yaml
        XCTAssertTrue(session.revealPassword)
        XCTAssertTrue(session.udpEnabled)
        session.input = "socks://localhost:1080#second"
        session.parse()
        XCTAssertFalse(session.revealPassword)
        XCTAssertFalse(session.udpEnabled)
        XCTAssertEqual(session.output, .qr)
    }

    /// 验证清空一个会话不会改变另一个会话的输入、节点和显示选项。
    @MainActor
    func testIndependentWindowsAndClear() {
        let first = ProxySession()
        let second = ProxySession()
        first.input = ProxyNode.exampleLink
        first.parse()
        first.udpEnabled = true
        first.revealPassword = true
        XCTAssertEqual(second.input, "")
        XCTAssertNil(second.node)
        XCTAssertFalse(second.udpEnabled)
        second.input = "socks://localhost:1080"
        second.parse()
        second.clear()
        XCTAssertNotNil(first.node)
        XCTAssertTrue(first.udpEnabled)
        XCTAssertTrue(first.revealPassword)
        XCTAssertNil(second.node)
        XCTAssertFalse(second.canClear)
    }

    /// 验证 YAML 导出快照、导出期间的操作禁用及取消后的选项保留。
    @MainActor
    func testYAMLExportSnapshotAndCancellationPreserveOptions() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        session.udpEnabled = true
        session.revealPassword = true
        session.output = .yaml
        let expected = Data(session.yaml.utf8)
        session.exportYAML()
        XCTAssertEqual(session.exportName, "clash.yaml")
        XCTAssertEqual(session.exportDocument?.data, expected)
        XCTAssertFalse(session.canParse)
        XCTAssertFalse(session.canClear)
        session.udpEnabled = false
        XCTAssertEqual(session.exportDocument?.data, expected)
        session.udpEnabled = true
        session.cancelExport()
        XCTAssertNil(session.message)
        XCTAssertNil(session.exportDocument)
        XCTAssertFalse(session.isExporting)
        XCTAssertNotNil(session.node)
        XCTAssertTrue(session.udpEnabled)
        XCTAssertTrue(session.revealPassword)
        XCTAssertEqual(session.output, .yaml)
    }

    /// 验证 PNG 文件签名及内容类型，并模拟用户取消错误；不执行系统面板交互。
    @MainActor
    func testPNGExportAndUserCancelledError() {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        session.exportPNG()
        XCTAssertEqual(session.exportName, "shadowrocket.png")
        XCTAssertEqual(session.exportType, .png)
        XCTAssertTrue(session.exportDocument?.data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) == true)
        session.finishExport(.failure(CocoaError(.userCancelled)))
        XCTAssertNil(session.message)
        XCTAssertNotNil(session.node)
        XCTAssertFalse(session.isExporting)
    }

    /// 验证系统导出结果处理；此测试不代替原生保存面板的失败交互验证。
    @MainActor
    func testExportSuccessAndFailureFeedback() {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        session.exportYAML()
        session.finishExport(.success(URL(fileURLWithPath: "/tmp/clash.yaml")))
        XCTAssertEqual(session.message, "文件已保存。")
        session.exportYAML()
        XCTAssertNil(session.message)
        session.finishExport(.failure(CocoaError(.fileWriteNoPermission)))
        XCTAssertTrue(session.message?.hasPrefix("保存失败：") == true)
        XCTAssertNotNil(session.node)
        XCTAssertNil(session.exportDocument)
    }
}
