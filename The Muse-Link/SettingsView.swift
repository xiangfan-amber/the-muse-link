//
//  SettingsView.swift
//  The Muse-Link
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var passport: PassportStore

    @State private var nameDraft: String = ""
    @State private var keyDraft: String = ""
    @State private var showKey: Bool = false
    @State private var confirmReset = false
    @State private var testStatus: TestStatus = .idle

    enum TestStatus: Equatable {
        case idle
        case running
        case ok(String)
        case fail(String)
    }

    private let models = ["claude-sonnet-4-6", "claude-opus-4-6", "claude-haiku-4-5-20251001"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {

                    SectionHeader("Visitor")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR NAME")
                            .font(MuseTheme.label()).tracking(1.2)
                            .foregroundColor(MuseTheme.inkSoft)
                        TextField("Your name", text: $nameDraft)
                            .padding(MuseTheme.pad)
                            .background(Color.white.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))
                            .onSubmit {
                                passport.setUserName(nameDraft.trimmingCharacters(in: .whitespaces))
                            }
                    }
                    .wallLabel()

                    SectionHeader("Curator")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ANTHROPIC API KEY")
                            .font(MuseTheme.label()).tracking(1.2)
                            .foregroundColor(MuseTheme.inkSoft)

                        HStack(spacing: 8) {
                            Group {
                                if showKey {
                                    TextField("sk-ant-…", text: $keyDraft)
                                } else {
                                    SecureField("sk-ant-…", text: $keyDraft)
                                }
                            }
                            .textFieldStyle(.plain)
                            .autocapitalizeNever()
                            .autocorrectionDisabled()

                            Button { showKey.toggle() } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                                    .foregroundColor(MuseTheme.inkSoft)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(MuseTheme.pad)
                        .background(Color.white.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))

                        HStack(spacing: 10) {
                            Button {
                                if let s = Clipboard.string() {
                                    keyDraft = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste from clipboard")
                                }
                            }
                            .buttonStyle(GhostButtonStyle())

                            Button {
                                settings.apiKey = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            } label: {
                                Text(settings.hasAPIKey ? "Update key" : "Save key")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        }

                        if settings.hasAPIKey {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(MuseTheme.brass)
                                Text("Key saved · ends in \(settings.apiKey.suffix(4))")
                                    .font(MuseTheme.body(12))
                                    .foregroundColor(MuseTheme.inkSoft)
                            }

                            Button {
                                Task { await testConnection() }
                            } label: {
                                HStack(spacing: 6) {
                                    if case .running = testStatus {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                    }
                                    Text(testButtonLabel)
                                }
                            }
                            .buttonStyle(GhostButtonStyle())
                            .disabled(isRunning)

                            switch testStatus {
                            case .ok(let msg):
                                statusLine(icon: "checkmark.circle.fill",
                                           color: MuseTheme.brass,
                                           text: msg)
                            case .fail(let msg):
                                statusLine(icon: "xmark.octagon.fill",
                                           color: MuseTheme.oxblood,
                                           text: msg)
                            default:
                                EmptyView()
                            }
                        }

                        Text("MODEL")
                            .font(MuseTheme.label()).tracking(1.2)
                            .foregroundColor(MuseTheme.inkSoft)
                            .padding(.top, 4)
                        Picker("Model", selection: $settings.modelName) {
                            ForEach(models, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(MuseTheme.ink)
                        .padding(.horizontal, MuseTheme.pad)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))

                        Text("Stored only on this device. Used for chat and route planning, with web search to confirm current exhibitions and closures.")
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.inkSoft)
                    }
                    .wallLabel()

                    SectionHeader("Companion mode")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(CuratorMode.allCases) { mode in
                            Button {
                                settings.curatorMode = mode
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: settings.curatorMode == mode
                                          ? "largecircle.fill.circle"
                                          : "circle")
                                        .foregroundColor(settings.curatorMode == mode
                                                         ? MuseTheme.oxblood
                                                         : MuseTheme.inkSoft)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(mode.label)
                                            .font(MuseTheme.title(16))
                                            .foregroundColor(MuseTheme.ink)
                                        Text(mode.subtitle)
                                            .font(MuseTheme.body(13))
                                            .foregroundColor(MuseTheme.inkSoft)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Toggle(isOn: $settings.audioGuideEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Audio guide")
                                    .font(MuseTheme.title(16))
                                    .foregroundColor(MuseTheme.ink)
                                Text("Show a Listen button on every curator reply.")
                                    .font(MuseTheme.body(13))
                                    .foregroundColor(MuseTheme.inkSoft)
                            }
                        }
                        .tint(MuseTheme.oxblood)
                        .padding(.top, 6)
                    }
                    .wallLabel()

                    SectionHeader("App")
                    VStack(spacing: 10) {
                        Button {
                            confirmReset = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Restart onboarding")
                                Spacer()
                            }
                        }
                        .buttonStyle(GhostButtonStyle())

                        Text("The Muse-Link · v0.1\nA pocket curator for any museum.")
                            .font(MuseTheme.body(12))
                            .foregroundColor(MuseTheme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 12)
                    }
                    .wallLabel()

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, MuseTheme.padL)
                .padding(.top, 8)
            }
            .parchment()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(MuseTheme.label(12)).tracking(2.5)
                        .foregroundColor(MuseTheme.inkSoft)
                }
            }
            .onAppear {
                nameDraft = passport.passport.userName
                keyDraft = settings.apiKey
            }
            .alert("Restart onboarding?", isPresented: $confirmReset) {
                Button("Restart", role: .destructive) { settings.resetOnboarding() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be guided through the welcome flow again. Your passport stays intact.")
            }
        }
        .tint(MuseTheme.oxblood)
    }

    // MARK: - Test connection

    private var isRunning: Bool {
        if case .running = testStatus { return true }
        return false
    }

    private var testButtonLabel: String {
        switch testStatus {
        case .running: return "Testing…"
        case .ok:      return "Test again"
        case .fail:    return "Test connection"
        case .idle:    return "Test connection"
        }
    }

    private func statusLine(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).foregroundColor(color)
            Text(text)
                .font(MuseTheme.body(12))
                .foregroundColor(MuseTheme.ink)
                .lineLimit(6)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func testConnection() async {
        guard settings.hasAPIKey else { return }
        testStatus = .running

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(settings.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 20

        let body: [String: Any] = [
            "model": settings.modelName,
            "max_tokens": 4,
            "messages": [["role": "user", "content": "ping"]]
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if (200...299).contains(status) {
                testStatus = .ok("Key works. Connection to Anthropic confirmed.")
            } else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                testStatus = .fail(diagnose(status: status, body: msg))
            }
        } catch {
            testStatus = .fail("Network error: \(error.localizedDescription)")
        }
    }

    private func diagnose(status: Int, body: String) -> String {
        let snippet = String(body.prefix(200))
        switch status {
        case 401: return "401 — invalid x-api-key. The stored key was rejected. Generate a fresh key in console.anthropic.com and paste it here."
        case 403: return "403 — your account doesn't have access to this model or feature. Try a different model in the picker above."
        case 429: return "429 — rate-limited or out of credits. Add credit at console.anthropic.com → Billing."
        case 400 where body.contains("web_search"):
            return "400 — web_search tool not enabled on this account. The chat will still work without it; ping me to disable web search."
        case 400: return "400 — request rejected: \(snippet)"
        case 500...599: return "Anthropic returned a server error (\(status)). Try again in a moment."
        default: return "HTTP \(status): \(snippet)"
        }
    }
}
