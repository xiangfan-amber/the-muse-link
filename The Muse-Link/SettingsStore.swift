//
//  SettingsStore.swift
//  The Muse-Link
//
//  Stores app settings: API key (Keychain), onboarding flag, and preferred model.
//

import Foundation
import Combine
import Security
import CoreGraphics

@MainActor
final class SettingsStore: ObservableObject {
    @Published var apiKey: String {
        didSet { Keychain.set(apiKey, for: Self.apiKeyKey) }
    }
    @Published var onboardingComplete: Bool {
        didSet { UserDefaults.standard.set(onboardingComplete, forKey: Self.onboardingKey) }
    }
    @Published var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: Self.modelKey) }
    }
    @Published var curatorMode: CuratorMode {
        didSet { UserDefaults.standard.set(curatorMode.rawValue, forKey: Self.modeKey) }
    }
    @Published var audioGuideEnabled: Bool {
        didSet { UserDefaults.standard.set(audioGuideEnabled, forKey: Self.audioKey) }
    }

    private static let apiKeyKey = "muselink.anthropic.apiKey"
    private static let onboardingKey = "muselink.onboardingComplete"
    private static let modelKey = "muselink.modelName"
    private static let modeKey = "muselink.curatorMode"
    private static let audioKey = "muselink.audioGuideEnabled"

    init() {
        self.apiKey = Keychain.get(for: Self.apiKeyKey) ?? ""
        self.onboardingComplete = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        self.modelName = UserDefaults.standard.string(forKey: Self.modelKey)
            ?? "claude-sonnet-4-6"
        let modeRaw = UserDefaults.standard.string(forKey: Self.modeKey) ?? CuratorMode.standard.rawValue
        self.curatorMode = CuratorMode(rawValue: modeRaw) ?? .standard
        if UserDefaults.standard.object(forKey: Self.audioKey) == nil {
            self.audioGuideEnabled = true
        } else {
            self.audioGuideEnabled = UserDefaults.standard.bool(forKey: Self.audioKey)
        }
    }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    func resetOnboarding() {
        onboardingComplete = false
    }
}

// MARK: - Curator companion modes

enum CuratorMode: String, Codable, CaseIterable, Identifiable {
    case standard
    case kid
    case accessible
    case scholar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:    return "Standard"
        case .kid:         return "Kid-friendly"
        case .accessible:  return "Slow & spacious"
        case .scholar:     return "Scholar"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:    return "Warm, Socratic, two or three sentences."
        case .kid:         return "Playful and curious. Simple words. Lots of questions a child can answer."
        case .accessible:  return "Slow pace, larger text, fewer stops, more rest."
        case .scholar:     return "Deeper context, references, comparative readings."
        }
    }

    /// Extra system-prompt lines injected just before the curator instructions.
    var systemAddendum: String {
        switch self {
        case .standard:
            return ""
        case .kid:
            return """
            COMPANION MODE: KID-FRIENDLY
            - The visitor may be a child or a family. Use simple, vivid words.
            - Ask one playful question at a time ("What do you think this person is feeling?").
            - Avoid art-history jargon unless you immediately translate it.
            """
        case .accessible:
            return """
            COMPANION MODE: SLOW & SPACIOUS
            - Speak in shorter sentences. One idea per sentence.
            - Suggest a bench or sitting break every 2–3 stops in routes.
            - Never overload with names or dates.
            """
        case .scholar:
            return """
            COMPANION MODE: SCHOLAR
            - The visitor enjoys art-historical depth. You may reference movements, contemporaries, and provenance.
            - When possible, cite the wall label or scholarship via web search.
            - Still keep replies under three short paragraphs and end with a question.
            """
        }
    }

    /// Body-text scale used in chat bubbles for accessibility.
    var bodyScale: CGFloat {
        switch self {
        case .accessible: return 1.18
        default:          return 1.0
        }
    }
}

// MARK: - Tiny Keychain wrapper

enum Keychain {
    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func get(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
