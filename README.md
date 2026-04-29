# The Muse-Link

The Muse-Link is a prototype museum companion app developed for the **Practicum** course in the **M.A. in Quantitative Methods in the Social Sciences (QMSS)** program at **Columbia University**.

It is an AI museum curator for iOS, iPadOS, and macOS. Tell it which museum you're visiting and what moves you, and it builds a focused three-stop narrative route shaped by your preferences and your past visits — not a list of recommendations, a story.

The curator speaks in short Socratic prompts instead of long lectures, threads today's visit to your "Art Passport" of past museums and saved artworks, uses live web search to confirm current exhibitions and gallery closures, and watches for fatigue cues so it can route you to a bench when your feet hurt.

Built in Swift / SwiftUI on top of the Anthropic API with the `web_search_20250305` tool enabled.

## Project Overview

This project explores how AI can be used to create a more personalized and engaging museum experience. Instead of treating each museum visit as an isolated event, The Muse-Link is designed to connect a visitor’s interests, visit preferences, and evolving “art passport” into a more meaningful narrative journey.

The prototype allows users to:
- choose a museum
- select available time and energy level
- choose a visit mode such as Quick Visit or Deep Dive
- select artistic interests
- generate a personalized narrative route
- explore artwork insights
- view an Art Passport that simulates reusable memory across museum visits

## Course Context

This project was created as part of a QMSS Practicum class assignment focused on designing and building a small AI-powered assistant or application. The goal of the assignment was not only to demonstrate technical implementation, but also to show product thinking, interface design, and a clear understanding of where AI adds value in a real user workflow.

## Features

- **Plan-your-visit wizard** — five numbered steps (museum, time, energy, mode, interests) drive a custom route generator
- **Narrative route + Insight pane** — a three-stop story with a "look first, then read" observation and a separate curator's note per stop
- **Interactive route progress** — check off stops as you walk; progress persists across launches and shows on the Passport
- **Curator chat** — short Socratic replies grounded in your Art Passport, with inline citations from web search
- **Audio guide** — every curator reply has a Listen button (AVSpeechSynthesizer; pause/resume)
- **Companion modes** — Standard / Kid-friendly / Slow & spacious / Scholar — changes voice, pace, and body-text size
- **Fatigue check-ins** — a "Feet hurting?" pill seeds the curator with a contextual prompt and tracks check-ins per visit
- **Art Passport** — visits, saved artworks (with notes), preferences, and six achievement stamps
- **Visitor Identity card** — at the top of the Passport: name, museum, visit parameters, curatorial profile, route progress
- **Daily artwork card** — Home tab shows one curated piece per day with a "look first" observation, cached by date
- **Settings** — API key (Keychain), model picker, companion mode, audio toggle, Test connection button, restart onboarding

## Requirements

