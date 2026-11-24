//
//  PartnerLogos.swift
//  RentalApp (Purrperty)
//
//  Components/Brand — The sign-in partners' own marks: Google's four-colour
//  G and Apple's logo. Never tinted to our palette.
//

import SwiftUI

/// Google's four-colour G.
struct GoogleLogo: View {
    var size: CGFloat = 20

    var body: some View {
        Image("GoogleG")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Apple's logo: black in light mode, white in dark, as Apple ships it.
struct AppleLogo: View {
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: "apple.logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(DS.Colors.Partner.appleMark)
            .accessibilityHidden(true)
    }
}
