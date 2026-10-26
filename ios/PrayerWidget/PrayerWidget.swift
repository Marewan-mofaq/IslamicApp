import WidgetKit
import SwiftUI

// MARK: - App Group Configuration
private let appGroupId = "group.com.islamicapp.app"

// MARK: - Timeline Entry
struct PrayerEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let nextPrayer: String
    let nextKey: String
    let nextTime: String
    let remaining: String
    let fajr: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
}

// MARK: - Timeline Provider
struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(
            date: Date(),
            cityName: "هەولێر",
            nextPrayer: "نوێژی داهاتوو: مەغریب 🌆",
            nextKey: "Maghrib",
            nextTime: "06:15",
            remaining: "ماوە 35 خولەک",
            fajr: "04:30",
            dhuhr: "12:15",
            asr: "03:45",
            maghrib: "06:15",
            isha: "07:45"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh timeline every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> PrayerEntry {
        let prefs = UserDefaults(suiteName: appGroupId)
        let rawCity = prefs?.string(forKey: "widget_city") ?? "هەولێر"
        let city = rawCity.replacingOccurrences(of: "📍", with: "").trimmingCharacters(in: .whitespaces)
        let fajr = prefs?.string(forKey: "widget_fajr") ?? "--:--"
        let dhuhr = prefs?.string(forKey: "widget_dhuhr") ?? "--:--"
        let asr = prefs?.string(forKey: "widget_asr") ?? "--:--"
        let maghrib = prefs?.string(forKey: "widget_maghrib") ?? "--:--"
        let isha = prefs?.string(forKey: "widget_isha") ?? "--:--"

        // Dynamic next prayer & remaining time calculation
        let prayers = [
            ("Fajr", "بەیانی 🌅", fajr),
            ("Dhuhr", "نیوەڕۆ 🌤️", dhuhr),
            ("Asr", "عەسر 🌥️", asr),
            ("Maghrib", "مەغریب 🌆", maghrib),
            ("Isha", "عیشا 🌙", isha)
        ]

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute

        var computedKey = "Fajr"
        var computedDisplay = "بەیانی 🌅"
        var computedTime = fajr
        var diffMinutes: Int? = nil

        for p in prayers {
            if let m = parseMinutes(p.2), m > currentMinutes {
                computedKey = p.0
                computedDisplay = p.1
                computedTime = p.2
                diffMinutes = m - currentMinutes
                break
            }
        }

        if diffMinutes == nil {
            computedKey = "Fajr"
            computedDisplay = "بەیانی (سبەی) 🌅"
            computedTime = fajr
            if let fm = parseMinutes(fajr) {
                diffMinutes = (24 * 60 + fm) - currentMinutes
            }
        }

        let computedRemaining: String
        if let diff = diffMinutes {
            if diff <= 1 {
                computedRemaining = "کاتی بانگ هاتووە 📢"
            } else if diff < 60 {
                computedRemaining = "ماوە \(diff) خولەک"
            } else {
                let h = diff / 60
                let m = diff % 60
                computedRemaining = m > 0 ? "ماوە \(h) کاتژمێر و \(m) خولەک" : "ماوە \(h) کاتژمێر"
            }
        } else {
            computedRemaining = prefs?.string(forKey: "widget_remaining") ?? "ماوە بۆ بانگ"
        }

        let nextPrayer = "نوێژی داهاتوو: \(computedDisplay)"

        return PrayerEntry(
            date: Date(),
            cityName: city,
            nextPrayer: nextPrayer,
            nextKey: computedKey,
            nextTime: computedTime,
            remaining: computedRemaining,
            fajr: fajr,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha
        )
    }

    private func parseMinutes(_ timeStr: String) -> Int? {
        let parts = timeStr.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
        if parts.count >= 2 {
            let h = Int(parts[0].filter { $0.isNumber })
            let m = Int(String(parts[1].filter { $0.isNumber }.prefix(2)))
            if let h = h, let m = m {
                return h * 60 + m
            }
        }
        return nil
    }
}

// MARK: - Colors & Styling
private extension Color {
    static let widgetBackgroundStart = Color(red: 13/255, green: 21/255, blue: 32/255)
    static let widgetBackgroundEnd = Color(red: 26/255, green: 40/255, blue: 58/255)
    static let widgetCard = Color(red: 22/255, green: 34/255, blue: 48/255)
    static let widgetCardBorder = Color(red: 46/255, green: 66/255, blue: 89/255)
    static let activeCard = Color(red: 38/255, green: 48/255, blue: 64/255)
    static let goldAccent = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let skyAccent = Color(red: 56/255, green: 189/255, blue: 248/255)
    static let textMuted = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let badgeBg = Color(red: 33/255, green: 27/255, blue: 18/255)
    static let badgeBorder = Color(red: 180/255, green: 83/255, blue: 9/255)
}

