// VibeCaaS Brand Colors
// Official branding from VibeCaaS.com parent company
// Use these colors for consistent branding across all Craig-O-Clean UI

import SwiftUI

extension Color {
    // MARK: - VibeCaaS Brand Colors

    /// VibeCaaS Primary - Vibe Purple (#6D4AFF)
    static let vibePurple = Color(red: 109/255, green: 74/255, blue: 255/255)

    /// VibeCaaS Secondary - Aqua Teal (#14B8A6)
    static let vibeTeal = Color(red: 20/255, green: 184/255, blue: 166/255)

    /// VibeCaaS Accent - Signal Amber (#FF8C00)
    static let vibeAmber = Color(red: 255/255, green: 140/255, blue: 0/255)

    // MARK: - VibeCaaS Purple Scale

    static let vibePurple50 = Color(red: 243/255, green: 240/255, blue: 255/255)
    static let vibePurple100 = Color(red: 233/255, green: 227/255, blue: 255/255)
    static let vibePurple200 = Color(red: 211/255, green: 199/255, blue: 255/255)
    static let vibePurple300 = Color(red: 182/255, green: 164/255, blue: 255/255)
    static let vibePurple400 = Color(red: 150/255, green: 122/255, blue: 255/255)
    static let vibePurple500 = Color(red: 109/255, green: 74/255, blue: 255/255)  // Primary
    static let vibePurple600 = Color(red: 92/255, green: 62/255, blue: 224/255)
    static let vibePurple700 = Color(red: 77/255, green: 52/255, blue: 191/255)
    static let vibePurple800 = Color(red: 59/255, green: 36/255, blue: 147/255)
    static let vibePurple900 = Color(red: 41/255, green: 24/255, blue: 108/255)

    // MARK: - VibeCaaS Teal Scale

    static let vibeTeal50 = Color(red: 229/255, green: 250/255, blue: 246/255)
    static let vibeTeal100 = Color(red: 191/255, green: 245/255, blue: 236/255)
    static let vibeTeal200 = Color(red: 152/255, green: 238/255, blue: 226/255)
    static let vibeTeal300 = Color(red: 112/255, green: 226/255, blue: 213/255)
    static let vibeTeal400 = Color(red: 74/255, green: 213/255, blue: 198/255)
    static let vibeTeal500 = Color(red: 20/255, green: 184/255, blue: 166/255)  // Secondary
    static let vibeTeal600 = Color(red: 17/255, green: 148/255, blue: 134/255)
    static let vibeTeal700 = Color(red: 13/255, green: 116/255, blue: 106/255)
    static let vibeTeal800 = Color(red: 10/255, green: 90/255, blue: 82/255)
    static let vibeTeal900 = Color(red: 7/255, green: 64/255, blue: 58/255)

    // MARK: - VibeCaaS Amber Scale

    static let vibeAmber50 = Color(red: 255/255, green: 244/255, blue: 230/255)
    static let vibeAmber100 = Color(red: 255/255, green: 231/255, blue: 204/255)
    static let vibeAmber200 = Color(red: 255/255, green: 210/255, blue: 153/255)
    static let vibeAmber300 = Color(red: 255/255, green: 187/255, blue: 102/255)
    static let vibeAmber400 = Color(red: 255/255, green: 164/255, blue: 51/255)
    static let vibeAmber500 = Color(red: 255/255, green: 140/255, blue: 0/255)  // Accent
    static let vibeAmber600 = Color(red: 217/255, green: 119/255, blue: 0/255)
    static let vibeAmber700 = Color(red: 179/255, green: 97/255, blue: 0/255)
    static let vibeAmber800 = Color(red: 140/255, green: 76/255, blue: 0/255)
    static let vibeAmber900 = Color(red: 102/255, green: 55/255, blue: 0/255)

    // MARK: - Gradient Utilities

    /// VibeCaaS brand gradient (Purple to Teal)
    static var vibeBrandGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [vibePurple, vibeTeal]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// VibeCaaS hero gradient (Purple to Amber)
    static var vibeHeroGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [vibePurple, vibeAmber]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Usage Examples
/*
 Example usage in SwiftUI views:

 // Single colors
 Text("VibeCaaS")
     .foregroundColor(.vibePurple)

 // Gradient backgrounds
 Rectangle()
     .fill(Color.vibeBrandGradient)

 // Scaled colors for different states
 Button("Action") { }
     .foregroundColor(.vibePurple500)
     .background(Color.vibePurple50)
 */
