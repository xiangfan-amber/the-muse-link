//
//  PassportStamps.swift
//  The Muse-Link
//
//  Achievement stamps computed from passport state. Rendered as a
//  horizontally-scrolling row of wax-seal-style stamps at the top of the
//  Passport tab.
//

import SwiftUI

struct PassportStamp: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let unlocked: Bool
}

enum PassportStamps {
    static func compute(_ p: ArtPassport) -> [PassportStamp] {
        let visits = p.visits.count
        let saves = p.favorites.count
        let movements = Set(
            p.preferences
                .filter { $0.kind == .movement }
                .map(\.name)
        ).count
        let museums = Set(p.visits.map(\.museum)).count

        return [
            PassportStamp(
                id: "first_visit",
                title: "First Visit",
                detail: "You stepped into your first museum.",
                icon: "building.columns.fill",
                unlocked: visits >= 1
            ),
            PassportStamp(
                id: "first_save",
                title: "First Save",
                detail: "You bookmarked your first artwork.",
                icon: "bookmark.fill",
                unlocked: saves >= 1
            ),
            PassportStamp(
                id: "five_visits",
                title: "Frequent Visitor",
                detail: "Five museum visits logged.",
                icon: "5.circle.fill",
                unlocked: visits >= 5
            ),
            PassportStamp(
                id: "ten_saves",
                title: "Collector",
                detail: "Ten artworks saved to your passport.",
                icon: "books.vertical.fill",
                unlocked: saves >= 10
            ),
            PassportStamp(
                id: "three_movements",
                title: "Open Eye",
                detail: "Following three different movements.",
                icon: "eye.fill",
                unlocked: movements >= 3
            ),
            PassportStamp(
                id: "three_museums",
                title: "Wanderer",
                detail: "Three distinct museums visited.",
                icon: "map.fill",
                unlocked: museums >= 3
            )
        ]
    }
}

// MARK: - Stamp row view

struct StampRow: View {
    let stamps: [PassportStamp]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STAMPS")
                    .font(MuseTheme.label())
                    .tracking(1.2)
                    .foregroundColor(MuseTheme.inkSoft)
                Spacer()
                Text("\(stamps.filter(\.unlocked).count) / \(stamps.count)")
                    .font(MuseTheme.body(12))
                    .foregroundColor(MuseTheme.inkSoft)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stamps) { stamp in
                        StampBadge(stamp: stamp)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }
}

struct StampBadge: View {
    let stamp: PassportStamp

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(stamp.unlocked
                          ? MuseTheme.oxblood.opacity(0.92)
                          : Color.white.opacity(0.5))
                Circle()
                    .stroke(stamp.unlocked
                            ? MuseTheme.oxblood.opacity(0.4)
                            : MuseTheme.hairline,
                            lineWidth: stamp.unlocked ? 3 : 0.5)
                    .padding(2)
                Image(systemName: stamp.unlocked ? stamp.icon : "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(stamp.unlocked ? MuseTheme.parchment : MuseTheme.inkSoft.opacity(0.7))
            }
            .frame(width: 64, height: 64)
            .opacity(stamp.unlocked ? 1 : 0.55)

            Text(stamp.title)
                .font(MuseTheme.label(11))
                .tracking(1.0)
                .foregroundColor(stamp.unlocked ? MuseTheme.ink : MuseTheme.inkSoft)
                .lineLimit(1)
            Text(stamp.detail)
                .font(MuseTheme.body(10))
                .foregroundColor(MuseTheme.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 96)
    }
}
