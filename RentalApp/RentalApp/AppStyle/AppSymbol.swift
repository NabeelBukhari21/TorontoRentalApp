//
//  AppSymbol.swift
//  RentalApp (Purrperty)
//
//  AppStyle — SF Symbols for the app's domain concepts.
//
//  One name per concept, so "properties" is the same building in the tab
//  bar, a list row, a widget and a Siri snippet. Generic actions (share,
//  delete, edit) use these too, so a symbol never drifts between screens.
//
//  Every name was checked against the system symbol set. Rendering mode
//  and effects are chosen at the call site, where the meaning is known.
//

import SwiftUI

enum AppSymbol: String, CaseIterable, Sendable {

    // MARK: Sections
    case home = "house"
    case properties = "building.2"
    case tenants = "person.2"
    case maintenance = "wrench.and.screwdriver"
    case messages = "bubble.left.and.bubble.right"
    case assistant = "sparkles"
    case documents = "doc.text"
    case notifications = "bell"
    case settings = "gearshape"
    case search = "magnifyingglass"

    // MARK: Domain
    case rent = "dollarsign.circle"
    case lease = "signature"
    case unit = "door.left.hand.closed"
    case vendor = "hammer"
    case occupancy = "chart.pie"
    case revenue = "chart.line.uptrend.xyaxis"
    case payment = "creditcard"
    case folder = "folder"
    case address = "mappin.and.ellipse"
    case calendar = "calendar"
    case phone = "phone"
    case email = "envelope"
    case person = "person.crop.circle"
    case invite = "person.badge.plus"
    case house = "house.fill"
    case condo = "building.fill"
    case commercial = "storefront.fill"
    case owner = "key.fill"
    case schedule = "clock"
    case inbox = "tray"

    // MARK: Actions
    case add = "plus"
    case edit = "pencil"
    case delete = "trash"
    case archive = "archivebox"
    case share = "square.and.arrow.up"
    case filter = "line.3.horizontal.decrease"
    case sort = "arrow.up.arrow.down"
    case more = "ellipsis.circle"
    case refresh = "arrow.clockwise"
    case send = "arrow.up"
    case attach = "paperclip"
    case photo = "photo"
    case camera = "camera"
    case done = "checkmark"
    case close = "xmark"
    case help = "questionmark.circle"
    case listLayout = "list.bullet.rectangle"
    case gridLayout = "square.grid.2x2"

    // MARK: State
    case positive = "checkmark.circle.fill"
    case caution = "exclamationmark.triangle.fill"
    case critical = "exclamationmark.octagon.fill"
    case informational = "info.circle.fill"
    case neutral = "circle.fill"
    case urgent = "bolt.fill"
    case offline = "wifi.slash"
    case locked = "lock.fill"
    case faceID = "faceid"

    // MARK: Appearance
    case light = "sun.max"
    case dark = "moon"
    case system = "circle.lefthalf.filled"
}

// MARK: - Conveniences

extension Image {
    init(symbol: AppSymbol) {
        self.init(systemName: symbol.rawValue)
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringKey, symbol: AppSymbol) {
        self.init(title, systemImage: symbol.rawValue)
    }

    init<S: StringProtocol>(_ title: S, symbol: AppSymbol) {
        self.init(title, systemImage: symbol.rawValue)
    }
}
