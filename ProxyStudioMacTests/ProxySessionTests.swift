import XCTest
@testable import ProxyStudio

/// 验证 Mac 窗口的会话隔离、输入失效及导出快照契约。
final class ProxySessionTests: XCTestCase {
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
