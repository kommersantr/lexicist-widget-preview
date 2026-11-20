import XCTest

// Puts the Lexicist widget on the simulator's Lock Screen the way a person would: long press, Customize, the widget area
// ("Add Widget"), Lexicist in the gallery, the "Today's words" widget, Close, Done. Every step leaves a screenshot and the
// SpringBoard tree as attachments, so a failed step can be read from the result bundle and fixed. The test never fails on a
// missing button; it goes on, so one run shows as much as possible.
final class AddWidgetTests: XCTestCase {
  let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
  var step = 0

  func snap(_ name: String, tree: Bool = true) {
    step += 1
    let tag = String(format: "%02d-%@", step, name)
    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    shot.name = tag
    shot.lifetime = .keepAlways
    add(shot)
    if tree {
      let t = XCTAttachment(string: sb.debugDescription)
      t.name = tag + "-tree"
      t.lifetime = .keepAlways
      add(t)
    }
  }

  // taps the first hittable element whose label or identifier matches; true if something was tapped
  @discardableResult
  func tapWhere(_ format: String, _ args: [Any], timeout: TimeInterval = 4) -> Bool {
    let q = sb.descendants(matching: .any).matching(NSPredicate(format: format, argumentArray: args))
    _ = q.firstMatch.waitForExistence(timeout: timeout)
    let n = min(q.count, 12)
    for i in 0..<n {
      let e = q.element(boundBy: i)
      if e.exists && e.isHittable { e.tap(); sleep(2); return true }
    }
    return false
  }

  func testAddLockScreenWidget() throws {
    continueAfterFailure = true
    let app = XCUIApplication()
    app.launch()
    _ = app.staticTexts["seeded"].waitForExistence(timeout: 10)
    sleep(2)
    snap("app", tree: false)
    XCUIDevice.shared.press(.home)
    sleep(2)
    XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    sleep(2)
    XCUIDevice.shared.press(.home)
    sleep(3)
    snap("lock", tree: false)
    sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 2.5)
    sleep(3)
    tapWhere("label ==[c] %@ OR label ==[c] %@", ["Customize", "Customise"])
    sleep(2)
    tapWhere("label ==[c] %@", ["Lock Screen"], timeout: 2)
    snap("editing")
    // the widget area under the clock
    // a real touch in the middle of the "Add Widget" area (a tap on the element itself did not open the gallery)
    let reticle = sb.descendants(matching: .any).matching(identifier: "grouped-widgets-reticle-view").firstMatch
    if reticle.waitForExistence(timeout: 5) {
      let f = reticle.frame
      sb.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
    }
    sleep(4)
    snap("gallery")
    let galleryOpen = sb.searchFields.firstMatch.exists || sb.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Lexicist'")).count > 0
    // Lexicist in the gallery: as it is, after scrolling, or by search
    var found = tapWhere("label CONTAINS[c] %@", ["Lexicist"], timeout: 3)
    var tries = 0
    while galleryOpen && !found && tries < 4 {
      let sheet = sb.scrollViews.firstMatch
      if sheet.exists { sheet.swipeUp() } else { sb.swipeUp() }
      sleep(2)
      tries += 1
      found = tapWhere("label CONTAINS[c] %@", ["Lexicist"], timeout: 2)
    }
    if !found {
      let search = sb.searchFields.firstMatch
      if search.waitForExistence(timeout: 3) {
        search.tap()
        search.typeText("Lexicist")
        sleep(2)
        found = tapWhere("label CONTAINS[c] %@", ["Lexicist"], timeout: 3)
      }
    }
    snap(found ? "lexicist-widgets" : "lexicist-not-found")
    // the widget itself ("Today's words"); the rectangular one comes first
    tapWhere("label CONTAINS[c] %@ OR label CONTAINS[c] %@", ["Today", "words"], timeout: 4)
    snap("after-pick")
    tapWhere("label ==[c] %@ OR identifier ==[c] %@", ["Close", "close-button"], timeout: 3)
    snap("gallery-closed")
    tapWhere("identifier == %@ OR label ==[c] %@", ["editing-done", "Done"], timeout: 4)
    sleep(2)
    snap("done")
    // any follow-up sheet after Done (wallpaper pair, etc.)
    if tapWhere("label ==[c] %@ OR label ==[c] %@", ["Set as Wallpaper Pair", "Done"], timeout: 2) { snap("follow-up") }
    XCUIDevice.shared.press(.home)
    sleep(2)
    XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    sleep(2)
    XCUIDevice.shared.press(.home)
    sleep(3)
    snap("final-lock-screen")
  }
}
