import XCTest
import Vision
import ImageIO
@testable import ProxyStudio

/// 两端会话均遵循导航保留、即时输出与不可变导出契约。
final class WorkspaceSessionTests: XCTestCase {
    /// 验证同一会话的格式与详情切换保留元数据和选项；不模拟真实导航交互。
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

    /// 验证编辑立即清除旧输出，新节点解析成功后重置详情及输出格式。
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

    /// 验证复制源为原始 JSON/YAML，UDP 即时同步且不刷新节点身份。
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

    /// 验证三种文本导出在选项变化后保留原始字节，取消后释放快照及导出限制。
    @MainActor
    func testCurrentExportCapturesTextSnapshotsBeforeChanges() throws {
        let session = ProxySession()
        session.input = ProxyNode.exampleLink
        session.parse()
        for format in [OutputFormat.json, .yaml, .url] {
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

    /// URL 文件保留可往返的单条链接，不添加 BOM、换行或文本包装。
    @MainActor
    func testURLExportRoundTripsCredentialsAddressesAndUDP() throws {
        let inputs = [
            ProxyNode.exampleLink,
            "socks5://[2001:db8::1]:1080?remarks=%E4%B8%AD%E6%96%87%20IPv6",
            "socks5://%E8%B4%A6%E5%8F%B7:p%40ss%3A%2F%3F%23%25@proxy.example.com:1080?remarks=%E4%B8%AD%E6%96%87%20%26%20URL"
        ]
        for input in inputs {
            let session = ProxySession()
            session.input = input
            session.parse()
            let node = try XCTUnwrap(session.node)
            let identifier = session.nodeIdentifier
            let createdAt = session.nodeCreatedAt
            session.output = .url
            for udp in [false, true] {
                session.udpEnabled = udp
                let text = try XCTUnwrap(session.outputText)
                XCTAssertEqual(text, session.shareLink)
                XCTAssertTrue(text.hasSuffix("&udp=\(udp ? 1 : 0)"))
                session.exportCurrent()
                let bytes = try XCTUnwrap(session.exportDocument?.data)
                XCTAssertEqual(bytes, Data(text.utf8))
                XCTAssertFalse(bytes.starts(with: [0xEF, 0xBB, 0xBF]))
                XCTAssertFalse(bytes.contains(10))
                XCTAssertFalse(bytes.contains(13))
                XCTAssertEqual(session.exportName, "shadowrocket.url")
                XCTAssertEqual(session.exportType, ExportDocument.shadowrocketURLType)
                XCTAssertEqual(session.exportType.preferredFilenameExtension, "url")
                XCTAssertTrue(ExportDocument.readableContentTypes.contains(session.exportType))
                let parsed = try ProxyNode.parse(String(decoding: bytes, as: UTF8.self))
                XCTAssertEqual(parsed.name, node.name)
                XCTAssertEqual(parsed.host, node.host)
                XCTAssertEqual(parsed.port, node.port)
                XCTAssertEqual(parsed.username, node.username)
                XCTAssertEqual(parsed.password, node.password)
                XCTAssertEqual(parsed.udpEnabled, udp)
                session.cancelExport()
                session.exportURL()
                XCTAssertEqual(session.exportDocument?.data, bytes)
                session.cancelExport()
                session.output = .json
                session.output = .url
                XCTAssertEqual(session.nodeIdentifier, identifier)
                XCTAssertEqual(session.nodeCreatedAt, createdAt)
            }
        }
    }

    /// 验证 URL 导出可用性、模拟保存结果和两个会话的独立性。
    ///
    /// - Note: 完成回调由测试构造，不代表执行了系统保存面板或实际文件写入。
    @MainActor
    func testURLExportAvailabilityResultsAndIndependentWindows() throws {
        let first = ProxySession()
        first.output = .url
        XCTAssertNil(first.outputText)
        XCTAssertFalse(first.canExportCurrent)
        first.exportURL()
        XCTAssertFalse(first.isExporting)
        let second = ProxySession()
        for session in [first, second] {
            session.input = ProxyNode.exampleLink
            session.parse()
        }
        first.output = .url
        first.udpEnabled = true
        first.revealPassword = true
        first.detailsExpanded = true
        let text = first.outputText
        let results: [Result<URL, Error>] = [
            .success(URL(fileURLWithPath: "/tmp/shadowrocket.url")),
            .failure(CocoaError(.fileWriteNoPermission)),
            .failure(CocoaError(.userCancelled))
        ]
        for result in results {
            first.exportCurrent()
            first.finishExport(result)
            XCTAssertFalse(first.isExporting)
            XCTAssertNil(first.exportDocument)
            XCTAssertEqual(first.outputText, text)
            XCTAssertEqual(first.output, .url)
            XCTAssertTrue(first.revealPassword)
            XCTAssertTrue(first.detailsExpanded)
            XCTAssertTrue(first.udpEnabled)
            switch result {
            case .success: XCTAssertEqual(first.message, "文件已保存。")
            case .failure(let error):
                if (error as NSError).code == NSUserCancelledError { XCTAssertNil(first.message) }
                else { XCTAssertTrue(first.message?.hasPrefix("保存失败：") == true) }
            }
        }
        XCTAssertEqual(second.output, .qr)
        XCTAssertFalse(second.udpEnabled)
        XCTAssertNil(second.exportDocument)
        first.input = "invalid"
        XCTAssertNil(first.outputText)
        XCTAssertFalse(first.canExportCurrent)
        XCTAssertNotNil(second.node)
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
        // URL 导出的原始文本与独立解码器读取的二维码载荷相同。
        session.cancelExport()
        session.udpEnabled = false
        session.output = .url
        session.exportCurrent()
        XCTAssertEqual(session.exportDocument?.data, Data(try XCTUnwrap(request.results?.first?.payloadStringValue).utf8))
        session.cancelExport()
        session.udpEnabled = true
        session.output = .qr
        XCTAssertTrue(session.udpEnabled)
        XCTAssertNil(session.message)
    }

    /// 验证无效输入恢复与保存成功、失败、取消的回调提示；不执行实际文件写入。
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
