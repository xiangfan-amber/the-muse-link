//
//  HomeView.swift
//  The Muse-Link
//
//  Plan your visit — a numbered wizard inspired by muse-companion.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var passport: PassportStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var daily: DailyArtworkStore

    // Wizard state
    @State private var museumDraft: String = ""
    @State private var customMuseum: String = ""
    @State private var minutes: Int = 60
    @State private var energy: EnergyLevel = .medium
    @State private var mode: VisitMode = .deep
    @State private var interests: Set<String> = []

    // Navigation
    @State private var pushChat = false
    @State private var pushRoute = false
    @State private var pushedMuseum: String = ""
    @State private var pushedParams: VisitParameters = .init()

    private let presetMuseums: [(name: String, blurb: String)] = [
        ("The Metropolitan Museum of Art", "A sprawling encyclopedic collection covering 5,000 years of culture."),
        ("The Museum of Modern Art", "The defining home of modern and contemporary art — Manhattan."),
        ("Musée d'Orsay", "Housed in a former railway station, holding the world's largest Impressionist trove."),
        ("The Louvre", "The world's most-visited museum, spanning antiquity to the mid-19th century."),
        ("Uffizi Gallery", "A Renaissance treasury — Botticelli, Leonardo, Raphael, Michelangelo."),
        ("The National Gallery", "Seven centuries of Western European painting, from medieval to post-Impressionist."),
        ("Guggenheim Museum", "A landmark spiral by Frank Lloyd Wright holding pioneering modern art."),
        ("The Art Institute of Chicago", "Renowned for its global curation, iconic architecture, and modern wing.")
    ]

    private let interestOptions: [String] = [
        "Impressionism", "Portraiture", "Ancient Art", "Sculpture", "Modern Art",
        "Renaissance", "Landscapes", "Asian Art", "Photography", "Contemporary"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    DailyArtworkCard(store: daily)
                    section1MuseumPicker
                    section2Time
                    section3Energy
                    section4Mode
                    section5Interests
                    summaryCard

                    if !passport.passport.visits.isEmpty {
                        recentVisitsSection
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, MuseTheme.padL)
                .padding(.top, 4)
            }
            .parchment()
            .navigationDestination(isPresented: $pushChat) {
                CuratorChatView(museum: pushedMuseum)
            }
            .navigationDestination(isPresented: $pushRoute) {
                RouteView(museum: pushedMuseum, parameters: pushedParams)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("THE MUSE-LINK")
                        .font(MuseTheme.label(12)).tracking(2.5)
                        .foregroundColor(MuseTheme.inkSoft)
                }
            }
            .onAppear { seedFromPassport() }
        }
        .tint(MuseTheme.oxblood)
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(passport.passport.userName.isEmpty
                 ? "Plan your visit"
                 : "Hello, \(passport.passport.userName).")
                .font(MuseTheme.display(34))
                .foregroundColor(MuseTheme.ink)
            Text("Tell me where you are and what moves you. I'll curate a focused, narrative route for your time here.")
                .font(MuseTheme.bodySerif(16))
                .foregroundColor(MuseTheme.inkSoft)
                .lineSpacing(2)
        }
        .padding(.top, 6)
    }

    // MARK: - 1. Museum picker

    private var section1MuseumPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            numberedTitle(1, "Choose a museum")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(presetMuseums, id: \.name) { item in
                    let selected = museumDraft == item.name
                    Button {
                        museumDraft = item.name
                        customMuseum = ""
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(MuseTheme.title(15))
                                .foregroundColor(MuseTheme.ink)
                                .multilineTextAlignment(.leading)
                            Text(item.blurb)
                                .font(MuseTheme.body(12))
                                .foregroundColor(MuseTheme.inkSoft)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(selected ? MuseTheme.oxblood.opacity(0.08) : Color.white.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? MuseTheme.oxblood : MuseTheme.hairline,
                                        lineWidth: selected ? 1.5 : 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("OR")
                    .font(MuseTheme.label(11))
                    .tracking(1.5)
                    .foregroundColor(MuseTheme.inkSoft)
                HairlineRule()
            }
            .padding(.top, 6)

            HStack {
                Image(systemName: "building.columns").foregroundColor(MuseTheme.inkSoft)
                TextField("Type any museum…", text: $customMuseum)
                    .autocapitalizeWords()
                    .onChange(of: customMuseum) { _, new in
                        if !new.trimmingCharacters(in: .whitespaces).isEmpty {
                            museumDraft = new
                        }
                    }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: MuseTheme.corner)
                    .stroke(MuseTheme.hairline, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))
        }
    }

    // MARK: - 2. Time

    private var section2Time: some View {
        VStack(alignment: .leading, spacing: 10) {
            numberedTitle(2, "Time available")
            HStack(spacing: 10) {
                radioButton(label: "30 min", selected: minutes == 30) { minutes = 30 }
                radioButton(label: "1 hour", selected: minutes == 60) { minutes = 60 }
                radioButton(label: "2 hours", selected: minutes == 120) { minutes = 120 }
                Spacer()
            }
        }
    }

    // MARK: - 3. Energy

    private var section3Energy: some View {
        VStack(alignment: .leading, spacing: 10) {
            numberedTitle(3, "Energy level")
            HStack(spacing: 10) {
                ForEach(EnergyLevel.allCases) { e in
                    radioButton(label: e.label, selected: energy == e) { energy = e }
                }
                Spacer()
            }
        }
    }

    // MARK: - 4. Mode

    private var section4Mode: some View {
        VStack(alignment: .leading, spacing: 10) {
            numberedTitle(4, "How do you want to visit?")
            HStack(spacing: 10) {
                ForEach(VisitMode.allCases) { m in
                    Button {
                        mode = m
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(m.label)
                                    .font(MuseTheme.title(16))
                                    .foregroundColor(MuseTheme.ink)
                                Spacer()
                                Text("\(m.stops) stops")
                                    .font(MuseTheme.body(12))
                                    .foregroundColor(MuseTheme.inkSoft)
                            }
                            Text(m.subtitle)
                                .font(MuseTheme.body(13))
                                .foregroundColor(MuseTheme.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(mode == m ? MuseTheme.oxblood.opacity(0.08) : Color.white.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(mode == m ? MuseTheme.oxblood : MuseTheme.hairline,
                                        lineWidth: mode == m ? 1.5 : 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 5. Interests

    private var section5Interests: some View {
        VStack(alignment: .leading, spacing: 10) {
            numberedTitle(5, "What do you want to see?")
            Text("Select at least one interest to help shape your route.")
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)
            FlowLayout(spacing: 8) {
                ForEach(interestOptions, id: \.self) { i in
                    let selected = interests.contains(i)
                    Button {
                        if selected { interests.remove(i) } else { interests.insert(i) }
                    } label: {
                        Text(i).chip(selected: selected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ready to explore")
                .font(MuseTheme.display(22))
                .foregroundColor(MuseTheme.ink)
            Text("Your choices will generate a custom \(mode == .quick ? "two" : "three")-stop narrative.")
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)

            HairlineRule().padding(.vertical, 4)

            summaryRow("Museum:",   museumDraft.isEmpty ? "—" : museumDraft)
            summaryRow("Mode:",     "\(mode.label) · \(mode.stops) stops")
            summaryRow("Time:",     timeLabel)
            summaryRow("Energy:",   energy.label)
            summaryRow("Interests:", interests.isEmpty ? "—" : "\(interests.count) selected")

            HStack(spacing: 10) {
                Button {
                    startCurator()
                } label: {
                    HStack { Image(systemName: "bubble.left.and.bubble.right"); Text("Chat first") }
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(museumDraft.isEmpty)
                .opacity(museumDraft.isEmpty ? 0.5 : 1)

                Button {
                    generateRoute()
                } label: {
                    HStack { Image(systemName: "wand.and.stars"); Text("Generate my route") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(museumDraft.isEmpty || interests.isEmpty)
                .opacity((museumDraft.isEmpty || interests.isEmpty) ? 0.5 : 1)
            }
            .padding(.top, 6)
        }
        .wallLabel()
    }

    private func summaryRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(MuseTheme.title(14))
                .foregroundColor(MuseTheme.ink)
            Spacer()
        }
    }

    // MARK: - Recent visits

    private var recentVisitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR RECENT VISITS")
                .font(MuseTheme.label())
                .tracking(1.2)
                .foregroundColor(MuseTheme.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(passport.passport.visits.prefix(8)) { v in
                        Button {
                            museumDraft = v.museum
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(v.museum)
                                    .font(MuseTheme.title(15))
                                    .foregroundColor(MuseTheme.ink)
                                    .lineLimit(2)
                                Text(v.dateLabel)
                                    .font(MuseTheme.body(12))
                                    .foregroundColor(MuseTheme.inkSoft)
                            }
                            .padding(12)
                            .frame(width: 180, alignment: .leading)
                            .background(Color.white.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(MuseTheme.hairline, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func numberedTitle(_ n: Int, _ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(n).")
                .font(MuseTheme.display(22))
                .foregroundColor(MuseTheme.ink)
            Text(title)
                .font(MuseTheme.display(22))
                .foregroundColor(MuseTheme.ink)
            Spacer()
        }
    }

    private func radioButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? MuseTheme.oxblood : MuseTheme.inkSoft)
                Text(label)
                    .font(MuseTheme.body(14))
                    .foregroundColor(MuseTheme.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(selected ? 0.85 : 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? MuseTheme.oxblood : MuseTheme.hairline,
                            lineWidth: selected ? 1.0 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var timeLabel: String {
        switch minutes {
        case ..<60: return "30 min"
        case 60: return "1 hour"
        default: return "\(minutes/60) hours"
        }
    }

    private func seedFromPassport() {
        if museumDraft.isEmpty, let last = passport.lastMuseum {
            museumDraft = last
        }
        if interests.isEmpty {
            let preferred = passport.passport.preferences
                .filter { $0.kind == .movement || $0.kind == .theme }
                .map(\.name)
                .filter(interestOptions.contains)
            interests = Set(preferred)
        }
    }

    // MARK: - Actions

    private func currentParameters() -> VisitParameters {
        VisitParameters(minutes: minutes,
                        energy: energy,
                        mode: mode,
                        interests: Array(interests))
    }

    private func startCurator() {
        let m = museumDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        let params = currentParameters()
        if passport.activeVisit?.museum != m {
            _ = passport.startVisit(museum: m, parameters: params)
        } else {
            passport.updateActiveVisitParameters(params)
        }
        pushedMuseum = m
        pushedParams = params
        pushChat = true
    }

    private func generateRoute() {
        let m = museumDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !m.isEmpty else { return }
        let params = currentParameters()
        if passport.activeVisit?.museum != m {
            _ = passport.startVisit(museum: m, parameters: params)
        } else {
            passport.updateActiveVisitParameters(params)
        }
        pushedMuseum = m
        pushedParams = params
        pushRoute = true
    }
}
