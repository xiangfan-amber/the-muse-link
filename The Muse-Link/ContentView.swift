//
//  ContentView.swift
//  The Muse-Link
//
//  Thin wrapper around RootView so existing references still compile.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
}
