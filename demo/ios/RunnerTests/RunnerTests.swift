import XCTest

// Drives actual UIKit accessibility input; Flutter checks logical coordinates,
// target counters, metrics and keyboard visibility in the application process.
final class RunnerTests: XCTestCase {
  override func tearDownWithError() throws {
    XCUIDevice.shared.orientation = .portrait
    XCUIApplication(bundleIdentifier: "dev.designscale.regression").terminate()
    try super.tearDownWithError()
  }

  func testNativeInteractionRegression() throws {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "dev.designscale.regression")
    app.launchArguments = ["--enable-checked-mode", "--verify-entry-points"]
    let originalOrientation = XCUIDevice.shared.orientation
    defer {
      XCUIDevice.shared.orientation = originalOrientation
      app.terminate()
    }
    XCUIDevice.shared.orientation = .portrait
    app.launch()
    let state = app.descendants(matching: .any)["regression-state"].firstMatch
    XCTAssertTrue(state.waitForExistence(timeout: 30), "Missing Flutter regression state")
    var handled = Set<Int>()
    let deadline = Date().addingTimeInterval(180)
    while Date() < deadline {
      let raw = (state.value as? String) ?? state.label
      guard let data = raw.data(using: .utf8),
            let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = event["type"] as? String else {
        Thread.sleep(forTimeInterval: 0.1)
        continue
      }
      if type == "failure" {
        XCTFail("Flutter regression failure: \(raw)")
        return
      }
      if type == "done" {
        let checks = try XCTUnwrap(event["checks"] as? [String])
        XCTAssertEqual(checks.count, 17, "Unexpected completion coverage")
        let attachment = XCTAttachment(string: raw)
        attachment.name = "Flutter native interaction checks"
        attachment.lifetime = .keepAlways
        add(attachment)
        add(XCTAttachment(screenshot: app.screenshot()))
        return
      }
      guard type == "action", let id = event["id"] as? Int,
            !handled.contains(id), let action = event["action"] as? String else {
        Thread.sleep(forTimeInterval: 0.1)
        continue
      }
      handled.insert(id)
      let width = try XCTUnwrap(event["physicalWidth"] as? Double)
      let height = try XCTUnwrap(event["physicalHeight"] as? Double)
      func coordinate(_ x: String, _ y: String) throws -> XCUICoordinate {
        let px = try XCTUnwrap(event[x] as? Double)
        let py = try XCTUnwrap(event[y] as? Double)
        return app.coordinate(withNormalizedOffset: CGVector(dx: px / width, dy: py / height))
      }
      switch action {
      case "tap":
        try coordinate("x", "y").tap()
      case "swipe":
        try coordinate("x1", "y1").press(forDuration: 0.05,
          thenDragTo: coordinate("x2", "y2"))
      case "text":
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        app.typeText(try XCTUnwrap(event["text"] as? String))
      case "back":
        app.typeText("\n") // TextInputAction.done submits and dismisses UIKit keyboard.
      case "rotation":
        XCUIDevice.shared.orientation = (event["value"] as? Int) == 1 ? .landscapeLeft : .portrait
      default:
        XCTFail("Unsupported native action: \(action)")
        return
      }
    }
    XCTFail("No completion event within 180 seconds; state=\(state.value ?? state.label)")
  }
}
