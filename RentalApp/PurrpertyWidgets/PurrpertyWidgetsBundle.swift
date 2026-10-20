//
//  PurrpertyWidgetsBundle.swift
//  PurrpertyWidgets
//
//  Everything the extension provides: the Rent and Repairs widgets, and
//  the repair-visit Live Activity.
//

import WidgetKit
import SwiftUI

@main
struct PurrpertyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RentWidget()
        RepairsWidget()
        RepairVisitLiveActivity()
    }
}
