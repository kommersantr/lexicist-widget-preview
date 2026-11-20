import SwiftUI
import WidgetKit

// A stand-in for the Lexicist app, only so the iOS Simulator can show the real Lexicist widget for the App Store preview video.
// On launch it hands the widget the same data the Lexicist app hands it: today's three words ("today") and 24 words for each
// of the next 7 days ("hourly"), both taken from the Lexicist page for a new reader on 20.11.2026.
@main
struct LexicistPreviewApp: App {
  init() { Seed.run() }
  var body: some Scene {
    WindowGroup { ContentView() }
  }
}

enum Seed {
  static let appGroup = "group.com.lexicist.app"
  static func run() {
    let shared = UserDefaults(suiteName: appGroup)
    for key in ["today", "hourly"] {
      if let url = Bundle.main.url(forResource: key, withExtension: "json"),
         let text = try? String(contentsOf: url, encoding: .utf8) {
        shared?.set(text, forKey: key)
      }
    }
    shared?.synchronize()
    WidgetCenter.shared.reloadAllTimelines()
  }
}

struct ContentView: View {
  var body: some View {
    ZStack {
      Color(red: 14 / 255, green: 15 / 255, blue: 13 / 255).ignoresSafeArea()
      Text("Lexicist")
        .font(.system(size: 44, weight: .medium, design: .serif))
        .foregroundColor(Color(red: 241 / 255, green: 240 / 255, blue: 233 / 255))
        .accessibilityIdentifier("seeded")
    }
  }
}
