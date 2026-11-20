// Today's words on the Home Screen and the Lock Screen.
// The app writes today's three words into the shared App Group.
// Home Screen: small and medium show one word, large shows all three; Edit Widget picks the color.
// Lock Screen: three fonts to pick in Edit Widget, as Vocabulary lets its readers pick a font there
// (Monkey Taps help, 07.11.2026). "Simple" copies Vocabulary's Lock Screen widget: the word in capitals,
// "(n.) meaning" under it, no box (owner 07.11.2026, his screenshot of TOMMYROT). Jost and Bold keep that layout.
// The owner approved these three only (07.11.2026), the others were unreadable; Bold is the default («6 bold самый лучший»).
// Nothing on the Lock Screen is smaller than Simple: lowercase at least 7.4 pt high, capitals at least 10.6 pt.
import AppIntents
import CoreText
import SwiftUI
import UIKit
import WidgetKit

private let appGroup = "group.com.lexicist.app"

// MARK: - Fonts

// Jost ships inside the widget (Info.plist UIAppFonts).
// If iOS has not picked it up, register it from the bundle once.
private let fontsReady: Bool = {
  if UIFont(name: "Jost-Regular", size: 12) == nil || UIFont(name: "Jost-Medium", size: 12) == nil {
    for file in ["LexJost-Regular", "LexJost-Medium"] {
      if let url = Bundle.main.url(forResource: file, withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
  return true
}()

private enum LexFont {
  static func jost(_ size: CGFloat) -> Font {
    _ = fontsReady
    return .custom("Jost-Regular", fixedSize: size)
  }

  static func jostMedium(_ size: CGFloat) -> Font {
    _ = fontsReady
    return .custom("Jost-Medium", fixedSize: size)
  }
}

// MARK: - Colors

struct Palette {
  let bg: Color
  let ink: Color
  let muted: Color
  let line: Color
}

private func rgb(_ hex: UInt32) -> Color {
  Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

// The same four looks as Settings > Look in the app (colors from app.html).
private func palette(_ theme: String) -> Palette {
  switch theme {
  case "white": return Palette(bg: rgb(0xFFFFFF), ink: rgb(0x141512), muted: rgb(0x55564F), line: rgb(0xDDDCD3))
  case "paper": return Palette(bg: rgb(0xF1F0E9), ink: rgb(0x141512), muted: rgb(0x55564F), line: rgb(0xD6D5CA))
  case "stone": return Palette(bg: rgb(0x23241F), ink: rgb(0xF1F0E9), muted: rgb(0xC0C1B7), line: rgb(0x45463F))
  default: return Palette(bg: rgb(0x0E0F0D), ink: rgb(0xF1F0E9), muted: rgb(0xB4B5AB), line: rgb(0x33342E))
  }
}

// Paper in light mode, the soft stone grey in dark mode: the widget blends in like Vocabulary's instead of a black block.
private func quiet(_ scheme: ColorScheme) -> Palette {
  scheme == .dark ? palette("stone") : palette("paper")
}

// MARK: - Words

struct LexWord: Codable, Hashable {
  let w: String
  let d: String
  let i: String?
  let g: String?
}

// Real cards from the library, shown in the widget gallery before the app has sent anything.
private let samples = [
  LexWord(w: "manumit", d: "to free from slavery", i: "/ˌmænjəˈmɪt/", g: "verb"),
  LexWord(w: "susurrus", d: "a whispering or rustling sound", i: "/səˈsɝ.əs/", g: "noun"),
  LexWord(w: "halcyon", d: "peaceful and happy, usually of the past", i: "/ˈhæl.si.ən/", g: "adjective"),
]

private func todayWords() -> [LexWord] {
  guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: "today"),
        let data = raw.data(using: .utf8),
        let words = try? JSONDecoder().decode([LexWord].self, from: data) else { return [] }
  return words
}

// A new word every hour (owner 16.11.2026): the app hands over 24 words for each of the next 7 days, keyed "2026-11-16".
private struct HourlyDay: Codable {
  let d: String
  let words: [LexWord]
}

private func hourlyTable() -> [String: [LexWord]] {
  guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: "hourly"),
        let data = raw.data(using: .utf8),
        let days = try? JSONDecoder().decode([HourlyDay].self, from: data) else { return [:] }
  var t: [String: [LexWord]] = [:]
  for day in days where !day.words.isEmpty { t[day.d] = day.words }
  return t
}

private func dayKey(_ date: Date) -> String {
  let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
  return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
}

private func wordURL(_ w: LexWord?) -> URL {
  let slug = w?.w.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
  return URL(string: "lexicist://word/" + slug) ?? URL(string: "lexicist://")!
}

// "n.", "v.", "adj." for the part of speech
private func posAbbr(_ g: String?) -> String {
  guard let g = g?.lowercased(), !g.isEmpty else { return "" }
  let m = ["noun": "n.", "verb": "v.", "adjective": "adj.", "adverb": "adv.", "pronoun": "pron.", "preposition": "prep.", "conjunction": "conj.", "interjection": "interj."]
  return m[g] ?? g
}

// "(v.) to free from slavery", the way Vocabulary writes it
private func meaningLine(_ w: LexWord?, _ fallback: String) -> String {
  guard let w = w else { return fallback }
  let p = posAbbr(w.g)
  return p.isEmpty ? w.d : "(" + p + ") " + w.d
}

private let emptyHint = "Open Lexicist to get today’s words"

// MARK: - Edit Widget

enum ChangeEvery: String, AppEnum, CaseIterable {
  case hour, threeHours, day

  static var typeDisplayRepresentation: TypeDisplayRepresentation { "Change the word" }
  static var caseDisplayRepresentations: [ChangeEvery: DisplayRepresentation] {
    [.hour: "Every hour", .threeHours: "Every 3 hours", .day: "Once a day"]
  }

  var hours: Int {
    switch self {
    case .hour: return 1
    case .threeHours: return 3
    case .day: return 24
    }
  }
}

enum HomeColor: String, AppEnum, CaseIterable {
  case auto, paper, stone, black, white

  static var typeDisplayRepresentation: TypeDisplayRepresentation { "Color" }
  static var caseDisplayRepresentations: [HomeColor: DisplayRepresentation] {
    [.auto: "Light or dark, as the iPhone", .paper: "Paper", .stone: "Stone", .black: "Black", .white: "White"]
  }
}

enum LockLook: String, AppEnum, CaseIterable {
  case simple, jost, bold

  static var typeDisplayRepresentation: TypeDisplayRepresentation { "Font" }
  static var caseDisplayRepresentations: [LockLook: DisplayRepresentation] {
    [.simple: "Simple", .jost: "Jost", .bold: "Bold"]
  }
}

// Home Screen settings. The name stays WordSettings so widgets already placed keep their choice.
struct WordSettings: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Today’s words" }
  static var description: IntentDescription { "Choose the color and how often the word changes." }

  @Parameter(title: "Change the word", default: .hour)
  var every: ChangeEvery

  @Parameter(title: "Color", default: .auto)
  var color: HomeColor
}

struct LockSettings: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Word on the Lock Screen" }
  static var description: IntentDescription { "Choose the font and how often the word changes." }

  @Parameter(title: "Font", default: .bold)
  var look: LockLook

  @Parameter(title: "Change the word", default: .hour)
  var every: ChangeEvery
}

