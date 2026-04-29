//
//  CuratorChatView.swift
//  The Muse-Link
//

import SwiftUI

struct CuratorChatView: View {
    let museum: String

    @EnvironmentObject var passport: PassportStore
    @EnvironmentObject var settings: SettingsStore

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var sending = false
    @State private var error: String?
    @State private var showFatigueSheet = false
    @State private var savedToast: String?
    @State private var cooldownRemaining: Int = 0
    @FocusState private var inputFocused: Bool

    private var service: AnthropicChatService { AnthropicChatService(settings: settings) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        chatHeader

                        if let err = error {
                            errorBanner(err)
                        }

                        ForEach(messages) { msg in
                            MessageBubble(message: msg,
                                          bodyScale: settings.curatorMode.bodyScale,
                                          audioGuideEnabled: settings.audioGuideEnabled) { suggestion in
                                save(suggestion)
                            }
                            .id(msg.id)
                        }

                        if sending {
                            TypingIndicator()
                                .padding(.leading, 4)
                        }

                        Color.clear.frame(height: 130).id("bottom")
                    }
                    .padding(.horizontal, MuseTheme.padL)
                    .padding(.top, 8)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: sending) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            inputBar
        }
        .parchment()
        .navigationTitle(museum)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .trailingAction) {
                Menu {
                    Button {
                        showFatigueSheet = true
                    } label: {
                        Label("I need a break", systemImage: "figure.seated.side")
                    }
                    Button(role: .destructive) {
                        passport.endActiveVisit()
                    } label: {
                        Label("End this visit", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showFatigueSheet) {
            FatigueSheet { level in
                showFatigueSheet = false
                handleFatigue(level: level)
            }
            .mediumDetent()
        }
        .alert("Curator unavailable",
               isPresented: Binding(get: { error != nil },
                                    set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .overlay(alignment: .top) {
            if let savedToast {
                Text(savedToast)
                    .font(MuseTheme.label(12)).tracking(1.5)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(MuseTheme.ink.opacity(0.9))
                    .foregroundColor(MuseTheme.parchment)
                    .clipShape(Capsule())
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { primeIfEmpty() }
    }

    // MARK: - Sub-views

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(MuseTheme.oxblood)
                Text("Curator unavailable")
                    .font(MuseTheme.title(14))
                    .foregroundColor(MuseTheme.ink)
                Spacer()
                Button { error = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(MuseTheme.inkSoft.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            Text(message)
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)
                .lineSpacing(2)
            if message.contains("preview") || message.contains("canvas") || message.contains("offline") {
                Text("Try running the app (⌘R) — previews can block network calls.")
                    .font(MuseTheme.body(12))
                    .foregroundColor(MuseTheme.inkSoft.opacity(0.85))
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(MuseTheme.oxblood.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(MuseTheme.oxblood.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR CURATOR")
                .font(MuseTheme.label()).tracking(1.2)
                .foregroundColor(MuseTheme.inkSoft)
            Text("A short conversation. One question at a time.")
                .font(MuseTheme.bodySerif(15))
                .foregroundColor(MuseTheme.inkSoft)
            HairlineRule().padding(.top, 6)
        }
        .padding(.bottom, 8)
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                fatigueQuickPill
                Spacer()
            }
            HStack(spacing: 10) {
                TextField("Ask the curator…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(MuseTheme.hairline, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(MuseTheme.parchment)
                        .frame(width: 38, height: 38)
                        .background(MuseTheme.oxblood)
                        .clipShape(Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || sending || cooldownRemaining > 0)
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty || sending || cooldownRemaining > 0 ? 0.5 : 1)
            }

            if cooldownRemaining > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass.bottomhalf.filled")
                        .foregroundColor(MuseTheme.brass)
                    Text("Rate limit — sending again in \(cooldownRemaining)s")
                        .font(MuseTheme.body(12))
                        .foregroundColor(MuseTheme.inkSoft)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, MuseTheme.padL)
        .padding(.bottom, 12)
        .padding(.top, 10)
        .background(
            LinearGradient(colors: [MuseTheme.parchment.opacity(0), MuseTheme.parchmentDk],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var fatigueQuickPill: some View {
        Button {
            showFatigueSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk").font(.system(size: 11, weight: .medium))
                Text("Feet hurting?")
            }
            .chip(selected: false)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func primeIfEmpty() {
        guard messages.isEmpty else { return }
        let opener: String = {
            let name = passport.passport.userName
            let prefs = passport.passport.preferenceSummary
            let greeting = name.isEmpty ? "Welcome." : "Welcome, \(name)."
            return "\(greeting) We're at \(museum). Given you lean toward \(prefs), what would you like today — a slow look at one or two works, or a wider tour? Take a breath; tell me what kind of visit you're in the mood for."
        }()
        messages.append(ChatMessage(role: .assistant, text: opener))
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        let userMsg = ChatMessage(role: .user, text: text)
        messages.append(userMsg)
        sending = true
        defer { sending = false }
        do {
            let reply = try await service.respond(history: messages,
                                                  passport: passport.passport,
                                                  currentMuseum: museum)
            messages.append(reply)
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

    private func handleFatigue(level: FatigueSheet.Level) {
        passport.recordFatigueCheck()
        let userText: String
        switch level {
        case .little:    userText = "I'm getting a little tired — could we slow down?"
        case .moderate:  userText = "My feet are starting to hurt. Could we take a short break or change the route?"
        case .heavy:     userText = "I'm pretty drained. I think I need a real rest — bench, café, or somewhere quiet."
        }
        draft = userText
        Task { await send() }
    }

    private func save(_ s: ArtworkSuggestion) {
        let artwork = Artwork(title: s.title, artist: s.artist, year: s.year, museum: museum)
        passport.saveArtwork(artwork)
        withAnimation { savedToast = "SAVED TO YOUR PASSPORT" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedToast = nil }
        }
    }
}

// MARK: - Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let onSave: (ArtworkSuggestion) -> Void
    let bodyScale: CGFloat
    let audioGuideEnabled: Bool

    @ObservedObject private var speech = SpeechPlayer.shared

    init(message: ChatMessage,
         bodyScale: CGFloat = 1.0,
         audioGuideEnabled: Bool = true,
         onSave: @escaping (ArtworkSuggestion) -> Void) {
        self.message = message
        self.bodyScale = bodyScale
        self.audioGuideEnabled = audioGuideEnabled
        self.onSave = onSave
    }

    private var isPlaying: Bool { speech.nowSpeakingID == message.id.uuidString && !speech.isPaused }
    private var isPaused: Bool  { speech.nowSpeakingID == message.id.uuidString &&  speech.isPaused }

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Text(message.text)
                    .font(message.role == .user
                          ? MuseTheme.body(16 * bodyScale)
                          : MuseTheme.bodySerif(17 * bodyScale))
                    .foregroundColor(message.role == .user ? MuseTheme.parchment : MuseTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.role == .user {
                                MuseTheme.ink
                            } else {
                                Color.white.opacity(0.8)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(message.role == .user ? Color.clear : MuseTheme.hairline, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: 320, alignment: message.role == .user ? .trailing : .leading)

                if message.role == .assistant && audioGuideEnabled {
                    Button {
                        speech.toggle(message.text, id: message.id.uuidString)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isPlaying ? "pause.fill"
                                              : isPaused ? "play.fill"
                                              : "speaker.wave.2")
                                .font(.system(size: 11))
                            Text(isPlaying ? "Pause" : isPaused ? "Resume" : "Listen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                (isPlaying || isPaused)
                                ? MuseTheme.oxblood.opacity(0.12)
                                : Color.white.opacity(0.6)
                            )
                        )
                        .overlay(
                            Capsule().stroke(MuseTheme.hairline, lineWidth: 0.5)
                        )
                        .foregroundColor(MuseTheme.ink)
                    }
                    .buttonStyle(.plain)
                }

                if let s = message.artworkSuggestion {
                    Button {
                        onSave(s)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark")
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Save \"\(s.title)\"")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("by \(s.artist)\(s.year.map { " · \($0)" } ?? "")")
                                    .font(.system(size: 12))
                                    .foregroundColor(MuseTheme.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(MuseTheme.brass.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MuseTheme.brass.opacity(0.55), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(MuseTheme.ink)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 320, alignment: .leading)
                }

                if !message.citations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(message.citations.prefix(4), id: \.url) { c in
                            Link(destination: URL(string: c.url) ?? URL(string: "https://example.com")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link").font(.system(size: 10))
                                    Text(c.title)
                                        .lineLimit(1)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(MuseTheme.inkSoft)
                            }
                        }
                    }
                    .frame(maxWidth: 320, alignment: .leading)
                }
            }
            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}

private struct TypingIndicator: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(MuseTheme.inkSoft.opacity(phase == i ? 0.9 : 0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.6))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Fatigue sheet

struct FatigueSheet: View {
    enum Level { case little, moderate, heavy }
    var onPick: (Level) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("A check-in", subtitle: "How are you holding up?")
                .padding(.top, 18)
            Text("I can slow the route, route us to a bench or courtyard, or wind down to one last work.")
                .font(MuseTheme.bodySerif(15))
                .foregroundColor(MuseTheme.inkSoft)

            Button { onPick(.little) } label: {
                fatigueRow(title: "A little tired", detail: "Slow the pace — fewer galleries, more time per work.")
            }
            Button { onPick(.moderate) } label: {
                fatigueRow(title: "Feet are starting to hurt", detail: "Find a bench or a sculpture courtyard, then keep going.")
            }
            Button { onPick(.heavy) } label: {
                fatigueRow(title: "I'm done — I need a real rest", detail: "Café break, then maybe one final piece on the way out.")
            }
            Spacer()
        }
        .padding(.horizontal, MuseTheme.padL)
        .parchment()
    }

    private func fatigueRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MuseTheme.title(17))
                .foregroundColor(MuseTheme.ink)
            Text(detail)
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MuseTheme.pad)
        .background(Color.white.opacity(0.65))
        .overlay(
            RoundedRectangle(cornerRadius: MuseTheme.corner)
                .stroke(MuseTheme.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))
    }
}
