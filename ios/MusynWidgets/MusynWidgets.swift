import SwiftUI
import WidgetKit

private let suite = "group.com.vorynlabs.musyn"

struct MusynEntry: TimelineEntry {
  let date: Date
  let title: String
  let artist: String
}

struct MusynProvider: TimelineProvider {
  func placeholder(in context: Context) -> MusynEntry {
    MusynEntry(date: .now, title: "Musyn", artist: "Your music, beautifully simple")
  }

  func getSnapshot(in context: Context, completion: @escaping (MusynEntry) -> Void) {
    completion(entry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MusynEntry>) -> Void) {
    completion(Timeline(entries: [entry()], policy: .never))
  }

  private func entry() -> MusynEntry {
    let defaults = UserDefaults(suiteName: suite)
    return MusynEntry(
      date: .now,
      title: defaults?.string(forKey: "widget.title") ?? "Nothing playing",
      artist: defaults?.string(forKey: "widget.artist") ?? "Open Musyn to start listening"
    )
  }
}

struct MusynWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: MusynEntry

  var body: some View {
    Link(destination: URL(string: "musyn://now-playing")!) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: "music.note")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color(red: 1, green: 0.77, blue: 0.65))
          Text("MUSYN")
            .font(.caption2.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(.secondary)
          Spacer()
          Image(systemName: "play.fill").font(.caption.weight(.bold))
        }
        Spacer(minLength: 0)
        Text(entry.title)
          .font(family == .systemSmall ? .headline : .title3.weight(.bold))
          .lineLimit(2)
        Text(entry.artist)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .padding(2)
    }
    .containerBackground(for: .widget) {
      LinearGradient(
        colors: [Color(red: 0.10, green: 0.09, blue: 0.11), .black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }
}

struct MusynNowPlayingWidget: Widget {
  let kind = "MusynNowPlayingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MusynProvider()) { entry in
      MusynWidgetView(entry: entry)
    }
    .configurationDisplayName("Now Playing")
    .description("Return to the music you were playing in Musyn.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct MusynWidgetBundle: WidgetBundle {
  var body: some Widget { MusynNowPlayingWidget() }
}