- macOS 14+ with Xcode 16+
- iOS 17+ / macOS 14+ deployment target (iPadOS and visionOS targets are also configured)
- An Anthropic API key from [console.anthropic.com](https://console.anthropic.com) with credit on the account
- The `web_search` tool enabled on your Anthropic account (default for new accounts)

## Setup

### 1. Clone and open

```bash
git clone https://github.com/<your-username>/the-muse-link.git
cd "the-muse-link"
open "The Muse-Link.xcodeproj"
```

### 2. Set your team and bundle ID

In Xcode, select the project → **The Muse-Link** target → **Signing & Capabilities**:

- Set **Team** to your Apple ID's team
- Change the **Bundle Identifier** to something unique (the default `Xiang-Fan.The-Muse-Link` will collide with anyone else's signing)

The project uses `PBXFileSystemSynchronizedRootGroup`, so any `.swift` file dropped into `The Muse-Link/` is picked up automatically — no need to add files to the project explicitly.

### 3. Run

Pick a destination and hit **⌘R**:

- **iPhone Simulator** — fastest path; no signing required
- **My Mac** — runs as a native macOS app via Designed-for-iPad / Catalyst
- **Physical iPhone** — requires the team set in step 2 and a free Apple ID for development signing

### 4. Add your Anthropic key

On first launch you'll go through onboarding. The third step asks for your API key. Paste it (use the **Paste from clipboard** button — `SecureField` ⌘V can be flaky on macOS) and tap **Enter the museum**.

You can change the key any time at **Settings → Anthropic API key → Update key**, and use the **Test connection** button to verify it's working.

The key is stored in your device's Keychain. It is never sent anywhere except `api.anthropic.com`.

## Architecture

```
The Muse-Link/
├── The_Muse_LinkApp.swift          App entry
├── ContentView.swift               Thin wrapper around RootView
├── RootView.swift                  TabView + onboarding gate; injects stores
├── DesignSystem.swift              Palette (parchment + ink + oxblood + brass), serif typography, view modifiers
├── CrossPlatform.swift             #if os shims so iOS-only modifiers compile on macOS
│
├── Models.swift                    ArtPassport, MuseumVisit, Artwork, ChatMessage, RouteStop, VisitParameters
├── PassportStore.swift             Persists Art Passport JSON in Application Support
├── SettingsStore.swift             API key (Keychain), companion mode, model, audio toggle
│
├── AnthropicChatService.swift      ChatService protocol + Anthropic implementation with web_search tool
├── SpeechPlayer.swift              AVSpeechSynthesizer wrapper (pause/resume/stop)
├── DailyArtwork.swift              Home-tab daily pick with date-keyed cache
│
├── OnboardingView.swift            Welcome / name / preferences / API key
├── HomeView.swift                  Plan-your-visit wizard (museum, time, energy, mode, interests)
├── CuratorChatView.swift           Chat bubbles, fatigue sheet, audio guide pill, save-artwork affordance
├── RouteView.swift                 Narrative route, stop cards with checkboxes, Insight pane
├── PassportView.swift              Tabbed passport (visits / favorites / preferences) + ArtworkDetailView
├── PassportStamps.swift            Six achievement stamps computed from passport state
├── VisitorIdentityCard.swift       Hero card on Passport tab with route checklist
├── SettingsView.swift              API key + Test connection + companion modes + audio toggle
│
└── The Muse-Link.entitlements      App Sandbox network.client + user-selected files (read-only)
```

### Data flow

The two stores (`SettingsStore`, `PassportStore`) are created in `RootView.init()` and propagated as `@EnvironmentObject` to every screen. `DailyArtworkStore` is a third store wired the same way. Anything that needs to talk to Anthropic builds an `AnthropicChatService` on demand using the `SettingsStore` injected from the environment.

`ArtPassport` is serialized as JSON to `Application Support/muselink_passport.json`. The Anthropic API key lives in the Keychain under `muselink.anthropic.apiKey`. Companion mode, model name, and onboarding flag live in `UserDefaults`.

## Known limitations

- **App Store readiness**: the BYOK (bring-your-own-key) model will likely be rejected for App Store submission per Apple guideline 4.0. To ship publicly, replace the direct `URLRequest` to `api.anthropic.com` with a request to your own proxy server that holds the key, and monetize via in-app subscription. The app is otherwise privacy-clean (no analytics, no third-party tracking, no IDFA).
- **Rate limits**: Anthropic Tier 1 caps you at 30,000 input tokens/min. Route generation is heavy because of `web_search`. The app shows a calm cooldown banner when 429s happen.
- **Web search availability**: the `web_search_20250305` tool requires it to be enabled on your Anthropic account. Most accounts have it; if you see HTTP 400 mentioning `web_search`, it's not enabled and chat/route will fail.

## Tech notes

- **Anthropic API**: uses `claude-sonnet-4-6` by default; switchable to Opus 4.6 or Haiku 4.5 in Settings
- **Models**: structured JSON responses for routes (parsed via `JSONExtractor`), free-form replies for chat
- **Persistence**: JSON file for passport, Keychain for key, UserDefaults for the rest
- **Cross-platform**: iOS + iPadOS + macOS + visionOS targets; macOS uses `#if os(iOS)` shims for `navigationBarTitleDisplayMode`, `tabBar` toolbarBackground, and friends

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

The narrative route format, "look first, then read" insight pattern, and Visitor Identity card are inspired by the [muse-companion](https://muse-companion--iiivyyy1115.replit.app/) Replit project.
