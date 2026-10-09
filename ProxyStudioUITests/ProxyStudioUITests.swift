import XCTest


/// 验证示例导入、详情预览、文件导出及辅助功能字号下的主要操作。
final class ProxyStudioUITests: XCTestCase {
    /// 保存 UDP 开启后的实际 PNG，保留附件以供主机侧 Vision 回读。
    @MainActor
    func testShadowrocketPNGSaveWithUDP() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openExampleDetails(app)
        let udp = app.switches["udpToggle"]
        scrollTo(udp, app: app)
        udp.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(udp.value as? String, "1")
        let export = app.buttons["exportPNG"]
        scrollTo(export, app: app)
        XCTAssertTrue(app.images["qrImage"].exists)
        attach(app, "iOS-Shadowrocket-二维码UDP")
        export.tap()
        let save = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@",
                                                    "DOCPicker.actionButton", "保存")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        app.buttons["取消"].firstMatch.tap()
        XCTAssertFalse(app.alerts["导出"].exists)
        scrollTo(udp, app: app)
        XCTAssertEqual(udp.value as? String, "1")
        scrollTo(export, app: app)
        export.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let filename = app.textFields["DOCPicker.filenameTextField"]
        if filename.exists {
            filename.tap()
            filename.doubleTap()
            filename.typeText("-qr-validation-" + UUID().uuidString.prefix(8))
        }
        save.tap()
        XCTAssertTrue(app.alerts["导出"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.alerts["导出"].staticTexts["文件已保存。"].exists)
    }

    /// 保存实际 JSON 并保留预览快照附件，供主机侧逐字节回读核验。
    @MainActor
    func testJSONSaveSuccess() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openExampleDetails(app)
        let preview = app.buttons["previewJSON"]
        scrollTo(preview, app: app)
        preview.tap()
        let text = app.staticTexts["jsonPreview"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        let snapshot = XCTAttachment(data: Data(text.label.utf8), uniformTypeIdentifier: "public.json")
        snapshot.name = "iOS-JSON-预览原始字节"
        snapshot.lifetime = .keepAlways
        add(snapshot)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.navigationBars["Shadowrocket JSON"].waitForNonExistence(timeout: 5))
        let export = app.buttons["exportJSON"]
        scrollTo(export, app: app)
        export.tap()
        let save = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@",
                                                    "DOCPicker.actionButton", "保存")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let filename = app.textFields["DOCPicker.filenameTextField"]
        if filename.exists {
            filename.tap()
            filename.doubleTap()
            filename.typeText("-json-validation-" + UUID().uuidString.prefix(8))
        }
        attach(app, "iOS-JSON-实际保存")
        save.tap()
        XCTAssertTrue(app.alerts["导出"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.alerts["导出"].staticTexts["文件已保存。"].exists)
    }

    /// 验证 JSON 快照、共享 UDP 与保存取消；实际保存成功单独检查。
    @MainActor
    func testJSONPreviewSharedUDPAndCancelExport() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        openExampleDetails(app)
        let udp = app.switches["udpToggle"]
        scrollTo(udp, app: app)
        // SwiftUI 的开关辅助功能范围可能包含整行；点击右侧开关控件。
        udp.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(udp.value as? String, "1")
        let preview = app.buttons["previewJSON"]
        scrollTo(preview, app: app)
        preview.tap()
        XCTAssertTrue(app.navigationBars["Shadowrocket JSON"].waitForExistence(timeout: 5))
        let text = app.staticTexts["jsonPreview"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        let snapshot = text.label
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(snapshot.utf8)) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "Socks5")
        XCTAssertEqual(object["udp"] as? Int, 1)
        attach(app, "iOS-JSON-预览")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.navigationBars["Shadowrocket JSON"].waitForNonExistence(timeout: 5))
        let yaml = app.buttons["预览 YAML"]
        scrollTo(yaml, app: app)
        yaml.tap()
        XCTAssertTrue(app.staticTexts["yamlPreview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["yamlPreview"].label.contains("udp: true"))
        app.buttons["完成"].tap()
        XCTAssertTrue(app.navigationBars["Clash YAML"].waitForNonExistence(timeout: 5))
        let export = app.buttons["exportJSON"]
        scrollTo(export, app: app)
        export.tap()
        let saveAppeared = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@",
                                                                   "DOCPicker.actionButton", "保存"))
            .firstMatch.waitForExistence(timeout: 20)
        if !saveAppeared { print(app.debugDescription) }
        XCTAssertTrue(saveAppeared)
        attach(app, "iOS-JSON-保存面板")
        let cancel = app.buttons["取消"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["导出"].exists)
        scrollTo(preview, app: app)
        preview.tap()
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.label, snapshot)
    }

    @MainActor
    func testJSONPreviewAtAccessibilityTextSize() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openExampleDetails(app)
        let preview = app.buttons["previewJSON"]
        scrollTo(preview, app: app)
        preview.tap()
        XCTAssertTrue(app.navigationBars["Shadowrocket JSON"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["jsonPreview"].waitForExistence(timeout: 5))
        attach(app, "iOS-JSON-辅助功能大字体")
        XCTAssertTrue(app.buttons["完成"].isHittable)
    }

    @MainActor
    private func openExampleDetails(_ app: XCUIApplication) {
        continueAfterFailure = false
        let sample = app.buttons["试用示例节点"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        scrollTo(sample, app: app, isImport: true)
        sample.tap()
        let parse = app.buttons["parseButton"]
        scrollTo(parse, app: app, isImport: true)
        parse.tap()
        let result = app.buttons["nodeResult"]
        if !app.descendants(matching: .any)["protocolRow"].exists {
            scrollTo(result, app: app, isImport: true)
            result.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["protocolRow"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, app: XCUIApplication, isImport: Bool = false) {
        let container = isImport ? app.scrollViews.firstMatch : app.collectionViews.firstMatch
        for direction in [true, false] {
            for _ in 0..<12 {
                if element.isHittable { return }
                if container.exists {
                    if direction { container.swipeUp() } else { container.swipeDown() }
                } else if direction { app.swipeUp() } else { app.swipeDown() }
            }
        }
        XCTAssertTrue(element.isHittable)
    }

    /// 验证从导入示例到保存配置的流程，并在发送旋转请求前后记录截图。
    ///
    /// - Note: 断言只检查旋转请求后的控件存在性，不证明设备已实际切换为横屏布局。
    @MainActor
    func testImportPreviewAndRotate() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["试用示例节点"].waitForExistence(timeout: 10))
        app.buttons["试用示例节点"].tap()
        app.buttons["parseButton"].tap()
        XCTAssertTrue(app.buttons["nodeResult"].waitForExistence(timeout: 5))
        app.buttons["nodeResult"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["protocolRow"].waitForExistence(timeout: 5))
        attach(app, "节点详情-竖屏")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.descendants(matching: .any)["protocolRow"].waitForExistence(timeout: 5))
        attach(app, "节点详情-横屏")
        let preview = app.buttons["预览 YAML"]
        // 在详情表单中滚动，避免分栏或横屏时手势落到导入栏。
        for _ in 0..<10 where !preview.isHittable {
            if app.collectionViews.firstMatch.exists { app.collectionViews.firstMatch.swipeUp() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(preview.isHittable)
        preview.tap()
        XCTAssertTrue(app.navigationBars["Clash YAML"].waitForExistence(timeout: 5))
        attach(app, "YAML预览")
        app.buttons["完成"].tap()
        let export = app.buttons["exportYAML"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        let save = app.buttons["DOCPicker.actionButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let filename = app.textFields["DOCPicker.filenameTextField"]
        if filename.exists {
            filename.tap()
            // 紧凑保存面板需再次激活文件名文本编辑。
            filename.doubleTap()
            filename.typeText("-uitest-" + UUID().uuidString.prefix(8))
        }
        attach(app, "文件导出")
        save.tap()
        XCTAssertTrue(app.alerts["导出"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.alerts["导出"].staticTexts["文件已保存。"].exists)
        app.alerts["导出"].buttons["好"].tap()
        XCUIDevice.shared.orientation = .portrait
    }

    /// 验证辅助功能最大字号下仍可操作导入入口并进入节点详情。
    @MainActor
    func testAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let sample = app.buttons["试用示例节点"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        for _ in 0..<5 where !sample.isHittable { app.swipeUp() }
        sample.tap()
        let parse = app.buttons["parseButton"]
        for _ in 0..<5 where !parse.isHittable { app.swipeUp() }
        parse.tap()
        let result = app.buttons["nodeResult"]
        for _ in 0..<5 where !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.isHittable)
        result.tap()
        XCTAssertTrue(app.descendants(matching: .any)["protocolRow"].waitForExistence(timeout: 5))
        attach(app, "辅助功能大字体")
    }

    /// 将当前应用截图作为永久保留的附件加入测试结果。
    ///
    /// - Parameters:
    ///   - app: 要捕获画面的被测应用。
    ///   - name: 测试结果中显示的附件名称。
    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
