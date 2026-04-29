//
//  AnthropicChatService.swift
//  The Muse-Link
//
//  Calls the Anthropic Messages API with the web_search_20250305 server tool
//  enabled, using a curator system prompt that enforces short Socratic prompts,
//  references the user's Art Passport, and watches for fatigue.
//

import Foundation

// MARK: - Errors

enum CuratorError: LocalizedError {
    case missingAPIKey
    case rateLimited(retryAfter: Int)
    case http(Int, String)
    case decoding(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:    return "Add an Anthropic API key in Settings to use the curator."
        case .rateLimited(let s): return "You've hit Anthropic's rate limit. Try again in \(s) seconds."
        case .http(let s, let m): return "Curator service error (\(s)): \(m)"
        case .decoding(let m):  return "Couldn't read curator's reply: \(m)"
        case .empty:            return "The curator didn't reply. Try again?"
        }
    }
}

// MARK: - Public service

protocol ChatService {
    func respond(history: [ChatMessage],
                 passport: ArtPassport,
                 currentMuseum: String?) async throws -> ChatMessage

    func planRoute(museum: String,
                   passport: ArtPassport,
                   parameters: VisitParameters) async throws -> RoutePlan
}

@MainActor
final class AnthropicChatService: ChatService {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    // MARK: - System prompts

    private func curatorSystemPrompt(passport: ArtPassport, currentMuseum: String?) -> String {
        let visits = passport.visits.prefix(6).map { "- \($0.museum) (\($0.dateLabel))" }.joined(separator: "\n")
        let prefs  = passport.preferences.map { "\($0.kind.label): \($0.name)" }.joined(separator: ", ")
        let favs   = passport.favorites.prefix(8).map { "- \($0.title) by \($0.artist)" }.joined(separator: "\n")

        let modeAddendum = settings.curatorMode.systemAddendum
        let modeBlock = modeAddendum.isEmpty ? "" : "\n\n\(modeAddendum)\n"

        return """
        You are The Muse-Link, a calm, knowledgeable museum curator who guides one visitor at a time, in person.\(modeBlock)
        VOICE
        - Speak warmly but in short paragraphs. Two or three sentences per turn, max.
        - Prefer one clear Socratic question over a lecture. Never assign more than one question at a time.
        - Use plain language. Drop a name or date only when it earns its place.
        - Avoid lists, bullets, and headers. Speak like someone standing next to the visitor.

        WHAT YOU KNOW ABOUT THIS VISITOR (their Art Passport)
        Name: \(passport.userName.isEmpty ? "(not given)" : passport.userName)
        Stated preferences: \(prefs.isEmpty ? "none yet" : prefs)
        Recent visits:
        \(visits.isEmpty ? "(none yet)" : visits)
        Saved favorites:
        \(favs.isEmpty ? "(none yet)" : favs)
        Current museum: \(currentMuseum ?? "(not set)")

        WHAT TO DO
        - Tie suggestions to their Art Passport when natural ("you saved a Rothko last month — there's a related Kline in Gallery 9").
        - Use the web_search tool when freshness matters: current exhibitions, gallery closures, today's hours, special events, and ticketed shows. Don't invent these.
        - If the visitor sounds tired ("my feet hurt", "overwhelmed", "too much"), offer a break or a route change before continuing.
        - Never claim certainty about a work's location or hours without searching.

        ARTWORK SUGGESTIONS
        - When you point to a specific artwork the visitor should consider seeing or saving, append on a NEW LAST LINE exactly:
          <<ARTWORK>>{"title":"...","artist":"...","year":"..."}<<END>>
        - Only emit one such line per reply, and only when you actually named an artwork. Omit the year field if unknown.
        - This line will be hidden from the visitor and rendered as a "Save to Passport" button.
        """
    }

