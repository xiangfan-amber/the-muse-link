//
//  CrossPlatform.swift
//  The Muse-Link
//
//  Cross-platform shims so iOS-only modifiers compile (as no-ops) on macOS.
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Clipboard

enum Clipboard {
    /// Returns the string currently on the system clipboard, if any.
    static func string() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}

extension View {
    /// Inline navigation title — iOS only; no-op on macOS.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Capitalize words while typing — iOS only.
    @ViewBuilder
    func autocapitalizeWords() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.words)
        #else
        self
        #endif
    }

    /// Disable autocapitalization — iOS only.
    @ViewBuilder
    func autocapitalizeNever() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    /// Parchment-colored tab bar background — iOS only.
    @ViewBuilder
    func parchmentTabBar() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(MuseTheme.parchment, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        #else
        self
        #endif
    }

    /// Paged TabView style with hidden index — iOS only; falls back to default
    /// TabView on macOS.
    @ViewBuilder
    func pagedNoIndicator() -> some View {
        #if os(iOS)
        self
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        #else
        self
        #endif
    }

    /// Medium presentation detents — iOS only; no-op on macOS sheets.
    @ViewBuilder
    func mediumDetent() -> some View {
        #if os(iOS)
        self.presentationDetents([.medium])
        #else
        self
        #endif
    }
}

// Toolbar placement that maps to the trailing top bar on iOS and the
// equivalent action slot on macOS.
extension ToolbarItemPlacement {
    static var trailingAction: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}
