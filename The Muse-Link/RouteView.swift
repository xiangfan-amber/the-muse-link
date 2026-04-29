//
//  RouteView.swift
//  The Muse-Link
//
//  "Your personalized narrative route" — a three-stop story shaped by visit
//  parameters and the Art Passport, with a slide-in Insight pane per stop.
//

import SwiftUI

struct RouteView: View {
    let museum: String
    let parameters: VisitParameters

    @EnvironmentObject var passport: PassportStore
    @EnvironmentObject var settings: SettingsStore

    @State private var plan: RoutePlan?
    @State private var loading = false
    @State private var error: String?
    @State private var selectedStop: RouteStop?
    @State private var cooldownRemaining: Int = 0

    private var service: AnthropicChatService { AnthropicChatService(settings: settings) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if cooldownRemaining > 0 {
                    cooldownBanner
                }

                if loading && plan == nil {
                    loadingPlaceholder
                } else if let plan {
                    narrativeBox(plan)
                    passportThreadCallout(plan)
                    stopsList(plan)
                    insightPane
                    actions
                } else {
                    emptyState
                    actions
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, MuseTheme.padL)
            .padding(.top, 8)
        }
        .parchment()
        .navigationTitle("Today's Route")
        .inlineNavigationTitle()
        .alert("Couldn't build a route",
               isPresented: Binding(get: { error != nil },
                                    set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .task {
            // If we already have a plan attached to the active visit, restore it
            // so checkmarks survive navigating away and back.
            if plan == nil, let saved = passport.activeVisit?.routePlan {
                plan = saved
            } else if plan == nil {
                await generate()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR PERSONALIZED NARRATIVE ROUTE")
                .font(MuseTheme.label()).tracking(1.2)
                .foregroundColor(MuseTheme.inkSoft)
            Text(museum)
                .font(MuseTheme.display(28))
                .foregroundColor(MuseTheme.ink)
            Text("Not a list of recommendations — a \(parameters.mode.stops)-stop story shaped by your choices, designed to unfold slowly as you walk.")
                .font(MuseTheme.bodySerif(15))
                .foregroundColor(MuseTheme.inkSoft)
                .lineSpacing(2)
            HairlineRule().padding(.top, 6)
        }
    }

    // MARK: - Narrative box

    private func narrativeBox(_ plan: RoutePlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !plan.narrative.isEmpty {
                Text("\u{201C}\(plan.narrative)\u{201D}")
                    .font(MuseTheme.bodySerif(17))
                    .italic()
                    .foregroundColor(MuseTheme.ink)
                    .lineSpacing(3)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func passportThreadCallout(_ plan: RoutePlan) -> some View {
        Group {
            if !plan.passportThread.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "book.closed")
                        .foregroundColor(MuseTheme.oxblood)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From your Art Passport:")
                            .font(MuseTheme.title(14))
                            .foregroundColor(MuseTheme.ink)
                        Text(plan.passportThread)
                            .font(MuseTheme.body(13))
                            .foregroundColor(MuseTheme.inkSoft)
                            .lineSpacing(2)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MuseTheme.hairline, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Stops list

    private func stopsList(_ plan: RoutePlan) -> some View {
        VStack(spacing: 14) {
            ForEach(Array(plan.stops.enumerated()), id: \.element.id) { idx, stop in
                stopCard(idx: idx, stop: stop, total: plan.stops.count)
            }
        }
    }

    private func stopCard(idx: Int, stop: RouteStop, total: Int) -> some View {
        let done = passport.isStopCompleted(stop.id)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(done
                              ? MuseTheme.brass.opacity(0.85)
                              : (stop.isBreak ? MuseTheme.brass : MuseTheme.oxblood))
                        .frame(width: 36, height: 36)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(MuseTheme.parchment)
                    } else {
                        Text("\(idx + 1)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(MuseTheme.parchment)
                    }
                }
                if idx < total - 1 {
                    Rectangle()
                        .fill(done ? MuseTheme.brass.opacity(0.6) : MuseTheme.hairline)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(stop.title)
                        .font(MuseTheme.title(20))
                        .foregroundColor(done ? MuseTheme.inkSoft : MuseTheme.ink)
                        .strikethrough(done, color: MuseTheme.inkSoft.opacity(0.6))
                    Spacer()
                    if !stop.isBreak {
                        Button {
                            passport.toggleStopCompletion(stop.id)
                        } label: {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(done ? MuseTheme.brass : MuseTheme.inkSoft.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(done ? "Mark stop incomplete" : "Mark stop complete")
                    }
                }

                if let artist = stop.artist {
                    Text(artist + (stop.year.map { ", \($0)" } ?? ""))
                        .font(MuseTheme.body(14))
                        .foregroundColor(MuseTheme.inkSoft)
                }

                if let room = stop.room, !room.isEmpty {
                    Text(room)
                        .font(MuseTheme.body(13))
                        .foregroundColor(MuseTheme.inkSoft.opacity(0.85))
                }

                if !stop.detail.isEmpty {
                    Text(stop.detail)
                        .font(MuseTheme.bodySerif(15))
                        .foregroundColor(MuseTheme.ink)
                        .lineSpacing(2)
                        .padding(.top, 4)
                }

                HStack(spacing: 10) {
                    Label("\(stop.minutes) min", systemImage: "clock")
                        .font(MuseTheme.body(12))
                        .foregroundColor(MuseTheme.inkSoft)

                    if stop.isBreak {
                        Label("Rest stop", systemImage: "cup.and.saucer")
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.brass)
                    }

                    Spacer()

                    if !stop.isBreak {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedStop?.id == stop.id {
                                    selectedStop = nil
                                } else {
                                    selectedStop = stop
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedStop?.id == stop.id ? "Hide insight" : "View insight")
                                Image(systemName: selectedStop?.id == stop.id ? "chevron.up" : "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .font(MuseTheme.body(13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(MuseTheme.hairline, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(MuseTheme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(Color.white.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedStop?.id == stop.id ? MuseTheme.oxblood.opacity(0.5) : MuseTheme.hairline,
                            lineWidth: selectedStop?.id == stop.id ? 1.2 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Insight pane

    private var insightPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insight")
                .font(MuseTheme.display(24))
                .foregroundColor(MuseTheme.ink)
            Text("Look first, then read. A short observation to guide your eye, followed by the curator's note.")
                .font(MuseTheme.bodySerif(14))
                .foregroundColor(MuseTheme.inkSoft)
                .lineSpacing(2)
            HairlineRule()

            if let stop = selectedStop {
                VStack(alignment: .leading, spacing: 14) {
                    Text(stop.title)
                        .font(MuseTheme.title(20))
                        .foregroundColor(MuseTheme.ink)

                    if let observation = stop.observation, !observation.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LOOK FIRST")
                                .font(MuseTheme.label(11)).tracking(1.5)
                                .foregroundColor(MuseTheme.oxblood)
                            Text(observation)
                                .font(MuseTheme.bodySerif(16))
                                .italic()
                                .foregroundColor(MuseTheme.ink)
                                .lineSpacing(3)
                        }
                    }

                    if let note = stop.curatorNote, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CURATOR'S NOTE")
                                .font(MuseTheme.label(11)).tracking(1.5)
                                .foregroundColor(MuseTheme.inkSoft)
                            Text(note)
                                .font(MuseTheme.bodySerif(15))
                                .foregroundColor(MuseTheme.ink)
                                .lineSpacing(3)
                        }
                    }

                    if let artist = stop.artist {
                        Text(artist + (stop.year.map { ", \($0)" } ?? "") + (stop.room.map { " · \($0)" } ?? ""))
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.inkSoft)
                            .padding(.top, 4)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Text("Resting point")
                        .font(MuseTheme.title(20))
                        .foregroundColor(MuseTheme.inkSoft)
                    Text("Pick a stop from your route above to see its detailed insight and observation notes.")
                        .font(MuseTheme.body(13))
                        .foregroundColor(MuseTheme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MuseTheme.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Loading / empty

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.4))
                    .frame(height: 120)
            }
            HStack {
                ProgressView().tint(MuseTheme.oxblood)
                Text("Checking today's exhibitions and gallery hours…")
                    .font(MuseTheme.body(13))
                    .foregroundColor(MuseTheme.inkSoft)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No route yet.")
                .font(MuseTheme.title(20))
                .foregroundColor(MuseTheme.ink)
            Text("Tap below and I'll check the museum's current exhibitions, closures, and shape something around your Art Passport.")
                .font(MuseTheme.bodySerif(15))
                .foregroundColor(MuseTheme.inkSoft)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack {
                Image(systemName: loading ? "hourglass"
                                  : (cooldownRemaining > 0 ? "clock" : "wand.and.stars"))
                Text(cooldownRemaining > 0
                     ? "Try again in \(cooldownRemaining)s"
                     : (plan == nil ? "Plan my route" : "Re-route"))
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(loading || cooldownRemaining > 0)
        .opacity(cooldownRemaining > 0 ? 0.6 : 1)
        .padding(.top, 12)
    }

    private var cooldownBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass.bottomhalf.filled")
                    .foregroundColor(MuseTheme.brass)
                Text("Anthropic rate limit reached")
                    .font(MuseTheme.title(14))
                    .foregroundColor(MuseTheme.ink)
                Spacer()
                Text("\(cooldownRemaining)s")
                    .font(MuseTheme.body(13)).monospacedDigit()
                    .foregroundColor(MuseTheme.inkSoft)
            }
            Text("Route generation pulls live exhibition data, which uses input tokens fast. The Re-route button will re-enable when the limit resets — usually within a minute.")
                .font(MuseTheme.body(12))
                .foregroundColor(MuseTheme.inkSoft)
                .lineSpacing(2)
        }
        .padding(12)
        .background(MuseTheme.brass.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(MuseTheme.brass.opacity(0.4), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func generate() async {
        loading = true
        selectedStop = nil
        defer { loading = false }
        do {
            let p = try await service.planRoute(museum: museum,
                                                passport: passport.passport,
                                                parameters: parameters)
            plan = p
            passport.attachRoute(p)
        } catch let e as CuratorError {
            if case .rateLimited(let secs) = e {
                startCooldown(secs)
            } else {
                error = e.errorDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startCooldown(_ seconds: Int) {
        cooldownRemaining = max(seconds, 5)
        Task { @MainActor in
            while cooldownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                cooldownRemaining -= 1
            }
        }
    }
}
