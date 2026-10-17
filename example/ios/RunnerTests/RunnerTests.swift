import XCTest

final class RunnerTests: XCTestCase {
  func testExampleLaunches() throws {
    let app = XCUIApplication(bundleIdentifier: "com.example.example")
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
    app.terminate()
  }
}
