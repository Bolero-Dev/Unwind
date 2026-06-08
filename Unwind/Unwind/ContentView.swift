//
//  ContentView.swift
//  Unwind
//
//  Created by Leah Cluff on 4/10/23.
//

import SwiftUI

struct ContentView: View {
    /// Brief "Unwind" splash shown on launch, then it fades into Home.
    @State private var showSplash = true

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    Gradient.blueGradient
                        .ignoresSafeArea()

                    // Mountain pinned flush to the bottom of the screen, full width.
                    // scaledToFit keeps the artwork's aspect ratio so it scales with
                    // any device, and filling the screen bottom-aligned (ignoring the
                    // safe area) makes its base bleed to the very bottom edge — so no
                    // gradient shows underneath it.
                    Image("Mountain1")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .ignoresSafeArea()

                    VStack(alignment: .leading) {
                        Text("Home")
                            .font(.custom("Montserrat-SemiBold", size: 40))
                            .padding(.leading, 40)
                            .padding(.top, 40)

                        Spacer()

                        VStack(spacing: 28) {
                            NavigationLink("Meditation")      { Meditate() }
                            NavigationLink("Journal Entries") { JournalEntryList() }
                            NavigationLink("Reminders")       { Reminders() }
                        }
                        .frame(maxWidth: .infinity)          // center the links across the screen
                        .font(.custom("Montserrat-Regular", size: 26))
                        .tint(.white)   // keep links white instead of the default accent tint

                        Spacer()
                    }
                }
                .foregroundStyle(.white)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Hold the splash briefly, then gently fade into Home.
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeInOut(duration: 0.6)) { showSplash = false }
        }
    }
}

/// The launch splash: the pre-designed "Unwind" script artwork, filled to the
/// full screen (its dark top matches the native launch color, so the hand-off
/// from the system launch screen is seamless).
private struct SplashView: View {
    var body: some View {
        GeometryReader { geo in
            Image("LaunchScreen")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