// MARK: - Timeline

struct WordEntry: TimelineEntry {
  let date: Date
  let words: [LexWord]
  let index: Int
  var look: LockLook = .bold
  var color: HomeColor = .auto
  // the word of this hour, when the app has sent the hourly words
  var one: LexWord? = nil

  var word: LexWord? { one ?? (words.isEmpty ? nil : words[index % words.count]) }
}

private func wordTimeline(_ every: ChangeEvery, look: LockLook = .bold, color: HomeColor = .auto) -> Timeline<WordEntry> {
  let words = todayWords()
  let now = Date()
  let cal = Calendar.current
  let step = every.hours
  let hourly = step < 24 ? hourlyTable() : [:]
  guard !words.isEmpty || !hourly.isEmpty else {
    return Timeline(entries: [WordEntry(date: now, words: [], index: 0, look: look, color: color)], policy: .after(now.addingTimeInterval(3600)))
  }
  if step >= 24 {
    // once a day: a different one of the three each day, changing at midnight
    let day = cal.ordinality(of: .day, in: .era, for: now) ?? 0
    let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
    return Timeline(entries: [WordEntry(date: now, words: words, index: day % words.count, look: look, color: color)], policy: .after(midnight))
  }
  let start = cal.dateInterval(of: .hour, for: now)?.start ?? now
  let entries = (0..<24).compactMap { h -> WordEntry? in
    guard let d = cal.date(byAdding: .hour, value: h, to: start) else { return nil }
    let slot = cal.component(.hour, from: d) / step
    // every hour a different word of that day; without the hourly words, today's three in turn as before
    if let day = hourly[dayKey(d)], !day.isEmpty {
      return WordEntry(date: d, words: words, index: 0, look: look, color: color, one: day[slot % day.count])
    }
    guard !words.isEmpty else { return WordEntry(date: d, words: [], index: 0, look: look, color: color) }
    return WordEntry(date: d, words: words, index: slot % words.count, look: look, color: color)
  }
  return Timeline(entries: entries, policy: .atEnd)
}

private func snapshotWords() -> [LexWord] {
  let words = todayWords()
  return words.isEmpty ? samples : words
}

struct HomeProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> WordEntry {
    WordEntry(date: .now, words: samples, index: 0)
  }

  func snapshot(for configuration: WordSettings, in context: Context) async -> WordEntry {
    WordEntry(date: .now, words: snapshotWords(), index: 0, color: configuration.color)
  }

  func timeline(for configuration: WordSettings, in context: Context) async -> Timeline<WordEntry> {
    wordTimeline(configuration.every, color: configuration.color)
  }
}

