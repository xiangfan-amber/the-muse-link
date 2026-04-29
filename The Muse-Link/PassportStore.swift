//
//  PassportStore.swift
//  The Muse-Link
//
//  Persists the user's Art Passport (preferences, visits, favorite artworks)
//  as JSON in the app's Application Support directory.
//

import Foundation
import Combine

@MainActor
final class PassportStore: ObservableObject {
    @Published var passport: ArtPassport
    @Published private(set) var activeVisitID: UUID?

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory,
                               in: .userDomainMask,
                               appropriateFor: nil,
                               create: true))
            ?? fm.temporaryDirectory
        self.fileURL = dir.appendingPathComponent("muselink_passport.json")

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(ArtPassport.self, from: data) {
            self.passport = loaded
        } else {
            self.passport = ArtPassport()
        }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(passport)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("PassportStore save failed: \(error)")
            #endif
        }
    }

    // MARK: - Mutations

    func setUserName(_ name: String) {
        passport.userName = name
        save()
    }

    func togglePreference(_ pref: ArtPreference) {
        if let idx = passport.preferences.firstIndex(of: pref) {
            passport.preferences.remove(at: idx)
        } else {
            passport.preferences.append(pref)
        }
        save()
    }

    func startVisit(museum: String, parameters: VisitParameters? = nil) -> MuseumVisit {
        let visit = MuseumVisit(museum: museum,
                                startedAt: Date(),
                                parameters: parameters)
        passport.visits.insert(visit, at: 0)
        activeVisitID = visit.id
        save()
        return visit
    }

    func updateActiveVisitParameters(_ parameters: VisitParameters) {
        guard let id = activeVisitID,
              let idx = passport.visits.firstIndex(where: { $0.id == id }) else { return }
        passport.visits[idx].parameters = parameters
        save()
    }

    /// Attach a generated route plan to the active visit. Resets any prior
    /// completion checkmarks since the plan itself just changed.
    func attachRoute(_ plan: RoutePlan) {
        guard let id = activeVisitID,
              let idx = passport.visits.firstIndex(where: { $0.id == id }) else { return }
        passport.visits[idx].routePlan = plan
        passport.visits[idx].completedStopIDs = []
        save()
    }

    /// Flip a stop's checkmark on the active visit.
    func toggleStopCompletion(_ stopID: UUID) {
        guard let id = activeVisitID,
              let idx = passport.visits.firstIndex(where: { $0.id == id }) else { return }
        if let pos = passport.visits[idx].completedStopIDs.firstIndex(of: stopID) {
            passport.visits[idx].completedStopIDs.remove(at: pos)
        } else {
            passport.visits[idx].completedStopIDs.append(stopID)
        }
        save()
    }

    func isStopCompleted(_ stopID: UUID) -> Bool {
        guard let v = activeVisit else { return false }
        return v.completedStopIDs.contains(stopID)
    }

    func endActiveVisit() {
        guard let id = activeVisitID,
              let idx = passport.visits.firstIndex(where: { $0.id == id }) else {
            return
        }
        passport.visits[idx].endedAt = Date()
        activeVisitID = nil
        save()
    }

    func recordFatigueCheck() {
        guard let id = activeVisitID,
              let idx = passport.visits.firstIndex(where: { $0.id == id }) else { return }
        passport.visits[idx].fatigueChecks += 1
        save()
    }

    @discardableResult
    func saveArtwork(_ artwork: Artwork) -> Artwork {
        var saved = artwork
        if saved.museum == nil, let visit = activeVisit {
            saved.museum = visit.museum
        }
        passport.favorites.insert(saved, at: 0)
        if let id = activeVisitID,
           let idx = passport.visits.firstIndex(where: { $0.id == id }) {
            passport.visits[idx].savedArtworkIDs.append(saved.id)
        }
        save()
        return saved
    }

    func updateNote(for artworkID: UUID, note: String) {
        guard let idx = passport.favorites.firstIndex(where: { $0.id == artworkID }) else { return }
        passport.favorites[idx].note = note
        save()
    }

    func deleteFavorite(_ artworkID: UUID) {
        passport.favorites.removeAll { $0.id == artworkID }
        save()
    }

    func deleteVisit(_ visitID: UUID) {
        passport.visits.removeAll { $0.id == visitID }
        if activeVisitID == visitID { activeVisitID = nil }
        save()
    }

    // MARK: - Convenience

    var activeVisit: MuseumVisit? {
        guard let id = activeVisitID else { return nil }
        return passport.visits.first { $0.id == id }
    }

    var lastMuseum: String? {
        passport.visits.first?.museum
    }
}
