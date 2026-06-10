//
//  Extensions.swift
//  Unwind
//
//  Created by Leah Cluff on 4/10/23.
//

import SwiftUI
import CoreHaptics

extension Color {
    static let jaguar = Color("Jaguar")
    static let midnight = Color("Midnight")
    static let sherpaBlue = Color("SherpaBlue")
    static let blueLagoon = Color("BlueLagoon")
    static let halfBaked = Color("HalfBaked")
    static let vividTangerine = Color("VividTangerine")
    static let desertSand = Color("DesertSand")
}


extension Gradient {
   static let blueGradient =  LinearGradient(colors: [Color.jaguar, Color.midnight, Color.sherpaBlue, Color.blueLagoon], startPoint: .top, endPoint: .bottom)
    
    static let pinkGradient = LinearGradient(colors: [Color.vividTangerine, Color.desertSand, Color.white], startPoint: .top, endPoint: .bottom)
    
    static let launchGradient = LinearGradient(colors: [Color.midnight, Color.sherpaBlue, Color.vividTangerine, Color.desertSand], startPoint: .top, endPoint: .bottom)
    
 
}

enum SetUIViewDefaults {
    
    case statusDetaultBarStyle
    case setDefaultBackground
    case setDefaultfont
    case errorSettingUIDefaults(Error)
    case ignoresSafeEdges
    //this is where I make it so the gradient ignores safe edges
   
    
    var defaultViewSettings: String {
        switch self {
        case.statusDetaultBarStyle: return "\(UIStatusBarStyle.darkContent)"
        case.setDefaultBackground: return "ForegroundStyle(Gradient.blueGradient)"
        case.setDefaultfont: return "FontVariation(name: Montserrat-Medium, value: 35)"
        case.errorSettingUIDefaults: return "there was an error setting up the view defaults"
        case.ignoresSafeEdges: return ""
        }
        
    }
}

//I would like to make this a function that I can call. it would be trigger animation. and it would be




enum ErrorState: Error {
    
    case errorLoadingData
    case errorSaving
    case errorReset
    case errorName
    
    var errorLable: String {
        switch self {
            
        case .errorSaving: return "There was an error saving data"
        case.errorReset: return "There was an error resetting data"
        case .errorName: return "there was an error loading title"
        case .errorLoadingData: return "there was an error loading data"

        }
    }
}


// MARK: - Shared UI (style guide)

extension Gradient {
    /// Warm translucent fill for content cards / tiles — the peachy "Delicate"
    /// look from the style guide, sitting over the dark blue background.
    static let cardFill = LinearGradient(
        colors: [Color.desertSand.opacity(0.45), Color.vividTangerine.opacity(0.30)],
        startPoint: .top, endPoint: .bottom)
}

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
                    Image(systemName: "arrow.left")
                        .headerIcon()
                }
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