    private func routeSystemPrompt(passport: ArtPassport,
                                   museum: String,
                                   parameters: VisitParameters) -> String {
        let prefs = (parameters.interests + passport.preferences.map(\.name))
            .filter { !$0.isEmpty }
            .uniqued()
            .joined(separator: ", ")
        let pastMuseums = Set(passport.visits.map(\.museum)).filter { $0 != museum }
        let memory = pastMuseums.isEmpty
            ? "this is one of the visitor's first museum trips."
            : "previously visited: \(pastMuseums.prefix(5).joined(separator: ", "))."

        let breakRule: String
        switch parameters.energy {
        case .low:    breakRule = "include at least one explicit rest stop (isBreak: true)"
        case .medium: breakRule = "include a rest stop only if total walking is heavy"
        case .high:   breakRule = "no rest stops needed"
        }

        return """
        You plan museum routes for ONE visitor. Reply ONLY with a single JSON object — no prose, no markdown fences.

        Museum: \(museum)
        Time budget: \(parameters.minutes) minutes
        Energy: \(parameters.energy.label) — \(breakRule)
        Mode: \(parameters.mode.label) — produce EXACTLY \(parameters.mode.stops) artwork stops (plus optional rest stops on top of that)
        Visitor interests: \(prefs.isEmpty ? "general interest" : prefs)
        Memory thread: \(memory)

        Use the web_search tool to confirm CURRENT exhibitions, gallery rooms, and any closures at \(museum) today. Don't invent rooms or works.

        Compose a NARRATIVE route, not a list. Each stop sets up the next; read in order, the works speak to one another.

        JSON shape:
        {
          "museum": "string",
          "narrative": "1-2 sentence italic intro framing the visit (e.g. 'A 2-hour narrative shaped around your interest in Modern Art. Each stop sets up the next — read them in order, and the three works begin to speak to one another.')",
          "passportThread": "1 sentence connecting today's route to past visits/preferences (e.g. 'this route picks up the threads of Modern Art you've returned to before, weaving today's visit into the artistic memory you've been building.')",
          "notes": "1 short overall note",
          "stops": [
            {
              "order": 1,
              "title": "Artwork title (or rest-stop name)",
              "artist": "Artist name (omit for rest stops)",
              "year": "1888",
              "room": "Room 43",
              "observation": "1 sentence — what to notice with your eyes BEFORE reading the curator's note. 'Look first.'",
              "curatorNote": "2-3 sentences of context — why this work matters, how it connects to the next stop in the narrative",
              "detail": "Short why-chosen line (e.g. 'Chosen for your interest in Modern Art. It opens your narrative — a starting note to set the tone.')",
              "minutes": 25,
              "isBreak": false
            }
          ]
        }

        Rules:
        - Exactly \(parameters.mode.stops) NON-break stops; their minutes should sum near \(parameters.minutes - (parameters.energy == .low ? 10 : 0)).
        - Stops must be specific artworks at \(museum), not vague galleries, unless an exhibition has a strong throughline.
        - Order stops to minimize walking when possible.
        - For rest stops set isBreak: true with title like "Sculpture courtyard pause" or "Café break"; omit artist/year/room.
        """
    }

    // MARK: - Public

    func respond(history: [ChatMessage],
                 passport: ArtPassport,
                 currentMuseum: String?) async throws -> ChatMessage {
        guard settings.hasAPIKey else { throw CuratorError.missingAPIKey }

        let system = curatorSystemPrompt(passport: passport, currentMuseum: currentMuseum)

        // Anthropic requires the first message to be from the user. Drop any
        // leading assistant/system messages (we use a UI-only intro turn).
        var trimmed = history.filter { $0.role != .system }
        while let first = trimmed.first, first.role != .user {
            trimmed.removeFirst()
        }
        let messages = trimmed.map {
            APIMessage(role: $0.role == .user ? "user" : "assistant",
                       content: [.init(type: "text", text: $0.text)])
        }

        let body = APIRequest(
            model: settings.modelName,
            maxTokens: 700,
            system: system,
            messages: messages,
            tools: [.init(type: "web_search_20250305", name: "web_search", maxUses: 3)]
        )

        let (text, citations) = try await callAPI(body)
        let cleaned = ArtworkSuggestionParser.strip(text)
        let suggestion = ArtworkSuggestionParser.extract(from: text)
        return ChatMessage(role: .assistant,
                           text: cleaned,
                           citations: citations,
                           artworkSuggestion: suggestion)
    }

    func planRoute(museum: String,
                   passport: ArtPassport,
                   parameters: VisitParameters) async throws -> RoutePlan {
        guard settings.hasAPIKey else { throw CuratorError.missingAPIKey }

        let system = routeSystemPrompt(passport: passport, museum: museum, parameters: parameters)
        let userTurn = APIMessage(
            role: "user",
            content: [.init(type: "text",
                            text: "Plan today's route for me. Output JSON only.")]
        )

        let body = APIRequest(
            model: settings.modelName,
            maxTokens: 1600,
            system: system,
            messages: [userTurn],
            tools: [.init(type: "web_search_20250305", name: "web_search", maxUses: 3)]
        )

        let (text, _) = try await callAPI(body)

        let json = JSONExtractor.extractObject(from: text) ?? text
        guard let data = json.data(using: .utf8) else { throw CuratorError.decoding("not utf8") }
        do {
            let parsed = try JSONDecoder().decode(RouteJSON.self, from: data)
            let stops = parsed.stops.map { s in
                RouteStop(order: s.order,
                          title: s.title,
                          detail: s.detail ?? "",
                          minutes: s.minutes,
                          isBreak: s.isBreak ?? false,
                          artist: s.artist,
                          year: s.year,
                          room: s.room,
                          observation: s.observation,
                          curatorNote: s.curatorNote)
            }
            return RoutePlan(museum: parsed.museum,
                             stops: stops.sorted(by: { $0.order < $1.order }),
                             notes: parsed.notes ?? "",
                             narrative: parsed.narrative ?? "",
                             passportThread: parsed.passportThread ?? "")
        } catch {
            throw CuratorError.decoding(error.localizedDescription)
        }
    }

