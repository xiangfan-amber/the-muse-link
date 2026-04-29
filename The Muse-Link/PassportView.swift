//
//  PassportView.swift
//  The Muse-Link
//

import SwiftUI

struct PassportView: View {
    @EnvironmentObject var passport: PassportStore
    @State private var tab: PassportTab = .visits

    enum PassportTab: String, CaseIterable {
        case visits = "Visits"
        case favorites = "Favorites"
        case preferences = "Preferences"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                segmented
                ScrollView {
                    Group {
                        switch tab {
                        case .visits:      visitsList
                        case .favorites:   favoritesList
                        case .preferences: preferencesEditor
                        }
                    }
                    .padding(.horizontal, MuseTheme.padL)
                    .padding(.top, 12)
                }
            }
            .parchment()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("THE ART PASSPORT")
                        .font(MuseTheme.label(12)).tracking(2.5)
                        .foregroundColor(MuseTheme.inkSoft)
                }
            }
        }
        .tint(MuseTheme.oxblood)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Art Passport")
                    .font(MuseTheme.display(28))
                    .foregroundColor(MuseTheme.ink)
                Text("A simulated reusable memory — a record that travels with you, connecting today's visit to the museums you'll walk into next.")
                    .font(MuseTheme.bodySerif(14))
                    .foregroundColor(MuseTheme.inkSoft)
                    .lineSpacing(2)
            }
            VisitorIdentityCard()
            StampRow(stamps: PassportStamps.compute(passport.passport))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MuseTheme.padL)
        .padding(.top, 8)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            ForEach(PassportTab.allCases, id: \.self) { t in
                Button { withAnimation { tab = t } } label: {
                    VStack(spacing: 6) {
                        Text(t.rawValue)
                            .font(MuseTheme.label(13)).tracking(1.2)
                            .foregroundColor(tab == t ? MuseTheme.ink : MuseTheme.inkSoft)
                        Rectangle()
                            .fill(tab == t ? MuseTheme.oxblood : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            VStack { Spacer(); HairlineRule() }
        )
    }

    // MARK: - Tabs

    private var visitsList: some View {
        VStack(spacing: 10) {
            if passport.passport.visits.isEmpty {
                EmptyStateView(title: "No visits yet",
                               detail: "Start a visit from Home — I'll log it here automatically.")
            } else {
                ForEach(passport.passport.visits) { v in
                    visitRow(v)
                }
            }
        }
    }

    private func visitRow(_ v: MuseumVisit) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Image(systemName: "building.columns")
                    .font(.system(size: 18))
                    .foregroundColor(MuseTheme.oxblood)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.6))
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(v.museum)
                    .font(MuseTheme.title(17))
                    .foregroundColor(MuseTheme.ink)
                Text(v.dateLabel)
                    .font(MuseTheme.body(13))
                    .foregroundColor(MuseTheme.inkSoft)
                HStack(spacing: 10) {
                    if let mins = v.durationMinutes {
                        Label("\(mins) min", systemImage: "clock")
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.inkSoft)
                    }
                    if !v.savedArtworkIDs.isEmpty {
                        Label("\(v.savedArtworkIDs.count) saved", systemImage: "bookmark")
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.inkSoft)
                    }
                    if v.fatigueChecks > 0 {
                        Label("\(v.fatigueChecks) check-ins", systemImage: "figure.seated.side")
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.inkSoft)
                    }
                }
                .padding(.top, 4)
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    passport.deleteVisit(v.id)
                } label: { Label("Delete visit", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .padding(8)
                    .foregroundColor(MuseTheme.inkSoft)
            }
        }
        .wallLabel()
    }

    private var favoritesList: some View {
        VStack(spacing: 10) {
            if passport.passport.favorites.isEmpty {
                EmptyStateView(title: "No saved artworks yet",
                               detail: "When the curator points to a piece, tap \"Save\" to add it here with a note.")
            } else {
                ForEach(passport.passport.favorites) { art in
                    NavigationLink {
                        ArtworkDetailView(artwork: art)
                    } label: {
                        favoriteRow(art)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func favoriteRow(_ a: Artwork) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(a.title)
                .font(MuseTheme.title(17))
                .foregroundColor(MuseTheme.ink)
            Text(a.artist + (a.year.map { " · \($0)" } ?? ""))
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)
            if let m = a.museum, !m.isEmpty {
                Text(m)
                    .font(MuseTheme.body(12))
                    .foregroundColor(MuseTheme.inkSoft.opacity(0.8))
            }
            if !a.note.isEmpty {
                Text("“\(a.note)”")
                    .font(MuseTheme.bodySerif(14))
                    .italic()
                    .foregroundColor(MuseTheme.inkSoft)
                    .padding(.top, 4)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wallLabel()
    }

    private var preferencesEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            preferenceGroup("Movements", kind: .movement, names: ArtPreference.movements)
            preferenceGroup("Mediums", kind: .medium, names: ArtPreference.mediums)
            preferenceGroup("Themes", kind: .theme, names: ArtPreference.themes)
            Spacer(minLength: 30)
        }
    }

    private func preferenceGroup(_ title: String, kind: ArtPreference.Kind, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(MuseTheme.label())
                .tracking(1.2)
                .foregroundColor(MuseTheme.inkSoft)
            FlowLayout(spacing: 8) {
                ForEach(names, id: \.self) { n in
                    let pref = ArtPreference(kind: kind, name: n)
                    let selected = passport.passport.preferences.contains(pref)
                    Button { passport.togglePreference(pref) } label: {
                        Text(n).chip(selected: selected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Artwork detail

struct ArtworkDetailView: View {
    @EnvironmentObject var passport: PassportStore
    let artwork: Artwork
    @State private var note: String = ""
    @FocusState private var noteFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FROM YOUR PASSPORT")
                        .font(MuseTheme.label()).tracking(1.2)
                        .foregroundColor(MuseTheme.inkSoft)
                    Text(artwork.title)
                        .font(MuseTheme.display(28))
                        .foregroundColor(MuseTheme.ink)
                    Text(artwork.artist + (artwork.year.map { " · \($0)" } ?? ""))
                        .font(MuseTheme.bodySerif(17))
                        .foregroundColor(MuseTheme.inkSoft)
                    if let m = artwork.museum, !m.isEmpty {
                        Text("Seen at \(m)")
                            .font(MuseTheme.body(13))
                            .foregroundColor(MuseTheme.inkSoft)
                    }
                    HairlineRule().padding(.top, 6)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR NOTE")
                        .font(MuseTheme.label()).tracking(1.2)
                        .foregroundColor(MuseTheme.inkSoft)
                    TextEditor(text: $note)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 160)
                        .background(Color.white.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: MuseTheme.corner)
                                .stroke(MuseTheme.hairline, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))
                        .focused($noteFocused)
                    HStack {
                        Spacer()
                        Button("Save note") {
                            passport.updateNote(for: artwork.id, note: note)
                            noteFocused = false
                        }
                        .buttonStyle(GhostButtonStyle())
                        .frame(maxWidth: 160)
                    }
                }

                Button(role: .destructive) {
                    passport.deleteFavorite(artwork.id)
                } label: {
                    HStack { Image(systemName: "trash"); Text("Remove from passport") }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .foregroundColor(MuseTheme.oxblood)
                .padding(.top, 8)
            }
            .padding(.horizontal, MuseTheme.padL)
            .padding(.top, 8)
        }
        .parchment()
        .navigationTitle("Artwork")
        .inlineNavigationTitle()
        .onAppear { note = artwork.note }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MuseTheme.title(18))
                .foregroundColor(MuseTheme.ink)
            Text(detail)
                .font(MuseTheme.bodySerif(14))
                .foregroundColor(MuseTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wallLabel()
    }
}