struct LockProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> WordEntry {
    WordEntry(date: .now, words: samples, index: 0)
  }

  func snapshot(for configuration: LockSettings, in context: Context) async -> WordEntry {
    WordEntry(date: .now, words: snapshotWords(), index: 0, look: configuration.look)
  }

  func timeline(for configuration: LockSettings, in context: Context) async -> Timeline<WordEntry> {
    wordTimeline(configuration.every, look: configuration.look)
  }
}

// MARK: - Home Screen views

struct HomeWordView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  let entry: WordEntry

  private var p: Palette { entry.color == .auto ? quiet(scheme) : palette(entry.color.rawValue) }
  private var word: String { entry.word?.w ?? "Lexicist" }

  var body: some View {
    if family == .systemLarge {
      ThreeWordsView(words: entry.words, p: p)
    } else {
      VStack(spacing: family == .systemSmall ? 6 : 8) {
        Spacer(minLength: 0)
        Text(word)
          .font(.system(size: family == .systemSmall ? 24 : 30, weight: .bold, design: .serif))
          .foregroundStyle(p.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
        Text(meaningLine(entry.word, "Open the app to get today’s words"))
          .font(.system(size: family == .systemSmall ? 13 : 15))
          .foregroundStyle(p.muted)
          .multilineTextAlignment(.center)
          .lineLimit(family == .systemSmall ? 4 : 3)
          .minimumScaleFactor(0.85)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 2)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .containerBackground(for: .widget) { p.bg }
    }
  }
}

// The large Home Screen size: all three of today's words, each one opens its own story.
struct ThreeWordsView: View {
  let words: [LexWord]
  let p: Palette

  var body: some View {
    let list = Array(words.prefix(3))
    VStack(alignment: .leading, spacing: 0) {
      Text("TODAY’S WORDS")
        .font(.system(size: 11, weight: .medium))
        .tracking(1.2)
        .foregroundStyle(p.muted)
        .padding(.bottom, 6)
      if list.isEmpty {
        Spacer(minLength: 0)
        Text(emptyHint)
          .font(.system(size: 16))
          .foregroundStyle(p.ink)
        Spacer(minLength: 0)
      } else {
        ForEach(Array(list.enumerated()), id: \.offset) { n, w in
          Link(destination: wordURL(w)) {
            VStack(alignment: .leading, spacing: 2) {
              Text(w.w)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(p.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
              Text(meaningLine(w, w.d))
                .font(.system(size: 14))
                .foregroundStyle(p.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          }
          if n < list.count - 1 {
            Rectangle().fill(p.line).frame(height: 1)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .containerBackground(for: .widget) { p.bg }
  }
}

// MARK: - Lock Screen views

struct LockWordView: View {
  @Environment(\.widgetFamily) private var family
  let entry: WordEntry

  private var w: LexWord? { entry.word }
  private var word: String { w?.w ?? "Lexicist" }

  var body: some View {
    Group {
      if family == .accessoryInline {
        Text(w.map { "\($0.w) · \($0.d)" } ?? emptyHint)
      } else {
        switch entry.look {
        case .simple: simple
        case .jost: jost
        case .bold: bold
        }
      }
    }
    .containerBackground(for: .widget) { Color.clear }
  }

  // As Vocabulary: TOMMYROT / (n.) Nonsense or foolish talk. System font, same size for both lines, no box.
  private var simple: some View {
    VStack(spacing: 0) {
      Text(word.uppercased())
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(meaningLine(w, emptyHint))
        .font(.system(size: 15))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // Jost, the app's list font, for both lines: the word in capitals with a little air between the letters.
  private var jost: some View {
    VStack(spacing: 0) {
      Text(word.uppercased())
        .font(LexFont.jostMedium(15.5))
        .tracking(1)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(meaningLine(w, emptyHint))
        .font(LexFont.jost(16))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // The owner's favourite (07.11.2026, «6 bold самый лучший»): system font, the word bold, lowercase and bigger.
  private var bold: some View {
    VStack(spacing: 0) {
      Text(word)
        .font(.system(size: 20, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(meaningLine(w, emptyHint))
        .font(.system(size: 15))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Widgets

struct WordWidget: Widget {
  let kind = "WordWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: WordSettings.self, provider: HomeProvider()) { entry in
      HomeWordView(entry: entry)
        .widgetURL(wordURL(entry.word))
    }
    .configurationDisplayName("Today’s words")
    .description("One of your three words for today, or all three on the large size.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct LockWordWidget: Widget {
  let kind = "LockWordWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: LockSettings.self, provider: LockProvider()) { entry in
      LockWordView(entry: entry)
        .widgetURL(wordURL(entry.word))
    }
    .configurationDisplayName("Today’s words")
    .description("A word on your Lock Screen. Tap it while editing the Lock Screen to pick a font.")
    .supportedFamilies([.accessoryRectangular, .accessoryInline])
  }
}

@main
struct LexicistWidgets: WidgetBundle {
  var body: some Widget {
    WordWidget()
    LockWordWidget()
  }
}
