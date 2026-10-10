import XCTest

/// 验证移动端自动导航、即时输出、会话保留与原生导出。
final class ProxyStudioUITests: XCTestCase {
    /// 二维码随内容宽度布局；滚动改变导航栏高度时，图片只移动、不缩放。
    @MainActor
    func testQRCodeSizeRemainsStableWhileScrolling() {
        let app = launch()
        openExampleDetails(app)
        let image = app.images["qrImage"]
        let initial = image.frame
        XCTAssertGreaterThan(initial.width, 0)
        XCTAssertEqual(initial.width, initial.height, accuracy: 1)
        attach(app, "QR-滚动前")
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.7))
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.3))
        lower.press(forDuration: 0.01, thenDragTo: upper)
        let scrolled = image.frame
        XCTAssertLessThan(scrolled.minY, initial.minY - 20, "必须实际滚动内容，才能验证尺寸保持稳定")
        XCTAssertEqual(scrolled.width, initial.width, accuracy: 1)
        XCTAssertEqual(scrolled.height, initial.height, accuracy: 1)
        XCTAssertTrue(app.buttons["exportPNG"].isHittable)
        attach(app, "QR-滚动后")
        upper.press(forDuration: 0.01, thenDragTo: lower)
        XCTAssertGreaterThan(image.frame.minY, scrolled.minY + 20)
        XCTAssertEqual(image.frame.width, initial.width, accuracy: 1)
        XCTAssertEqual(image.frame.height, initial.height, accuracy: 1)
    }

    /// 短视口允许滚动到二维码，完整图片不会被底部操作区遮挡。
    @MainActor
    func testQRCodeFitsVisibleViewportAfterScrolling() {
        let app = launch()
        openExampleDetails(app)
        scrollTo(app.images["qrImage"], app: app)
        let image = app.images["qrImage"].frame
        let viewport = app.scrollViews["nodeDetails"].frame
        XCTAssertGreaterThanOrEqual(image.minY, viewport.minY)
        XCTAssertLessThanOrEqual(image.maxY, viewport.maxY)
        XCTAssertGreaterThanOrEqual(image.minX, viewport.minX)
        XCTAssertLessThanOrEqual(image.maxX, viewport.maxX)
        attach(app, "QR-滚动后完整二维码")
    }

    /// 为无法稳定返回几何范围的模拟器保留实际像素截图，单独进行视觉回读。
    @MainActor
    func testQRCodeWorkspaceScreenshot() {
        let app = launch()
        openExampleDetails(app)
        XCTAssertTrue(app.images["qrImage"].exists)
        attach(app, "Glass-iOS-二维码工作区像素")
    }

    @MainActor
    func testJSONPreviewSharedUDPAndCancelExport() throws {
        let app = launch()
        openExampleDetails(app)
        setUDP(app)
        select(.json, app: app)
        let preview = app.staticTexts["jsonPreview"]
        let initial = try jsonObject(preview)
        XCTAssertEqual(initial["udp"] as? Int, 1)
        select(.yaml, app: app)
        XCTAssertTrue(text(app.staticTexts["yamlPreview"]).contains("udp: true"))
        select(.json, app: app)
        XCTAssertEqual(try jsonObject(preview)["uuid"] as? String, initial["uuid"] as? String)
        app.buttons["exportJSON"].tap()
        XCTAssertTrue(saveButton(app).waitForExistence(timeout: 15))
        cancelSave(app)
        XCTAssertTrue(app.buttons["exportJSON"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["导出"].exists)
        XCTAssertEqual(try jsonObject(preview)["uuid"] as? String, initial["uuid"] as? String)
        attach(app, "Glass-iOS-JSON")
    }

    @MainActor
    func testURLPreviewSharedUDPAndCancelExport() throws {
        let app = launch()
        openExampleDetails(app)
        select(.url, app: app)
        let preview = app.staticTexts["urlPreview"]
        XCTAssertTrue(text(preview).hasSuffix("&udp=0"))
        setUDP(app)
        let snapshot = text(preview)
        XCTAssertTrue(snapshot.hasSuffix("&udp=1"))
        select(.json, app: app)
        let original = try jsonObject(app.staticTexts["jsonPreview"])
        XCTAssertEqual(original["udp"] as? Int, 1)
        select(.yaml, app: app)
        XCTAssertTrue(text(app.staticTexts["yamlPreview"]).contains("udp: true"))
        select(.url, app: app)
        XCTAssertEqual(text(preview), snapshot)
        app.buttons["exportURL"].tap()
        XCTAssertTrue(saveButton(app).waitForExistence(timeout: 15))
        cancelSave(app)
        XCTAssertTrue(app.buttons["exportURL"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["导出"].exists)
        XCTAssertEqual(text(preview), snapshot)
        attach(app, "URL-iOS-即时预览与取消")
        select(.json, app: app)
        XCTAssertEqual(try jsonObject(app.staticTexts["jsonPreview"])["uuid"] as? String, original["uuid"] as? String)
    }

    @MainActor
    func testBackNavigationPreservesOptionsAndCopyUsesOriginalText() throws {
        let app = launch()
        openExampleDetails(app)
        app.buttons["nodeDisclosure"].tap()
        XCTAssertTrue(app.buttons["togglePassword"].waitForExistence(timeout: 5))
        app.buttons["togglePassword"].tap()
        setUDP(app)
        select(.json, app: app)
        let snapshot = text(app.staticTexts["jsonPreview"])
        // 紧凑布局具有系统返回按钮；宽分栏直接保留导入栏。
        let back = app.buttons.matching(NSPredicate(
            format: "identifier == %@ OR label == %@ OR label == %@ OR label == %@",
            "BackButton", "Proxy Studio", "返回", "Back")).firstMatch
        if back.exists {
            back.tap()
            let result = app.buttons["nodeResult"]
            scrollTo(result, app: app, isImport: true)
            result.tap()
        }
        XCTAssertTrue(app.buttons["exportJSON"].waitForExistence(timeout: 5))
        XCTAssertEqual(text(app.staticTexts["jsonPreview"]), snapshot)
        scrollTo(app.buttons["togglePassword"], app: app)
        XCTAssertEqual(app.staticTexts["nodePassword"].value as? String, "example-password")
        app.buttons["copyOutput"].tap()
        // 反馈会自动消失；用后续主动粘贴核对真正复制的原始内容。
        if back.exists { back.tap() }
        let paste = app.buttons["粘贴代理链接"]
        scrollTo(paste, app: app, isImport: true)
        paste.tap()
        let allow = app.buttons["允许粘贴"]
        if allow.waitForExistence(timeout: 2) { allow.tap() }
        let editor = app.descendants(matching: .any)["proxyLinkInput"].firstMatch
        XCTAssertEqual(editor.value as? String, snapshot)
        XCTAssertFalse(app.buttons["nodeResult"].exists)
        attach(app, "Glass-iOS-复制与输入失效")
    }

    @MainActor
    func testURLBackNavigationAndCopyUsesOriginalText() throws {
        let app = launch()
        openExampleDetails(app)
        app.buttons["nodeDisclosure"].tap()
        XCTAssertTrue(app.buttons["togglePassword"].waitForExistence(timeout: 5))
        app.buttons["togglePassword"].tap()
        setUDP(app)
        select(.url, app: app)
        let snapshot = text(app.staticTexts["urlPreview"])
        // 紧凑布局具有系统返回按钮；宽分栏直接保留导入栏。
        let back = app.buttons.matching(NSPredicate(
            format: "identifier == %@ OR label == %@ OR label == %@ OR label == %@",
            "BackButton", "Proxy Studio", "返回", "Back")).firstMatch
        if back.exists {
            back.tap()
            let result = app.buttons["nodeResult"]
            scrollTo(result, app: app, isImport: true)
            result.tap()
        }
        XCTAssertTrue(app.buttons["exportURL"].waitForExistence(timeout: 5))
        XCTAssertEqual(text(app.staticTexts["urlPreview"]), snapshot)
        scrollTo(app.buttons["togglePassword"], app: app)
        XCTAssertEqual(app.staticTexts["nodePassword"].value as? String, "example-password")
        app.buttons["copyOutput"].tap()
        // 反馈会自动消失；用后续主动粘贴核对真正复制的原始内容。
        if back.exists { back.tap() }
        let paste = app.buttons["粘贴代理链接"]
        scrollTo(paste, app: app, isImport: true)
        paste.tap()
        let allow = app.buttons["允许粘贴"]
        if allow.waitForExistence(timeout: 2) { allow.tap() }
        let editor = app.descendants(matching: .any)["proxyLinkInput"].firstMatch
        XCTAssertEqual(editor.value as? String, snapshot)
        XCTAssertFalse(app.buttons["nodeResult"].exists)
        attach(app, "URL-iOS-复制与输入失效")
    }

    @MainActor
    func testJSONPreviewAtAccessibilityTextSize() {
        let app = launch(large: true)
        openExampleDetails(app)
        select(.json, app: app)
        XCTAssertTrue(app.staticTexts["jsonPreview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportJSON"].isHittable)
        XCTAssertTrue(app.buttons["copyOutput"].isHittable)
        attach(app, "Glass-iOS-辅助功能JSON")
    }

    @MainActor
    func testURLPreviewAtAccessibilityTextSize() {
        let app = launch(large: true)
        openExampleDetails(app)
        select(.url, app: app)
        XCTAssertTrue(app.staticTexts["urlPreview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportURL"].isHittable)
        XCTAssertTrue(app.buttons["copyOutput"].isHittable)
        attach(app, "URL-iOS-辅助功能URL")
    }

    @MainActor
    func testAccessibilityTextSize() {
        let app = launch(large: true)
        openExampleDetails(app)
        scrollTo(app.buttons["nodeDisclosure"], app: app)
        app.buttons["nodeDisclosure"].tap()
        scrollTo(app.buttons["togglePassword"], app: app)
        XCTAssertTrue(app.buttons["togglePassword"].isHittable)
        XCTAssertTrue(app.buttons["exportPNG"].isHittable)
        attach(app, "Glass-iOS-辅助功能二维码")
    }

    @MainActor
    func testImportPreviewAndRotate() throws {
        let app = launch()
        openExampleDetails(app)
        XCTAssertFalse(app.buttons["togglePassword"].exists)
        app.buttons["nodeDisclosure"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["protocolRow"].exists)
        attach(app, "Glass-iOS-二维码")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["exportPNG"].waitForExistence(timeout: 5))
        select(.yaml, app: app)
        XCTAssertTrue(app.staticTexts["yamlPreview"].waitForExistence(timeout: 5))
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(app.buttons["exportYAML"].frame.minX, screen.minX)
        XCTAssertLessThanOrEqual(app.buttons["exportYAML"].frame.maxX, screen.maxX)
        attach(app, "Glass-iOS-旋转请求后YAML")
        app.buttons["exportYAML"].tap()
        XCTAssertTrue(saveButton(app).waitForExistence(timeout: 15))
        cancelSave(app)
        XCTAssertFalse(app.alerts["导出"].exists)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testDarkAppearanceAndShareMenu() {
        let app = launch(dark: true)
        openExampleDetails(app)
        app.buttons["shareMenu"].tap()
        XCTAssertTrue(app.buttons["sharePNG"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shareLink"].exists)
        app.buttons["sharePNG"].tap()
        let activity = app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@ OR label == %@ OR label == %@", "拷贝", "Copy", "存储到文件")).firstMatch
        XCTAssertTrue(activity.waitForExistence(timeout: 10))
        attach(app, "Glass-iOS-深色分享面板")
    }

    @MainActor
    func testShadowrocketPNGSaveWithUDP() throws {
        let app = launch()
        openExampleDetails(app)
        setUDP(app)
        app.buttons["exportPNG"].tap()
        finishSave(app, suffix: "glass-png")
    }

    @MainActor
    func testJSONSaveSuccess() throws {
        let app = launch()
        openExampleDetails(app)
        select(.json, app: app)
        let snapshot = Data(text(app.staticTexts["jsonPreview"]).utf8)
        let attachment = XCTAttachment(data: snapshot, uniformTypeIdentifier: "public.json")
        attachment.name = "Glass-iOS-JSON原始字节"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["exportJSON"].tap()
        finishSave(app, suffix: "glass-json")
    }

    @MainActor
    func testURLSaveSuccess() throws {
        let app = launch()
        openExampleDetails(app)
        select(.url, app: app)
        let snapshot = Data(text(app.staticTexts["urlPreview"]).utf8)
        let attachment = XCTAttachment(data: snapshot, uniformTypeIdentifier: "public.plain-text")
        attachment.name = "URL-iOS-预览原始字节"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["exportURL"].tap()
        finishSave(app, suffix: "url-export")
    }

    @MainActor
    func testYAMLSaveSuccess() throws {
        let app = launch()
        openExampleDetails(app)
        setUDP(app)
        select(.yaml, app: app)
        let attachment = XCTAttachment(data: Data(text(app.staticTexts["yamlPreview"]).utf8),
                                      uniformTypeIdentifier: "public.plain-text")
        attachment.name = "Glass-iOS-YAML原始字节"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["exportYAML"].tap()
        finishSave(app, suffix: "glass-yaml")
    }

    @MainActor
    func testRTLWorkspaceAndLiveJSON() throws {
        let app = launch(rtl: true)
        openExampleDetails(app)
        select(.json, app: app)
        setUDP(app)
        XCTAssertEqual(try jsonObject(app.staticTexts["jsonPreview"])["udp"] as? Int, 1)
        XCTAssertTrue(app.buttons["exportJSON"].isHittable)
        XCTAssertTrue(app.buttons["copyOutput"].isHittable)
        attach(app, "Glass-iOS-RTLJSON")
    }

    private enum Format: String { case qr = "二维码", yaml = "Clash YAML", json = "Shadowrocket JSON", url = "Shadowrocket URL" }

    @MainActor
    private func select(_ format: Format, app: XCUIApplication) {
        let picker = app.descendants(matching: .any)["outputPicker"].firstMatch
        scrollTo(picker, app: app)
        let full = app.buttons[format.rawValue].firstMatch
        let short = app.buttons[format == .url ? "URL" : format == .json ? "JSON" : format == .yaml ? "YAML" : "二维码"].firstMatch
        if full.isHittable { full.tap() }
        else if short.isHittable { short.tap() }
        else {
            picker.tap()
            XCTAssertTrue(full.waitForExistence(timeout: 5))
            full.tap()
        }
        XCTAssertTrue(app.buttons[format == .url ? "exportURL" : format == .qr ? "exportPNG" : format == .yaml ? "exportYAML" : "exportJSON"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launch(large: Bool = false, dark: Bool = false, rtl: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", rtl ? "(ar)" : "(zh-Hans)", "-AppleLocale", rtl ? "ar_SA" : "zh_CN",
                               "-UIPreferredContentSizeCategoryName", large ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
                               "-AppleInterfaceStyle", dark ? "Dark" : "Light"]
        if rtl { app.launchArguments.append("-ProxyStudioRTL") }
        app.launch()
        return app
    }

    @MainActor
    private func openExampleDetails(_ app: XCUIApplication) {
        let sample = app.buttons["试用示例节点"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        scrollTo(sample, app: app, isImport: true)
        sample.tap()
        scrollTo(app.buttons["parseButton"], app: app, isImport: true)
        app.buttons["parseButton"].tap()
        // 无需点击解析结果，直接进入工作区。
        XCTAssertTrue(app.buttons["exportPNG"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["udpToggle"].exists)
    }

    @MainActor
    private func setUDP(_ app: XCUIApplication) {
        let udp = app.switches["udpToggle"]
        scrollTo(udp, app: app)
        guard udp.value as? String != "1" else { return }
        udp.tap()
        // 部分系统将标签和开关合并为同一辅助功能元素；默认命中点未切换时再点击控件一侧。
        if udp.value as? String != "1" {
            let controlPosition = app.launchArguments.contains("-ProxyStudioRTL") ? 0.1 : 0.9
            udp.coordinate(withNormalizedOffset: CGVector(dx: controlPosition, dy: 0.5)).tap()
        }
        XCTAssertEqual(udp.value as? String, "1")
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, app: XCUIApplication, isImport: Bool = false) {
        let container = app.scrollViews[isImport ? "importScroll" : "nodeDetails"].firstMatch
        for direction in [true, false] {
            for _ in 0..<18 {
                // SwiftUI 在 iPad 上可能将仅露出边缘的按钮报告为可点击。
                // 填入多行示例后控件还会下移，必须确认整项进入滚动视口。
                let visibleFrame = container.frame.intersection(app.frame).insetBy(dx: 0, dy: 12)
                if element.isHittable && visibleFrame.contains(element.frame) { return }
                // 大字体下底部操作区较高，默认 swipe 的起点可能落在玻璃按钮上。
                let upper = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                let lower = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                if direction { lower.press(forDuration: 0.01, thenDragTo: upper) }
                else { upper.press(forDuration: 0.01, thenDragTo: lower) }
            }
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func text(_ element: XCUIElement) -> String { element.value as? String ?? element.label }

    @MainActor
    private func jsonObject(_ element: XCUIElement) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text(element).utf8)) as? [String: Any])
    }

    @MainActor
    private func saveButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "DOCPicker.actionButton", "保存")).firstMatch
    }

    /// 有些系统位置页只显示返回箭头，允许通过系统 sheet 下拉取消。
    @MainActor
    private func cancelSave(_ app: XCUIApplication) {
        let cancel = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@ OR identifier == %@",
                                                     "取消", "Cancel", "DOCPicker.cancelButton")).firstMatch
        if cancel.waitForExistence(timeout: 2) { cancel.tap() }
        else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.095))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        }
    }

    @MainActor
    private func finishSave(_ app: XCUIApplication, suffix: String) {
        let save = saveButton(app)
        // 系统可能恢复上一次尚未处理的同名文件确认页。
        if !keepBothIfPresented(app) {
            XCTAssertTrue(save.waitForExistence(timeout: 15))
            let filename = app.textFields["DOCPicker.filenameTextField"]
            if filename.exists {
                filename.tap(); filename.doubleTap()
                filename.typeText("-" + suffix + "-" + UUID().uuidString.prefix(8))
            }
            save.tap()
            _ = keepBothIfPresented(app)
        }
        XCTAssertTrue(app.alerts["导出"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.alerts["导出"].staticTexts["文件已保存。"].exists)
        attach(app, "Glass-iOS-实际保存成功")
    }

    /// 原生确认页可能属于文件管理器或 SpringBoard，而非应用自身。
    @MainActor
    private func keepBothIfPresented(_ app: XCUIApplication) -> Bool {
        for owner in [app, XCUIApplication(bundleIdentifier: "com.apple.DocumentManager.DockFolderViewService"),
                      XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp"),
                      XCUIApplication(bundleIdentifier: "com.apple.springboard")] {
            let keepBoth = owner.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "保留两者", "Keep Both")).firstMatch
            if keepBoth.waitForExistence(timeout: 2) { keepBoth.tap(); return true }
        }
        return false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
