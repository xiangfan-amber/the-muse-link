//
//  DailyArtwork.swift
//  The Muse-Link
//
//  Once-per-day curated artwork prompt rendered as a card on the Home tab.
//  The pick is cached by date in UserDefaults so it stays the same all day.
//

import Foundation
import SwiftUI
import Combine

struct DailyPick: Codable, Equatable {
    var dateKey: String
    var title: String
    var artist: String
    var year: String?
    var observation: String   // 1–2 sentence "look first" observation
    var museum: String?
}

@MainActor
final class DailyArtworkStore: ObservableObject {
    @Published private(set) var pick: DailyPick?
    @Published private(set) var loading = false
    @Published private(set) var error: String?

    private let key = "muselink.dailyPick"
    private let settings: SettingsStore
    private let passport: PassportStore

    init(settings: SettingsStore, passport: PassportStore) {
        self.settings = settings
        self.passport = passport
        if let data = UserDefaults.standard.data(forKey: key),
           let cached = try? JSONDecoder().decode(DailyPick.self, from: data) {
            self.pick = cached
        }
    }

    var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var isStale: Bool {
        guard let pick else { return true }
        return pick.dateKey != todayKey
    }

    func loadIfNeeded() async {
        guard isStale, settings.hasAPIKey, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let p = try await fetch()
            self.pick = p
            if let data = try? JSONEncoder().encode(p) {
                UserDefaults.standard.set(data, forKey: key)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch

    private func fetch() async throws -> DailyPick {
        let prefs = passport.passport.preferences.map(\.name).joined(separator: ", ")
        let prompt = """
        Pick ONE notable artwork (any era, any culture) that resonates with these visitor preferences: \(prefs.isEmpty ? "general interest" : prefs).
        Avoid obvious greatest-hits unless they truly fit. Vary your picks day to day.

        Respond with ONLY a JSON object — no prose, no markdown:
        {
          "title": "...",
          "artist": "...",
          "year": "1888",
          "museum": "...",
          "observation": "1–2 sentence 'look first' observation that guides the eye before any history."
        }
        """
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": settings.modelName,
            "max_tokens": 400,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "DailyArtwork", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }

        struct Resp: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        let parsed = try JSONDecoder().decode(Resp.self, from: data)
        let text = parsed.content.compactMap { $0.text }.joined()
        let json = JSONExtractor.extractObject(from: text) ?? text

        struct DTO: Decodable {
            let title: String; let artist: String
            let year: String?; let museum: String?; let observation: String
        }
        let dto = try JSONDecoder().decode(DTO.self, from: Data(json.utf8))
        return DailyPick(dateKey: todayKey,
                         title: dto.title,
                         artist: dto.artist,
                         year: dto.year,
                         observation: dto.observation,
                         museum: dto.museum)
    }
}

// MARK: - Card view

struct DailyArtworkCard: View {
    @ObservedObject var store: DailyArtworkStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ARTWORK OF THE DAY")
                    .font(MuseTheme.label())
                    .tracking(1.2)
                    .foregroundColor(MuseTheme.inkSoft)
                Spacer()
                Text(todayLabel)
                    .font(MuseTheme.body(12))
                    .foregroundColor(MuseTheme.inkSoft)
            }
            content
        }
        .wallLabel()
        .task { await store.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let pick = store.pick {
            VStack(alignment: .leading, spacing: 8) {
                Text(pick.title)
                    .font(MuseTheme.title(20))
                    .foregroundColor(MuseTheme.ink)
                Text(pick.artist + (pick.year.map { " · \($0)" } ?? "")
                     + (pick.museum.map { " · \($0)" } ?? ""))
                    .font(MuseTheme.body(13))
                    .foregroundColor(MuseTheme.inkSoft)
                Text("\u{201C}\(pick.observation)\u{201D}")
                    .font(MuseTheme.bodySerif(15))
                    .italic()
                    .foregroundColor(MuseTheme.ink)
                    .padding(.top, 4)
                    .lineSpacing(2)
            }
        } else if store.loading {
            HStack(spacing: 8) {
                ProgressView().tint(MuseTheme.oxblood)
                Text("Choosing today's piece…")
                    .font(MuseTheme.body(13))
                    .foregroundColor(MuseTheme.inkSoft)
            }
        } else if let err = store.error {
            Text(err)
                .font(MuseTheme.body(12))
                .foregroundColor(MuseTheme.oxblood)
        } else {
            Text("Add an Anthropic API key in Settings and a daily piece will appear here.")
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)
        }
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: Date()).uppercased()
    }
}
