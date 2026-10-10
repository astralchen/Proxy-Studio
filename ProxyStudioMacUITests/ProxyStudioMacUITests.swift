import XCTest
import Vision
import ImageIO
import CoreImage
import AppKit

/// 验证原生 Mac 的导入、输出切换、键盘操作及独立窗口。
final class ProxyStudioMacUITests: XCTestCase {
    /// 在二维码标签修改 UDP，经原生面板保存实际 PNG，并回读载荷和纠错级别。
    @MainActor
    func testShadowrocketPNGActualSaveAndSharedUDP() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ProxyStudioQR-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = launch()
        importExample(app)
        XCTAssertTrue(app.switches["udpToggle"].waitForExistence(timeout: 5))
        app.switches["udpToggle"].click()
        app.typeKey("3", modifierFlags: .command)
        XCTAssertEqual(try jsonObject(app.descendants(matching: .any)["jsonPreview"])["udp"] as? Int, 1)
        app.typeKey("1", modifierFlags: .command)
        app.buttons["exportPNG"].click()
        XCTAssertTrue(app.buttons["CancelButton"].waitForExistence(timeout: 5))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertFalse(app.buttons["action-button-1"].exists)
        XCTAssertTrue(app.buttons["CancelButton"].waitForNonExistence(timeout: 5))
        app.typeKey("3", modifierFlags: .command)
        XCTAssertEqual(try jsonObject(app.descendants(matching: .any)["jsonPreview"])["udp"] as? Int, 1)
        app.typeKey("1", modifierFlags: .command)
        app.buttons["exportPNG"].click()
        XCTAssertTrue(app.buttons["OKButton"].waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let path = app.textFields["PathTextField"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        path.click()
        app.typeKey("a", modifierFlags: .command)
        pastePath(directory.path, into: path, app: app)
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
        XCTAssertTrue(path.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["OKButton"].isEnabled)
        app.buttons["OKButton"].click()
        XCTAssertTrue(app.buttons["action-button-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                                                          "文件已保存。", "文件已保存。")).firstMatch.exists)
        let data = try Data(contentsOf: directory.appendingPathComponent("shadowrocket.png"))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        request.revision = VNDetectBarcodesRequestRevision1
        request.usesCPUOnly = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let expected = "socks://" + Data("demo:example-password@proxy.example.com:1080".utf8).base64EncodedString()
            + "?remarks=%E7%A4%BA%E4%BE%8B%E8%8A%82%E7%82%B9&udp=1"
        XCTAssertEqual(request.results?.first?.payloadStringValue, expected)
        XCTAssertEqual((request.results?.first?.barcodeDescriptor as? CIQRCodeDescriptor)?.errorCorrectionLevel, .levelH)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "Mac-Shadowrocket-实际保存PNG"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["action-button-1"].click()
        attach(app, "Mac-Shadowrocket-二维码UDP")
    }

    /// 通过原生面板写入文件并回读；只读目录检查实际文件写入失败。
    @MainActor
    func testJSONActualSaveAndReadOnlyFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProxyStudioJSONUITests-" + UUID().uuidString).path
        let readOnly = directory + "/ReadOnly"
        try FileManager.default.createDirectory(atPath: readOnly, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly) }
        let app = launch()
        importExample(app)
        app.typeKey("3", modifierFlags: .command)
        app.switches["udpToggle"].click()
        let preview = app.descendants(matching: .any)["jsonPreview"]
        let snapshot = Data(try XCTUnwrap(preview.value as? String).utf8)
        let attachment = XCTAttachment(data: snapshot, uniformTypeIdentifier: "public.json")
        attachment.name = "Mac-JSON-预览原始字节"
        attachment.lifetime = .keepAlways
        add(attachment)
        saveJSON(app, directory: directory)
        XCTAssertTrue(app.buttons["action-button-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                                                          "文件已保存。", "文件已保存。")).firstMatch.exists)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: directory + "/shadowrocket.json")), snapshot)
        attach(app, "Mac-JSON-实际保存成功")
        app.buttons["action-button-1"].click()
        saveJSON(app, directory: readOnly)
        XCTAssertTrue(app.buttons["action-button-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                                                          "保存失败：", "保存失败：")).firstMatch.exists)
        XCTAssertFalse(FileManager.default.fileExists(atPath: readOnly + "/shadowrocket.json"))
        attach(app, "Mac-JSON-只读目录失败")
        app.buttons["action-button-1"].click()
        XCTAssertTrue(preview.exists)
        XCTAssertEqual(Data(try XCTUnwrap(preview.value as? String).utf8), snapshot)
    }

    /// 通过原生面板写入文件并回读；只读目录检查实际文件写入失败。
    @MainActor
    func testURLActualSaveAndReadOnlyFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProxyStudioURLUITests-" + UUID().uuidString).path
        let readOnly = directory + "/ReadOnly"
        try FileManager.default.createDirectory(atPath: readOnly, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly) }
        let app = launch()
        importExample(app)
        app.typeKey("4", modifierFlags: .command)
        app.switches["udpToggle"].click()
        let preview = app.descendants(matching: .any)["urlPreview"]
        let snapshot = Data(try XCTUnwrap(preview.value as? String).utf8)
        let attachment = XCTAttachment(data: snapshot, uniformTypeIdentifier: "public.plain-text")
        attachment.name = "Mac-URL-预览原始字节"
        attachment.lifetime = .keepAlways
        add(attachment)
        saveText(app, identifier: "exportURL", directory: directory)
        XCTAssertTrue(app.buttons["action-button-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                                                          "文件已保存。", "文件已保存。")).firstMatch.exists)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: directory + "/shadowrocket.url")), snapshot)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory).sorted(), ["ReadOnly", "shadowrocket.url"])
        XCTAssertFalse(snapshot.starts(with: [0xEF, 0xBB, 0xBF]))
        XCTAssertFalse(snapshot.contains(10))
        attach(app, "Mac-URL-实际保存成功")
        app.buttons["action-button-1"].click()
        saveText(app, identifier: "exportURL", directory: readOnly)
        XCTAssertTrue(app.buttons["action-button-1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                                                          "保存失败：", "保存失败：")).firstMatch.exists)
        XCTAssertFalse(FileManager.default.fileExists(atPath: readOnly + "/shadowrocket.url"))
        attach(app, "Mac-URL-只读目录失败")
        app.buttons["action-button-1"].click()
        XCTAssertTrue(preview.exists)
        XCTAssertEqual(Data(try XCTUnwrap(preview.value as? String).utf8), snapshot)
    }

    /// 使用原生面板保存 YAML，逐字节验证视觉换行不影响输出。
    @MainActor
    func testYAMLActualSaveMatchesLivePreview() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ProxyStudioYAML-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = launch()
        importExample(app)
        app.typeKey("2", modifierFlags: .command)
        app.switches["udpToggle"].click()
        let snapshot = Data(try XCTUnwrap(app.descendants(matching: .any)["yamlPreview"].value as? String).utf8)
        app.buttons["exportYAML"].click()
        XCTAssertTrue(app.buttons["OKButton"].waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let path = app.textFields["PathTextField"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        path.click()
        app.typeKey("a", modifierFlags: .command)
        pastePath(directory.path, into: path, app: app)
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
        XCTAssertTrue(path.waitForNonExistence(timeout: 5))
        app.buttons["OKButton"].click()
        XCTAssertTrue(app.buttons["action-button-1"].waitForExistence(timeout: 10))
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("clash.yaml")), snapshot)
        app.buttons["action-button-1"].click()
        attach(app, "Glass-Mac-YAML实际保存")
    }

    @MainActor
    private func saveJSON(_ app: XCUIApplication, directory: String) {
        saveText(app, identifier: "exportJSON", directory: directory)
    }

    @MainActor
    private func saveText(_ app: XCUIApplication, identifier: String, directory: String) {
        app.buttons[identifier].click()
        XCTAssertTrue(app.buttons["OKButton"].waitForExistence(timeout: 5))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let path = app.textFields["PathTextField"]
        XCTAssertTrue(path.waitForExistence(timeout: 5))
        path.click()
        app.typeKey("a", modifierFlags: .command)
        pastePath(directory, into: path, app: app)
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
        XCTAssertTrue(path.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["OKButton"].isEnabled)
        app.buttons["OKButton"].click()
    }

    @MainActor
    func testLiveJSONSharedUDPAndEscape() throws {
        let app = launch()
        importExample(app)
        app.typeKey("3", modifierFlags: .command)
        let preview = app.descendants(matching: .any)["jsonPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        let initial = try jsonObject(preview)
        XCTAssertEqual(initial["type"] as? String, "Socks5")
        XCTAssertEqual(initial["udp"] as? Int, 0)
        app.switches["udpToggle"].click()
        XCTAssertEqual(try jsonObject(preview)["udp"] as? Int, 1)
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue((app.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        app.typeKey("3", modifierFlags: .command)
        XCTAssertEqual(try jsonObject(preview)["uuid"] as? String, initial["uuid"] as? String)
        attach(app, "Mac-JSON-即时预览")
        app.buttons["exportJSON"].click()
        XCTAssertTrue(app.buttons["CancelButton"].waitForExistence(timeout: 5))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["action-button-1"].exists)
        XCTAssertEqual(try jsonObject(preview)["udp"] as? Int, 1)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["exportPNG"].waitForExistence(timeout: 5))
    }

    /// URL 菜单和快捷键操作当前窗口，保存面板优先处理 Escape。
    @MainActor
    func testLiveURLCopyMenusSharedUDPAndEscape() throws {
        let app = launch(appearance: "Light")
        importExample(app)
        app.menuBars.menuBarItems["节点"].click()
        app.menuItems["显示 Shadowrocket URL"].click()
        let preview = app.descendants(matching: .any)["urlPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue((preview.value as? String)?.hasSuffix("&udp=0") == true)
        app.switches["udpToggle"].click()
        let snapshot = try XCTUnwrap(preview.value as? String)
        XCTAssertTrue(snapshot.hasSuffix("&udp=1"))
        app.buttons["copyOutput"].click()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), snapshot)
        app.typeKey("3", modifierFlags: .command)
        XCTAssertEqual(try jsonObject(app.descendants(matching: .any)["jsonPreview"])["udp"] as? Int, 1)
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue((app.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        app.typeKey("4", modifierFlags: .command)
        XCTAssertEqual(preview.value as? String, snapshot)
        app.menuBars.menuBarItems["节点"].click()
        app.menuItems["导出 Shadowrocket URL…"].click()
        XCTAssertTrue(app.buttons["CancelButton"].waitForExistence(timeout: 5))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["CancelButton"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["action-button-1"].exists)
        XCTAssertEqual(preview.value as? String, snapshot)
        attach(app, "Mac-URL-浅色预览复制与取消")
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["exportPNG"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func jsonObject(_ preview: XCUIElement) throws -> [String: Any] {
        let text = try XCTUnwrap(preview.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    @MainActor
    func testImportPasswordAndLiveYAML() {
        let app = launch()
        importExample(app)
        app.buttons["nodeDisclosure"].click()
        app.buttons["togglePassword"].click()
        XCTAssertEqual(app.descendants(matching: .any)["nodePassword"].value as? String, "example-password")
        app.typeKey("2", modifierFlags: .command)
        let yaml = app.descendants(matching: .any)["yamlPreview"]
        XCTAssertTrue(yaml.waitForExistence(timeout: 5))
        XCTAssertTrue((yaml.value as? String)?.contains("udp: false") == true)
        app.switches["udpToggle"].click()
        XCTAssertTrue((yaml.value as? String)?.contains("udp: true") == true)
        attach(app, "Mac-YAML-即时预览")
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["exportPNG"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["nodePassword"].value as? String, "example-password")
        attach(app, "Mac-二维码")
    }

    @MainActor
    func testEditingInvalidatesNodeAndKeyboardClear() {
        let app = launch()
        XCTAssertFalse(app.buttons["parseButton"].isEnabled)
        importExample(app)
        let editor = app.textViews["proxyLinkInput"]
        editor.click()
        app.typeKey("a", modifierFlags: .command)
        editor.typeText("invalid")
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["parseError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["exportPNG"].exists)
        app.typeKey(XCUIKeyboardKey.delete, modifierFlags: [.command, .shift])
        XCTAssertEqual(editor.value as? String, "")
        XCTAssertFalse(app.buttons["parseButton"].isEnabled)
    }

    @MainActor
    func testNewWindowIsIndependent() {
        let app = launch()
        importExample(app)
        app.typeKey("2", modifierFlags: .command)
        app.switches["udpToggle"].click()
        let first = app.windows.containing(.any, identifier: "yamlPreview").firstMatch
        app.typeKey("n", modifierFlags: .command)
        let twoWindows = NSPredicate(format: "count == 2")
        expectation(for: twoWindows, evaluatedWith: app.windows)
        waitForExpectations(timeout: 5)
        let editors = app.textViews.matching(identifier: "proxyLinkInput")
        XCTAssertEqual(editors.count, 2)
        let values = editors.allElementsBoundByIndex.compactMap { $0.value as? String }
        XCTAssertTrue(values.contains(""))
        XCTAssertTrue(values.contains(where: { $0.hasPrefix("socks://") }))
        XCTAssertTrue((first.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        attach(app, "Mac-独立多窗口")
    }

    @MainActor
    func testCancelPNGAndYAMLSave() {
        let app = launch()
        importExample(app)
        for identifier in ["exportPNG", "exportYAML", "exportJSON", "exportURL"] {
            if identifier == "exportYAML" { app.typeKey("2", modifierFlags: .command) }
            if identifier == "exportJSON" { app.typeKey("3", modifierFlags: .command) }
            if identifier == "exportURL" { app.typeKey("4", modifierFlags: .command) }
            app.buttons[identifier].click()
            XCTAssertTrue(app.buttons["CancelButton"].waitForExistence(timeout: 5))
            attach(app, "Mac-\(identifier)-保存面板")
            app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["action-button-1"].exists)
            XCTAssertTrue(app.switches["udpToggle"].exists)
        }
    }

    /// 保存应用范围内的浅色截图，外观是否正确需人工检查该附件。
    @MainActor
    func testLightAppearance() {
        let app = launch(appearance: "Light")
        importExample(app)
        attach(app, "Mac-浅色-二维码")
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.buttons["exportYAML"].waitForExistence(timeout: 5))
        attach(app, "Mac-浅色-YAML")
    }

    /// 实际拖动窗口边缘，确认尺寸变化和侧栏隐藏恢复都不重置会话。
    @MainActor
    func testWindowResizeAndSidebarPreserveSession() {
        let app = launch()
        // 先收窄窗口，让密码按钮避开屏幕中央的系统提示；后续仍恢复默认基线再测尺寸。
        let initialWindow = app.windows.firstMatch
        let initialRightEdge = initialWindow.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.8))
            .withOffset(CGVector(dx: -1, dy: 0))
        initialRightEdge.click(forDuration: 0.2, thenDragTo: initialRightEdge.withOffset(CGVector(
            dx: -max(400, initialWindow.frame.width - 760), dy: 0)))
        importExample(app)
        app.buttons["nodeDisclosure"].click()
        app.buttons["togglePassword"].click()
        app.typeKey("2", modifierFlags: .command)
        app.switches["udpToggle"].click()
        // 第一次 Escape 可能先返回二维码；第二次交给输入法关闭短暂浮层，再恢复当前输出。
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        app.typeKey("2", modifierFlags: .command)
        let window = app.windows.firstMatch
        // 将测试窗口移至可见区域，避免底边在屏幕之外导致拖动未生效。
        let initialFrame = window.frame
        let titleBar = window.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 20))
        titleBar.click(forDuration: 0.2, thenDragTo: titleBar.withOffset(CGVector(
            dx: 80 - initialFrame.minX, dy: 80 - initialFrame.minY)))
        // 系统可能恢复上次的最小窗口，先扩大基线再验证缩小确实生效。
        let restoredFrame = window.frame
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -1, dy: -1))
        corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(
            dx: 1100 - restoredFrame.width, dy: 812 - restoredFrame.height)))
        let originalFrame = window.frame
        let rightEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.8))
            .withOffset(CGVector(dx: -1, dy: 0))
        rightEdge.click(forDuration: 0.2, thenDragTo: rightEdge.withOffset(CGVector(dx: -max(400, originalFrame.width - 760), dy: 0)))
        let bottomEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 1))
            .withOffset(CGVector(dx: 0, dy: -1))
        bottomEdge.click(forDuration: 0.2, thenDragTo: bottomEdge.withOffset(CGVector(dx: 0, dy: -300)))
        XCTAssertLessThan(window.frame.width, originalFrame.width)
        XCTAssertLessThan(window.frame.height, originalFrame.height)
        XCTAssertGreaterThanOrEqual(window.frame.width, 760)
        XCTAssertGreaterThanOrEqual(window.frame.height, 560)
        XCTAssertTrue((app.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        XCTAssertEqual(app.descendants(matching: .any)["nodePassword"].value as? String, "example-password")
        attach(app, "Mac-最小窗口-YAML")
        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["jsonPreview"].waitForExistence(timeout: 5))
        XCTAssertEqual(try? jsonObject(app.descendants(matching: .any)["jsonPreview"])["udp"] as? Int, 1)
        for identifier in ["jsonPreview", "exportJSON", "outputPicker"] {
            let element = app.descendants(matching: .any)[identifier]
            XCTAssertGreaterThanOrEqual(element.frame.minX, window.frame.minX)
            XCTAssertLessThanOrEqual(element.frame.maxX, window.frame.maxX)
        }
        attach(app, "Mac-最小窗口-JSON")
        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue((app.descendants(matching: .any)["urlPreview"].value as? String)?.hasSuffix("&udp=1") == true)
        XCTAssertTrue(app.buttons["exportURL"].isHittable)
        XCTAssertTrue(app.buttons["copyOutput"].isHittable)
        for identifier in ["urlPreview", "exportURL", "outputPicker"] {
            let element = app.descendants(matching: .any)[identifier]
            XCTAssertGreaterThanOrEqual(element.frame.minX, window.frame.minX)
            XCTAssertLessThanOrEqual(element.frame.maxX, window.frame.maxX)
        }
        attach(app, "Mac-最小窗口-URL")
        app.typeKey("2", modifierFlags: .command)
        app.buttons["隐藏边栏"].click()
        XCTAssertTrue(app.buttons["显示边栏"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        app.buttons["显示边栏"].click()
        // 窗口拖动后辅助功能点击偶尔未送达；只在边栏仍隐藏时重试该操作。
        if !app.textViews["proxyLinkInput"].waitForExistence(timeout: 3), app.buttons["显示边栏"].exists {
            app.buttons["显示边栏"].click()
        }
        XCTAssertTrue(app.textViews["proxyLinkInput"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textViews["proxyLinkInput"].value as? String)?.hasPrefix("socks://") == true)
        let widerEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.8))
            .withOffset(CGVector(dx: -1, dy: 0))
        widerEdge.click(forDuration: 0.2, thenDragTo: widerEdge.withOffset(CGVector(dx: 500, dy: 0)))
        XCTAssertGreaterThan(window.frame.width, originalFrame.width)
        XCTAssertTrue((app.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        attach(app, "Mac-宽窗口-YAML")
    }

    /// 复制保存原始字节，并验证收起字段不会暴露密码。
    @MainActor
    func testCopyOriginalTextAndCollapsedDetails() throws {
        let app = launch()
        importExample(app)
        XCTAssertFalse(app.buttons["togglePassword"].exists)
        app.typeKey("3", modifierFlags: .command)
        let expected = try XCTUnwrap(app.descendants(matching: .any)["jsonPreview"].value as? String)
        app.buttons["copyOutput"].click()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), expected)
        XCTAssertTrue(app.staticTexts["copyFeedback"].waitForExistence(timeout: 3))
        attach(app, "Glass-Mac-复制文本")
    }

    /// 原生分享菜单提供图片和链接；不向外部服务实际发送内容。
    @MainActor
    func testShareMenuOffersImageAndLink() {
        let app = launch()
        importExample(app)
        app.descendants(matching: .any)["shareMenu"].click()
        XCTAssertTrue(app.menuItems["分享图片"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["分享导入链接"].exists)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    /// 路径使用粘贴，避免中文输入法将斜杠转换为顿号。
    @MainActor
    private func pastePath(_ directory: String, into field: XCUIElement, app: XCUIApplication) {
        let previous = NSPasteboard.general.string(forType: .string)
        defer {
            NSPasteboard.general.clearContents()
            if let previous { NSPasteboard.general.setString(previous, forType: .string) }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(directory, forType: .string)
        app.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(field.value as? String, directory)
    }

    @MainActor
    private func launch(appearance: String = "Dark") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO",
                               "-AppleInterfaceStyle", appearance]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let frame = window.frame
        // 从左侧空白标题栏拖动，避开屏幕中央可能存在的系统提示。
        let titleBar = window.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 20))
        titleBar.click(forDuration: 0.2, thenDragTo: titleBar.withOffset(CGVector(
            dx: 80 - frame.minX, dy: 80 - frame.minY)))
        XCTAssertTrue(app.buttons["试用示例节点"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func importExample(_ app: XCUIApplication) {
        app.buttons["试用示例节点"].click()
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: .command)
        XCTAssertTrue(app.switches["udpToggle"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        // 先激活被测应用再截窗口边界；附件仍需人工检查是否被其他窗口遮挡。
        app.activate()
        for (index, window) in app.windows.allElementsBoundByIndex.enumerated() {
            let attachment = XCTAttachment(screenshot: window.screenshot())
            attachment.name = "\(name)-窗口\(index + 1)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