// MARK: - SwiftUI View for Widgets
struct PrayerWidgetEntryView: View {
    var entry: PrayerTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.widgetBackgroundStart, Color.widgetBackgroundEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            @unknown default:
                mediumWidgetView
            }
        }
    }

    // MARK: Small Widget View
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("📍 \(entry.cityName)")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.skyAccent)
                Spacer()
                Text("✨ بانگ")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.nextPrayer)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.goldAccent)
                    .lineLimit(1)

                Text(entry.nextTime)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.skyAccent)

                Text("⏱️ \(entry.remaining)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(red: 253/255, green: 230/255, blue: 138/255))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.badgeBg)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.badgeBorder, lineWidth: 0.8))
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.widgetCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.widgetCardBorder, lineWidth: 1))
        }
        .padding(12)
    }

    // MARK: Medium Widget View
    private var mediumWidgetView: some View {
        VStack(spacing: 7) {
            // Header Row: City & Title
            HStack {
                Text("📍 \(entry.cityName)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.skyAccent)
                Spacer()
                Text("✨ کاتەکانی بانگ")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
            }

            // Highlight Next Prayer Box
            HStack {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(entry.nextPrayer)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.goldAccent)
                    
                    Text("⏱️ \(entry.remaining)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 253/255, green: 230/255, blue: 138/255))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.badgeBg)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.badgeBorder, lineWidth: 0.8))
                }
                Spacer()
                Text(entry.nextTime)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.skyAccent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.widgetCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.widgetCardBorder, lineWidth: 1))

            // 5 Prayers Bottom Bar
            HStack(spacing: 4) {
                prayerColumn(title: "🌅 بەیانی", time: entry.fajr, isNext: entry.nextKey == "Fajr")
                prayerColumn(title: "🌤️ نیوەڕۆ", time: entry.dhuhr, isNext: entry.nextKey == "Dhuhr")
                prayerColumn(title: "🌥️ عەسر", time: entry.asr, isNext: entry.nextKey == "Asr")
                prayerColumn(title: "🌆 مەغریب", time: entry.maghrib, isNext: entry.nextKey == "Maghrib")
                prayerColumn(title: "🌙 عیشا", time: entry.isha, isNext: entry.nextKey == "Isha")
            }
        }
        .padding(10)
    }

    // MARK: Large Widget View
    private var largeWidgetView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("📍 \(entry.cityName)")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.skyAccent)
                Spacer()
                Text("✨ کاتەکانی بانگی ئیسلامی")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
            }

            // Big Highlight Card
            VStack(spacing: 6) {
                Text(entry.nextPrayer)
                    .font(.headline)
                    .bold()
                    .foregroundColor(.goldAccent)

                Text(entry.nextTime)
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(.skyAccent)

                Text("⏱️ \(entry.remaining)")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 253/255, green: 230/255, blue: 138/255))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.badgeBg)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.badgeBorder, lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.widgetCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.widgetCardBorder, lineWidth: 1))

            // Detailed 5 Prayers Grid
            VStack(spacing: 6) {
                prayerRow(title: "بانگی بەیانی (Fajr)", time: entry.fajr, icon: "🌅", isNext: entry.nextKey == "Fajr")
                prayerRow(title: "بانگی نیوەڕۆ (Dhuhr)", time: entry.dhuhr, icon: "🌤️", isNext: entry.nextKey == "Dhuhr")
                prayerRow(title: "بانگی عەسر (Asr)", time: entry.asr, icon: "🌥️", isNext: entry.nextKey == "Asr")
                prayerRow(title: "بانگی مەغریب (Maghrib)", time: entry.maghrib, icon: "🌆", isNext: entry.nextKey == "Maghrib")
                prayerRow(title: "بانگی عیشا (Isha)", time: entry.isha, icon: "🌙", isNext: entry.nextKey == "Isha")
            }
            .padding(8)
            .background(Color.widgetCard.opacity(0.7))
            .cornerRadius(12)
        }
        .padding(14)
    }

    private func prayerColumn(title: String, time: String, isNext: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(isNext ? .goldAccent : .textMuted)
                .lineLimit(1)
            Text(time)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isNext ? .white : Color(red: 203/255, green: 213/255, blue: 225/255))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(isNext ? Color.activeCard : Color.widgetCard.opacity(0.4))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isNext ? Color.goldAccent : Color.widgetCardBorder.opacity(0.5), lineWidth: isNext ? 1.2 : 0.6)
        )
    }

    private func prayerRow(title: String, time: String, icon: String, isNext: Bool) -> some View {
        HStack {
            Text(icon)
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 13, weight: isNext ? .bold : .medium))
                .foregroundColor(isNext ? .goldAccent : .white)
            Spacer()
            Text(time)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isNext ? .goldAccent : .skyAccent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isNext ? Color.activeCard : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Widget Definition
struct PrayerWidget: Widget {
    let kind: String = "PrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("کاتەکانی نوێژ")
        .description("پیشاندانی کاتەکانی نوێژ و کاتی ماوە بۆ بانگ لەسەر شاشەی سەرەکی")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
