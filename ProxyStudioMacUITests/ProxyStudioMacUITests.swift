import XCTest

/// 验证原生 Mac 的导入、输出切换、键盘操作及独立窗口。
final class ProxyStudioMacUITests: XCTestCase {
    @MainActor
    func testImportPasswordAndLiveYAML() {
        let app = launch()
        importExample(app)
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
        for identifier in ["exportPNG", "exportYAML"] {
            if identifier == "exportYAML" { app.typeKey("2", modifierFlags: .command) }
            app.buttons[identifier].click()
            XCTAssertTrue(app.buttons["CancelButton"].waitForExistence(timeout: 5))
            attach(app, "Mac-\(identifier)-保存面板")
            app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
            XCTAssertFalse(app.alerts.firstMatch.exists)
            XCTAssertTrue(app.descendants(matching: .any)["protocolRow"].exists)
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
        importExample(app)
        app.buttons["togglePassword"].click()
        app.typeKey("2", modifierFlags: .command)
        app.switches["udpToggle"].click()
        let window = app.windows.firstMatch
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
        app.buttons["隐藏边栏"].click()
        XCTAssertTrue((app.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        app.buttons["显示边栏"].click()
        XCTAssertTrue((app.textViews["proxyLinkInput"].value as? String)?.hasPrefix("socks://") == true)
        let widerEdge = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.8))
            .withOffset(CGVector(dx: -1, dy: 0))
        widerEdge.click(forDuration: 0.2, thenDragTo: widerEdge.withOffset(CGVector(dx: 500, dy: 0)))
        XCTAssertGreaterThan(window.frame.width, originalFrame.width)
        XCTAssertTrue((app.descendants(matching: .any)["yamlPreview"].value as? String)?.contains("udp: true") == true)
        attach(app, "Mac-宽窗口-YAML")
    }

    @MainActor
    private func launch(appearance: String = "Dark") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO",
                               "-AppleInterfaceStyle", appearance]
        app.launch()
        XCTAssertTrue(app.buttons["试用示例节点"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func importExample(_ app: XCUIApplication) {
        app.buttons["试用示例节点"].click()
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["protocolRow"].waitForExistence(timeout: 5))
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
