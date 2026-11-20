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
    // Customize until the Lock Screen editor is open (the button sometimes ignores a tap during its animation)
    let editorDone = sb.descendants(matching: .any).matching(identifier: "editing-done").firstMatch
    for _ in 0..<4 {
      if editorDone.exists { break }
      let customize = sb.buttons.matching(identifier: "posterboard-customize-button").firstMatch
      if customize.waitForExistence(timeout: 4) {
        sleep(1)
        let f = customize.frame
        sb.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
      } else {
        sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 2.5)
      }
      sleep(3)
      tapWhere("label ==[c] %@", ["Lock Screen"], timeout: 1)
      _ = editorDone.waitForExistence(timeout: 3)
    }
    snap("editing")
    // the widget area under the clock
    // a real touch in the middle of the "Add Widget" area (a tap on the element itself did not open the gallery)
    let reticle = sb.descendants(matching: .any).matching(identifier: "grouped-widgets-reticle-view").firstMatch
    if reticle.waitForExistence(timeout: 5) {
      let f = reticle.frame
      sb.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
    }
    // the sheet opens half high and fills in a few seconds later; pull it up and wait for its content
    sleep(4)
    let grabber = sb.buttons["Sheet Grabber"]
    if grabber.waitForExistence(timeout: 3) {
      let g = grabber.frame
      sb.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: g.midX, dy: g.midY))
        .press(forDuration: 0.1, thenDragTo: sb.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: g.midX, dy: 120)))
    }
    for _ in 0..<6 {
      if sb.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Lexicist' OR label CONTAINS[c] 'Weather' OR label CONTAINS[c] 'Calendar,'")).count > 0 { break }
      sleep(3)
    }
    snap("gallery")
    let galleryOpen = sb.searchFields.firstMatch.exists || sb.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Lexicist'")).count > 0
    // Lexicist in the gallery: wait until the list stops moving, then tap its row by exact name
    sleep(3)
    var opened = false
    for attempt in 0..<3 {
      let cell = sb.cells.matching(NSPredicate(format: "label ==[c] %@", "Lexicist")).firstMatch
      if !cell.waitForExistence(timeout: 4) {
        let sheet = sb.scrollViews.firstMatch
        if sheet.exists { sheet.swipeUp() }
        sleep(2)
        continue
      }
      sleep(1)
      cell.tap()
      sleep(3)
      // our page shows the widget gallery for Lexicist; anything else means the tap hit another row
      let gallery = sb.scrollViews["complicationGalleryScrollView"]
      let mine = gallery.exists && sb.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Lexicist", "Today")).count > 0
      snap("opened-row-\(attempt)")
      if mine { opened = true; break }
      tapWhere("label ==[c] %@", ["close"], timeout: 2)
      sleep(2)
    }
    // tap the widget preview: the first preview tile in the gallery, else the middle of the preview row
    let sv = sb.scrollViews["complicationGalleryScrollView"]
    var picked = false
    if opened && sv.exists {
      let top = sv.frame.minY
      let tiles = sv.descendants(matching: .any).allElementsBoundByIndex.filter {
        let f = $0.frame
        return f.height > 40 && f.height < 150 && f.width > 40 && f.width < 300 && f.minY > top + 80
      }
      if let t = tiles.first(where: { $0.isHittable }) { t.tap(); picked = true }
      if !picked { sb.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: sv.frame.midX, dy: top + 200)).tap(); picked = true }
      sleep(3)
    }
    snap(picked ? "after-pick" : "not-picked")
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
