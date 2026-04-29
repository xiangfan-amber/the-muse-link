//
//  VisitorIdentityCard.swift
//  The Muse-Link
//
//  Hero card for the Passport tab, modeled on muse-companion's "Your Art
//  Passport" panel. Pulls visitor identity, location, visit parameters,
//  curatorial profile, and route progress from the most recent visit.
//

import SwiftUI

struct VisitorIdentityCard: View {
    @EnvironmentObject var passport: PassportStore

    private var latest: MuseumVisit? { passport.passport.visits.first }
    private var name: String {
        passport.passport.userName.isEmpty ? "Visitor" : passport.passport.userName
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(MuseTheme.oxblood)
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 18) {
                topRow
                paramsAndProfile
                routeProgress
                memoryCopy
            }
            .padding(MuseTheme.padL)
            .background(Color.white.opacity(0.85))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(MuseTheme.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("VISITOR IDENTITY")
                    .font(MuseTheme.label(11)).tracking(1.5)
                    .foregroundColor(MuseTheme.inkSoft)
                Text(name)
                    .font(MuseTheme.display(36))
                    .foregroundColor(MuseTheme.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("LOCATION")
                    .font(MuseTheme.label(11)).tracking(1.5)
                    .foregroundColor(MuseTheme.inkSoft)
                Text(latest?.museum ?? "—")
                    .font(MuseTheme.title(18))
                    .foregroundColor(MuseTheme.ink)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Visit params + profile

    private var paramsAndProfile: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("VISIT PARAMETERS")
                    .font(MuseTheme.label(11)).tracking(1.5)
                    .foregroundColor(MuseTheme.inkSoft)
                HStack(spacing: 8) {
                    paramChip("Time", latest?.parameters?.timeLabel ?? "—")
                    paramChip("Energy", latest?.parameters?.energy.label ?? "—")
                    paramChip("Mode", modeShort)
                }
            }
            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("CURATORIAL PROFILE")
                    .font(MuseTheme.label(11)).tracking(1.5)
                    .foregroundColor(MuseTheme.inkSoft)
                FlowLayout(spacing: 6) {
                    ForEach(profileTags, id: \.self) { t in
                        Text(t)
                            .font(MuseTheme.body(12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(MuseTheme.oxblood.opacity(0.10))
                            .foregroundColor(MuseTheme.oxblood)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(MuseTheme.oxblood.opacity(0.35), lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if profileTags.isEmpty {
                        Text("No tags yet")
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.inkSoft)
                    }
                }
            }
        }
    }

    private var modeShort: String {
        guard let m = latest?.parameters?.mode else { return "—" }
        return m == .quick ? "Quick · 2" : "Deep · 3"
    }

    private var profileTags: [String] {
        let interests = latest?.parameters?.interests ?? []
        let movements = passport.passport.preferences
            .filter { $0.kind == .movement }
            .map(\.name)
        return Array((interests + movements).uniqued().prefix(6))
    }

    private func paramChip(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key)
                .font(MuseTheme.body(11))
                .foregroundColor(MuseTheme.inkSoft)
            Text(value)
                .font(MuseTheme.title(14))
                .foregroundColor(MuseTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MuseTheme.parchment.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MuseTheme.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Route progress

    private var routeProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ROUTE PROGRESS")
                    .font(MuseTheme.label(11)).tracking(1.5)
                    .foregroundColor(MuseTheme.inkSoft)
                Spacer()
                Text("\(completedCount) / \(totalStops) stops")
                    .font(MuseTheme.body(13))
                    .foregroundColor(MuseTheme.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MuseTheme.parchment.opacity(0.7))
                    Capsule()
                        .fill(MuseTheme.oxblood)
                        .frame(width: max(6, geo.size.width * progressFraction))
                }
            }
            .frame(height: 6)

            if !routeStops.isEmpty {
                VStack(spacing: 8) {
                    ForEach(routeStops) { stop in
                        stopRow(stop)
                    }
                }
                .padding(.top, 6)
            } else {
                Text("Generate a route from the Today tab to start checking off stops.")
                    .font(MuseTheme.body(12))
                    .foregroundColor(MuseTheme.inkSoft)
                    .padding(.top, 4)
            }
        }
    }

    private func stopRow(_ stop: RouteStop) -> some View {
        let done = passport.isStopCompleted(stop.id)
        return HStack(alignment: .top, spacing: 10) {
            Button {
                passport.toggleStopCompletion(stop.id)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(done ? MuseTheme.brass : MuseTheme.inkSoft.opacity(0.6))
            }
            .buttonStyle(.plain)
            .disabled(stop.isBreak)
            .opacity(stop.isBreak ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.title)
                    .font(MuseTheme.title(14))
                    .foregroundColor(done ? MuseTheme.inkSoft : MuseTheme.ink)
                    .strikethrough(done, color: MuseTheme.inkSoft.opacity(0.6))
                    .lineLimit(2)
                if let artist = stop.artist {
                    Text(artist + (stop.year.map { ", \($0)" } ?? "")
                         + (stop.room.map { " · \($0)" } ?? ""))
                        .font(MuseTheme.body(11))
                        .foregroundColor(MuseTheme.inkSoft)
                        .lineLimit(1)
                } else if stop.isBreak {
                    Text("Rest stop")
                        .font(MuseTheme.body(11))
                        .foregroundColor(MuseTheme.brass)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var routeStops: [RouteStop] {
        latest?.routePlan?.stops ?? []
    }
    private var nonBreakStops: [RouteStop] {
        routeStops.filter { !$0.isBreak }
    }
    private var completedCount: Int {
        let done = Set(latest?.completedStopIDs ?? [])
        return nonBreakStops.filter { done.contains($0.id) }.count
    }
    private var totalStops: Int {
        if !nonBreakStops.isEmpty { return nonBreakStops.count }
        return latest?.parameters?.mode.stops ?? 3
    }
    private var progressFraction: CGFloat {
        guard totalStops > 0 else { return 0 }
        return CGFloat(min(completedCount, totalStops)) / CGFloat(totalStops)
    }

    // MARK: - Memory copy

    private var memoryCopy: some View {
        Text("Your passport simulates **reusable memory across museum visits**. Walk into a different gallery next month and it remembers what moved you here, threading today's stops into tomorrow's route — so each visit builds on the last instead of starting from zero.")
            .font(MuseTheme.body(13))
            .foregroundColor(MuseTheme.inkSoft)
            .lineSpacing(2.5)
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
