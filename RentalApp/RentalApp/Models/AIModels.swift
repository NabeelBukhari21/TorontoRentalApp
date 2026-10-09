//
//  AIModels.swift
//  RentalApp (RentOS)
//
//  Models — Copilot domain types.
//

import Foundation

struct AIRecommendedAction: Identifiable {
    enum State {
        case pending
        case accepted
    }

    let id = UUID()
    let icon: String
    let kind: DSStatusKind
    let title: String
    let detail: String
    let impact: String
    let acceptedLabel: String
    var state: State = .pending
}

struct AIInsightRow: Identifiable {
    let id = UUID()
    let icon: String
    let kind: DSStatusKind
    let text: String
}

struct AIHealthFactor: Identifiable {
    let id = UUID()
    let name: String
    let score: Double // 0...1
    let kind: DSStatusKind
}

struct AIActivityEntry: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let time: String
}

struct AIQuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let logText: String
}
