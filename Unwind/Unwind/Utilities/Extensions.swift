//
//  Extensions.swift
//  Unwind
//
//  Created by Leah Cluff on 4/10/23.
//

import SwiftUI
import os

/// App-wide unified logging. Categories let you filter the stream in Console.app
/// or the Xcode console (filter by subsystem = the app's bundle id). Errors are
/// recorded rather than silently swallowed, which is what made the on-device
/// haptics issue hard to trace.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Unwind"
    static let haptics = Logger(subsystem: subsystem, category: "haptics")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let data = Logger(subsystem: subsystem, category: "data")
}

// MARK: - Theme

extension Color {
    static let jaguar = Color("Jaguar")
    static let midnight = Color("Midnight")
    static let sherpaBlue = Color("SherpaBlue")
    static let blueLagoon = Color("BlueLagoon")
    static let vividTangerine = Color("VividTangerine")
    static let desertSand = Color("DesertSand")
}

extension Gradient {
    /// The app's dark background, top to bottom.
    static let blueGradient = LinearGradient(
        colors: [.jaguar, .midnight, .sherpaBlue, .blueLagoon],
        startPoint: .top, endPoint: .bottom)

    /// Warm translucent fill for content cards / tiles, over the dark background.
    static let cardFill = LinearGradient(
        colors: [Color.desertSand.opacity(0.45), Color.vividTangerine.opacity(0.30)],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Shared UI

extension View {
    /// Rounded warm "card" background used across the app's screens.
    func warmCard(cornerRadius: CGFloat = 20) -> some View {
        background(Gradient.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Consistent styling for header action icons (back arrow, +, trash) so the
    /// leading and trailing buttons match across every screen.
    func headerIcon() -> some View {
        font(.system(size: 22, weight: .semibold))
    }

    /// Lets the user dismiss the keyboard by tapping anywhere that doesn't
    /// already handle the tap (buttons and text fields keep their priority).
    func tapToDismissKeyboard() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

/// Standard screen header from the style guide: a back arrow, a large
/// left-aligned title, and an optional trailing action (e.g. + or Save).
struct NavHeader<Trailing: View>: View {
    private let title: String
    private let trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left").headerIcon()
                }
                .accessibilityLabel("Back")
                Spacer()
                trailing
            }
            Text(title)
                .font(.custom("Montserrat-SemiBold", size: 34))
        }
        .foregroundStyle(.white)
        .tint(.white)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
