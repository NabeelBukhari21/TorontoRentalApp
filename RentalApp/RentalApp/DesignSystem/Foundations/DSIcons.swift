//
//  DSIcons.swift
//  RentalApp
//
//  Design System — SF Symbol names used across the app.
//  Centralized so icons stay consistent between screens.
//

import SwiftUI

extension DS {

    enum Icons {

        // MARK: Navigation
        static let dashboard = "square.grid.2x2.fill"
        static let properties = "building.2.fill"
        static let maintenance = "wrench.and.screwdriver.fill"
        static let messages = "bubble.left.and.bubble.right.fill"
        static let documents = "doc.fill"
        static let reports = "chart.bar.xaxis"
        static let notifications = "bell.fill"
        static let settings = "gearshape.fill"

        // MARK: Domain
        static let unit = "door.left.hand.closed"
        static let tenant = "person.fill"
        static let tenants = "person.2.fill"
        static let vendor = "hammer.fill"
        static let lease = "doc.text.fill"
        static let payment = "creditcard.fill"
        static let occupancy = "chart.pie.fill"

        // MARK: AI
        static let ai = "sparkles"
        static let aiAssistant = "wand.and.stars"

        // MARK: Actions
        static let add = "plus"
        static let search = "magnifyingglass"
        static let filter = "line.3.horizontal.decrease"
        static let sort = "arrow.up.arrow.down"
        static let more = "ellipsis"
        static let close = "xmark"
        static let chevronRight = "chevron.right"
        static let camera = "camera.fill"
        static let attachment = "paperclip"
        static let send = "arrow.up.circle.fill"

        // MARK: Status
        static let success = "checkmark.circle.fill"
        static let warning = "exclamationmark.triangle.fill"
        static let danger = "exclamationmark.octagon.fill"
        static let info = "info.circle.fill"
        static let clock = "clock.fill"
    }
}
