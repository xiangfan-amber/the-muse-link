//
//  Models.swift
//  The Muse-Link
//
//  Domain models for the Art Passport, visits, artworks, chat, and route plans.
//

import Foundation

// MARK: - Art preferences

/// A preference tag the user picks during onboarding (movements, mediums, themes).
struct ArtPreference: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case movement, medium, theme
        var label: String {
            switch self {
            case .movement: return "Movement"
            case .medium:   return "Medium"
            case .theme:    return "Theme"
            }
        }
    }
    var id: String { "\(kind.rawValue):\(name)" }
    var kind: Kind
    var name: String
}

extension ArtPreference {
    static let movements: [String] = [
        "Renaissance", "Baroque", "Impressionism", "Post-Impressionism",
        "Cubism", "Surrealism", "Abstract Expressionism", "Pop Art",
        "Minimalism", "Contemporary"
    ]
    static let mediums: [String] = [
        "Painting", "Sculpture", "Photography", "Drawing",
        "Installation", "Video", "Textile", "Ceramics", "Print"
    ]
    static let themes: [String] = [
        "Portraiture", "Landscape", "Abstraction", "Identity",
        "Power & politics", "Mythology", "Everyday life",
        "Feminist art", "Nature & ecology"
    ]
}

// MARK: - Artwork

struct Artwork: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var artist: String
    var year: String?
    var museum: String?
    var note: String = ""
    var savedAt: Date = Date()
}

// MARK: - Visit parameters (muse-companion-style)

enum EnergyLevel: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum VisitMode: String, Codable, CaseIterable, Identifiable {
    case quick, deep
    var id: String { rawValue }
    var label: String {
        switch self {
        case .quick: return "Quick Visit"
        case .deep:  return "Deep Dive"
        }
    }
    var stops: Int { self == .quick ? 2 : 3 }
    var subtitle: String {
        switch self {
        case .quick: return "Two stops, lighter notes — for a focused pass through the gallery."
        case .deep:  return "Three stops, full curator context — slower and more reflective."
        }
    }
}

struct VisitParameters: Codable, Hashable {
    var minutes: Int = 60         // 30, 60, 120
    var energy: EnergyLevel = .medium
    var mode: VisitMode = .deep
    var interests: [String] = []  // e.g. ["Modern Art", "Sculpture"]

    var timeLabel: String {
        switch minutes {
        case ..<60: return "30 min"
        case 60: return "1 hour"
        default: return "\(minutes / 60) hours"
        }
    }
}

// MARK: - Museum visit

struct MuseumVisit: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var museum: String
    var startedAt: Date
    var endedAt: Date?
    var savedArtworkIDs: [UUID] = []
    var fatigueChecks: Int = 0
    var parameters: VisitParameters?
    var routePlan: RoutePlan?
    var completedStopIDs: [UUID] = []

    var dateLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: startedAt)
    }

    var durationMinutes: Int? {
        guard let endedAt else { return nil }
        return Int(endedAt.timeIntervalSince(startedAt) / 60)
    }
}

// MARK: - Chat

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case user, assistant, system }
    var id: UUID = UUID()
    var role: Role
    var text: String
    var citations: [Citation] = []
    var artworkSuggestion: ArtworkSuggestion?
    var createdAt: Date = Date()
}

struct Citation: Codable, Hashable {
    var title: String
    var url: String
}

/// Lightweight artwork the assistant offered as a possible "save to passport".
struct ArtworkSuggestion: Codable, Hashable {
    var title: String
    var artist: String
    var year: String?
}

// MARK: - Route

struct RouteStop: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var order: Int
    var title: String        // artwork title, gallery, or rest-stop name
    var detail: String       // why this stop, what to look for (1–2 sentences)
    var minutes: Int
    var isBreak: Bool = false
    // Muse-companion style enrichment
    var artist: String?
    var year: String?
    var room: String?
    var observation: String?     // "look first" — what to notice with your eyes
    var curatorNote: String?     // the deeper note revealed under "View insight"
}

struct RoutePlan: Codable, Hashable {
    var museum: String
    var generatedAt: Date = Date()
    var stops: [RouteStop]
    var notes: String = ""
    var narrative: String = ""      // italic intro paragraph at the top
    var passportThread: String = "" // "From your Art Passport: ..." callout
}

// MARK: - The Art Passport (root document)

struct ArtPassport: Codable {
    var userName: String = ""
    var preferences: [ArtPreference] = []
    var visits: [MuseumVisit] = []
    var favorites: [Artwork] = []

    var preferenceSummary: String {
        guard !preferences.isEmpty else { return "no stated preferences yet" }
        return preferences.map(\.name).joined(separator: ", ")
    }
}