    // MARK: - HTTP

    private func callAPI(_ body: APIRequest) async throws -> (String, [Citation]) {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try enc.encode(body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if http.statusCode == 429 {
                // Prefer the explicit retry-after header; otherwise fall back to
                // anthropic-ratelimit-input-tokens-reset (an ISO-8601 timestamp).
                let retry = parseRetryAfter(headers: http.allHeaderFields)
                throw CuratorError.rateLimited(retryAfter: retry)
            }
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw CuratorError.http(http.statusCode, msg.prefix(300).description)
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        let parsed: APIResponse
        do {
            parsed = try dec.decode(APIResponse.self, from: data)
        } catch {
            throw CuratorError.decoding(error.localizedDescription)
        }

        var text = ""
        var citations: [Citation] = []
        for block in parsed.content {
            guard block.type == "text" else { continue }
            if let t = block.text { text += t }
            if let cs = block.citations {
                for c in cs {
                    if let url = c.url, let title = c.title {
                        citations.append(Citation(title: title, url: url))
                    }
                }
            }
        }

        // Deduplicate citations by URL
        var seen = Set<String>()
        citations = citations.filter { seen.insert($0.url).inserted }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw CuratorError.empty }
        return (trimmed, citations)
    }
}

// MARK: - API DTOs

private struct APIRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [APIMessage]
    let tools: [APITool]
}

private struct APIMessage: Encodable {
    let role: String
    let content: [APIContentBlock]
    struct APIContentBlock: Encodable {
        let type: String
        let text: String
    }
}

private struct APITool: Encodable {
    let type: String
    let name: String
    let maxUses: Int
}

private struct APIResponse: Decodable {
    let content: [Block]
    struct Block: Decodable {
        let type: String
        let text: String?
        let citations: [Cite]?
    }
    struct Cite: Decodable {
        let url: String?
        let title: String?
    }
}

// MARK: - Tool result JSON for routes

private struct RouteJSON: Decodable {
    let museum: String
    let notes: String?
    let narrative: String?
    let passportThread: String?
    let stops: [Stop]
    struct Stop: Decodable {
        let order: Int
        let title: String
        let detail: String?
        let minutes: Int
        let isBreak: Bool?
        let artist: String?
        let year: String?
        let room: String?
        let observation: String?
        let curatorNote: String?
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

/// Parses Anthropic's rate-limit headers and returns a sensible "retry after"
/// value in seconds. Falls back to 60 if no usable header is present.
private func parseRetryAfter(headers: [AnyHashable: Any]) -> Int {
    func value(_ key: String) -> String? {
        for (k, v) in headers {
            if let ks = k as? String, ks.lowercased() == key.lowercased() {
                return v as? String
            }
        }
        return nil
    }

    if let s = value("retry-after"), let n = Int(s.trimmingCharacters(in: .whitespaces)) {
        return max(1, n)
    }

    let resetKeys = [
        "anthropic-ratelimit-input-tokens-reset",
        "anthropic-ratelimit-tokens-reset",
        "anthropic-ratelimit-requests-reset"
    ]
    let isoFormatter = ISO8601DateFormatter()
    for key in resetKeys {
        if let s = value(key), let d = isoFormatter.date(from: s) {
            let secs = Int(d.timeIntervalSinceNow.rounded(.up))
            if secs > 0 { return min(secs, 120) }
        }
    }
    return 60
}

// MARK: - Parsers

enum ArtworkSuggestionParser {
    private static let opener = "<<ARTWORK>>"
    private static let closer = "<<END>>"

    static func extract(from text: String) -> ArtworkSuggestion? {
        guard let start = text.range(of: opener),
              let end   = text.range(of: closer, range: start.upperBound..<text.endIndex) else {
            return nil
        }
        let json = String(text[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = json.data(using: .utf8) else { return nil }
        struct DTO: Decodable { let title: String; let artist: String; let year: String? }
        guard let dto = try? JSONDecoder().decode(DTO.self, from: data) else { return nil }
        return ArtworkSuggestion(title: dto.title, artist: dto.artist, year: dto.year)
    }

    static func strip(_ text: String) -> String {
        guard let start = text.range(of: opener),
              let end   = text.range(of: closer, range: start.upperBound..<text.endIndex) else {
            return text
        }
        var result = text
        result.removeSubrange(start.lowerBound..<end.upperBound)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum JSONExtractor {
    /// Returns the substring from the first `{` to its matching `}` (naive brace counting).
    static func extractObject(from text: String) -> String? {
        guard let first = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        for i in text[first...].indices {
            let c = text[i]
            if c == "{" { depth += 1 }
            else if c == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[first...i])
                }
            }
        }
        return nil
    }
}
