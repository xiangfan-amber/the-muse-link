//
//  RootView.swift
//  The Muse-Link
//
//  App-level container: gates onboarding, then shows the main TabView.
//

import SwiftUI

struct RootView: View {
    @StateObject private var settings: SettingsStore
    @StateObject private var passport: PassportStore
    @StateObject private var daily: DailyArtworkStore
    @State private var selectedTab: Int = 0

    init() {
        let s = SettingsStore()
        let p = PassportStore()
        _settings = StateObject(wrappedValue: s)
        _passport = StateObject(wrappedValue: p)
        _daily = StateObject(wrappedValue: DailyArtworkStore(settings: s, passport: p))
    }

    var body: some View {
        Group {
            if settings.onboardingComplete {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem {
                            Label("Today", systemImage: "sparkles")
                        }
                        .tag(0)

                    PassportView()
                        .tabItem {
                            Label("Passport", systemImage: "book.closed")
                        }
                        .tag(1)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag(2)
                }
                .tint(MuseTheme.oxblood)
                .parchmentTabBar()
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environmentObject(settings)
        .environmentObject(passport)
        .environmentObject(daily)
        .preferredColorScheme(.light)
    }
}

#Preview {
    RootView()
}
