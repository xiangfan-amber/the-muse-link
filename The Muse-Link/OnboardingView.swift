//
//  OnboardingView.swift
//  The Muse-Link
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var passport: PassportStore
    @EnvironmentObject var settings: SettingsStore

    @State private var page: Int = 0
    @State private var name: String = ""
    @State private var apiKeyDraft: String = ""

    var body: some View {
        ZStack {
            TabView(selection: $page) {
                welcomePage.tag(0)
                namePage.tag(1)
                preferencesPage.tag(2)
                apiKeyPage.tag(3)
            }
            .pagedNoIndicator()

            VStack {
                Spacer()
                bottomBar
                    .padding(.horizontal, MuseTheme.padL)
                    .padding(.bottom, 24)
            }
        }
        .parchment()
        .onAppear {
            name = passport.passport.userName
            apiKeyDraft = settings.apiKey
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("THE MUSE-LINK")
                .font(MuseTheme.label(14)).tracking(3)
                .foregroundColor(MuseTheme.inkSoft)
            Text("Your pocket\ncurator.")
                .font(MuseTheme.display(44))
                .multilineTextAlignment(.center)
                .foregroundColor(MuseTheme.ink)
            Text("A patient guide for any museum, shaped by what you've seen and what you love.")
                .font(MuseTheme.bodySerif(17))
                .multilineTextAlignment(.center)
                .foregroundColor(MuseTheme.inkSoft)
                .padding(.horizontal, MuseTheme.padL)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, MuseTheme.padL)
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Step 1 of 3", subtitle: "What should I call you?")
                .padding(.top, 80)
            Text("I'll greet you by name and remember the museums we visit together.")
                .font(MuseTheme.bodySerif())
                .foregroundColor(MuseTheme.inkSoft)
            TextField("Your name", text: $name)
                .autocapitalizeWords()
                .padding(MuseTheme.pad)
                .background(Color.white.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: MuseTheme.corner)
                        .stroke(MuseTheme.hairline, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))
            Spacer()
        }
        .padding(.horizontal, MuseTheme.padL)
        .padding(.bottom, 120)
    }

    private var preferencesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader("Step 2 of 3", subtitle: "What pulls you in?")
                    .padding(.top, 60)
                Text("Pick anything that speaks to you. You can change these later.")
                    .font(MuseTheme.bodySerif())
                    .foregroundColor(MuseTheme.inkSoft)

                preferenceGroup("Movements", kind: .movement, names: ArtPreference.movements)
                preferenceGroup("Mediums", kind: .medium, names: ArtPreference.mediums)
                preferenceGroup("Themes", kind: .theme, names: ArtPreference.themes)

                Spacer(minLength: 120)
            }
            .padding(.horizontal, MuseTheme.padL)
        }
    }

    private func preferenceGroup(_ title: String, kind: ArtPreference.Kind, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(MuseTheme.label())
                .foregroundColor(MuseTheme.inkSoft)
                .tracking(1.2)
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

    private var apiKeyPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Step 3 of 3", subtitle: "Connect your curator.")
                .padding(.top, 80)
            Text("The Muse-Link uses Anthropic's Claude with live web search to check current exhibitions and closures. Paste your API key — it's stored only on this device.")
                .font(MuseTheme.bodySerif())
                .foregroundColor(MuseTheme.inkSoft)
            SecureField("sk-ant-...", text: $apiKeyDraft)
                .textFieldStyle(.plain)
                .autocapitalizeNever()
                .autocorrectionDisabled()
                .padding(MuseTheme.pad)
                .background(Color.white.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: MuseTheme.corner)
                        .stroke(MuseTheme.hairline, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: MuseTheme.corner))
            Button {
                if let s = Clipboard.string() {
                    apiKeyDraft = s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste from clipboard")
                }
            }
            .buttonStyle(GhostButtonStyle())
            Text("You can add or change this later in Settings.")
                .font(MuseTheme.body(13))
                .foregroundColor(MuseTheme.inkSoft)
            Spacer()
        }
        .padding(.horizontal, MuseTheme.padL)
        .padding(.bottom, 120)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button("Back") { withAnimation { page -= 1 } }
                    .buttonStyle(GhostButtonStyle())
            }
            Button(page == 3 ? "Enter the museum" : "Continue") {
                advance()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity((page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1)
        }
    }

    private func advance() {
        switch page {
        case 1: passport.setUserName(name.trimmingCharacters(in: .whitespaces))
        case 3:
            settings.apiKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.onboardingComplete = true
            return
        default: break
        }
        withAnimation { page += 1 }
    }
}

// MARK: - Tiny FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var lineW: CGFloat = 0
        var totalH: CGFloat = 0
        var lineH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if lineW + size.width > maxW {
                totalH += lineH + spacing
                lineW = 0
                lineH = 0
            }
            lineW += size.width + spacing
            lineH = max(lineH, size.height)
        }
        totalH += lineH
        return CGSize(width: proposal.width ?? lineW, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineH + spacing
                lineH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
    }
}
