import XCTest


/// 验证示例导入、详情预览、文件导出及辅助功能字号下的主要操作。
final class ProxyStudioUITests: XCTestCase {
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
