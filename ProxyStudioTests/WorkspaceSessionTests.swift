import XCTest
import Vision
import ImageIO
@testable import ProxyStudio

/// 两端会话均遵循导航保留、即时输出与不可变导出契约。
final class WorkspaceSessionTests: XCTestCase {
    @MainActor
    func testOutputAndDetailsChangesPreserveIdentityAndOptions() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        let identity = session.nodeIdentifier
        let created = session.nodeCreatedAt
        session.detailsExpanded = true
        session.revealPassword = true
        session.udpEnabled = true
        session.output = .json
        let json = try XCTUnwrap(session.jsonData)
        session.output = .yaml
        session.output = .json
        // 视图退出与重建只持有同一会话，不调用 clear 或 parse。
        let returnedSession = session
        XCTAssertEqual(returnedSession.nodeIdentifier, identity)
        XCTAssertEqual(returnedSession.nodeCreatedAt, created)
        XCTAssertEqual(returnedSession.jsonData, json)
        XCTAssertTrue(returnedSession.detailsExpanded)
        XCTAssertTrue(returnedSession.revealPassword)
        XCTAssertTrue(returnedSession.udpEnabled)
        XCTAssertEqual(returnedSession.output, .json)
    }

    @MainActor
    func testEditingClearsOldOutputAndNewNodeResetsPresentation() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        let identity = session.nodeIdentifier
        session.output = .json
        session.detailsExpanded = true
        session.revealPassword = true
        session.udpEnabled = true
        session.input = "socks5://other.example.com:1081"
        XCTAssertNil(session.node)
        XCTAssertNil(session.qrImage)
        XCTAssertNil(session.jsonData)
        XCTAssertFalse(session.canUseOutput)
        XCTAssertFalse(session.detailsExpanded)
        session.parse()
        XCTAssertNotEqual(session.nodeIdentifier, identity)
        XCTAssertEqual(session.output, .qr)
        XCTAssertFalse(session.detailsExpanded)
        XCTAssertFalse(session.revealPassword)
        XCTAssertFalse(session.udpEnabled)
    }

    @MainActor
    func testCurrentTextIsOriginalAndUDPUpdatesBothFormats() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        session.output = .json
        let identity = session.nodeIdentifier
        let original = try XCTUnwrap(session.outputText)
        session.udpEnabled = true
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(XCTUnwrap(session.outputText).utf8)) as? [String: Any])
        XCTAssertEqual(object["udp"] as? Int, 1)
        XCTAssertEqual(session.nodeIdentifier, identity)
        XCTAssertNotEqual(session.outputText, original)
        session.output = .yaml
        XCTAssertEqual(session.outputText, session.yaml)
        XCTAssertTrue(session.yaml.contains("udp: true"))
        session.output = .qr
        XCTAssertNil(session.outputText)
    }

    @MainActor
    func testCurrentExportCapturesJSONAndYAMLSnapshotsBeforeChanges() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        for format in [OutputFormat.json, .yaml] {
            session.output = format
            let expected = Data(try XCTUnwrap(session.outputText).utf8)
            session.exportCurrent()
            XCTAssertEqual(session.exportDocument?.data, expected)
            XCTAssertFalse(session.canExportCurrent)
            XCTAssertFalse(session.canParse)
            session.udpEnabled.toggle()
            XCTAssertEqual(session.exportDocument?.data, expected)
            session.cancelExport()
            XCTAssertNil(session.exportDocument)
            XCTAssertNil(session.message)
            XCTAssertEqual(session.output, format)
            XCTAssertNotNil(session.node)
        }
    }

    /// 独立二维码解码器验证 PNG 快照保留保存前的 UDP 载荷。
    @MainActor
    func testPNGSnapshotPreservesPayloadWhenLiveOptionsChange() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        let payload = session.shareLink
        session.exportCurrent()
        let snapshot = try XCTUnwrap(session.exportDocument?.data)
        session.udpEnabled = true
        XCTAssertNotEqual(session.shareLink, payload)
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        // 与二维码回读测试采用同一 CPU 修订版，兼容模拟器未提供最新 Vision 模型的情况。
        request.revision = VNDetectBarcodesRequestRevision1
        request.usesCPUOnly = true
        let source = try XCTUnwrap(CGImageSourceCreateWithData(snapshot as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        try VNImageRequestHandler(cgImage: image).perform([request])
        XCTAssertEqual(request.results?.first?.payloadStringValue, payload)
        XCTAssertEqual(session.exportDocument?.data, snapshot)
        session.cancelExport()
        XCTAssertTrue(session.udpEnabled)
        XCTAssertNil(session.message)
    }

    @MainActor
    func testSaveResultsAndInvalidInputRecovery() {
        let session = ProxySession()
        session.input = "https://invalid.example.com"
        session.parse()
        XCTAssertNotNil(session.parseError)
        session.input = ProxyNode.exampleLink
        XCTAssertNil(session.parseError)
        session.parse()
        session.output = .yaml
        session.exportCurrent()
        session.finishExport(.failure(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)))
        XCTAssertNil(session.message)
        session.exportCurrent()
        session.finishExport(.failure(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)))
        XCTAssertTrue(session.message?.hasPrefix("保存失败：") == true)
        session.exportCurrent()
        session.finishExport(.success(URL(fileURLWithPath: "/tmp/clash.yaml")))
        XCTAssertEqual(session.message, "文件已保存。")
    }
}
