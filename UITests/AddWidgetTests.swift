import XCTest

// Puts the Lexicist widget on the simulator's Lock Screen the way a person would: long press, Customize, Lock Screen,
// the widget area, Lexicist, the rectangular widget, Done. Every step leaves a screenshot and the SpringBoard tree as
// attachments, so a failed step can be read from the result bundle and fixed. The test never fails on a missing button;
// it tries the next way and goes on, so one run shows as much as possible.
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

  @discardableResult
  func tapFirst(_ labels: [String], timeout: TimeInterval = 4) -> Bool {
    for l in labels {
      let q = sb.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@", l, l)).firstMatch
      if q.waitForExistence(timeout: timeout), q.isHittable { q.tap(); sleep(2); return true }
    }
    return false
  }

  @discardableResult
  func tapContaining(_ text: String, timeout: TimeInterval = 4) -> Bool {
    let q = sb.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    if q.waitForExistence(timeout: timeout), q.isHittable { q.tap(); sleep(2); return true }
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
    // lock, then wake to the Lock Screen
    XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    sleep(2)
    XCUIDevice.shared.press(.home)
    sleep(3)
    snap("lock")
    // long press the Lock Screen to edit it
    sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 2.5)
    sleep(3)
    snap("after-long-press")
    if !tapFirst(["Customize", "Customise"]) { tapContaining("Customi") }
    sleep(2)
    snap("after-customize")
    // iOS asks which to customize: the Lock Screen (left) or the Home Screen
    if !tapFirst(["Lock Screen"]) {
      sb.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.5)).tap()
      sleep(2)
    }
    snap("editing-lock-screen")
    // the widget area under the clock
    if !tapContaining("Add Widgets") && !tapContaining("widget") {
      sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.36)).tap()
      sleep(2)
    }
    snap("widget-gallery")
    // find Lexicist in the gallery: by its name, else by search
    if !tapContaining("Lexicist", timeout: 3) {
      let search = sb.searchFields.firstMatch
      if search.waitForExistence(timeout: 3) {
        search.tap()
        search.typeText("Lexicist")
        sleep(2)
        snap("searched")
        tapContaining("Lexicist", timeout: 3)
      } else {
        sb.swipeUp()
        sleep(2)
        snap("scrolled")
        tapContaining("Lexicist", timeout: 3)
      }
    }
    snap("lexicist-widgets")
    // the first widget preview of Lexicist (rectangular comes first, then inline)
    let preview = sb.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Word' OR label CONTAINS[c] 'Lexicist'")).element(boundBy: 0)
    if preview.waitForExistence(timeout: 3), preview.isHittable { preview.tap(); sleep(2) }
    snap("after-pick")
    // close the gallery and finish editing
    tapFirst(["Close", "Dismiss"])
    snap("gallery-closed")
    tapFirst(["Done"])
    sleep(2)
    snap("done")
    // back on the Lock Screen with the widget
    XCUIDevice.shared.press(.home)
    sleep(2)
    XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
    sleep(2)
    XCUIDevice.shared.press(.home)
    sleep(3)
    snap("final-lock-screen")
  }
}
