//
//  MessagesModels.swift
//  RentalApp (RentOS)
//
//  Messages — Models, mock threads, and the shared observable store.
//  The store simulates the live side of messaging (typing, replies,
//  read receipts) until a real-time backend plugs in.
//

import SwiftUI
import Observation

// MARK: - Models

enum ChatRole: String {
    case tenant = "Tenant"
    case vendor = "Vendor"

    var kind: DSStatusKind {
        switch self {
        case .tenant: .info
        case .vendor: .warning
        }
    }
}

struct Conversation: Identifiable, Sendable {
    let id: String
    let name: String
    let role: ChatRole
    let context: String // property/unit or company
    var lastMessage: String
    var lastTime: String
    var unreadCount: Int
    let isOnline: Bool
    let isPinned: Bool
}

enum ChatAttachment: Hashable {
    case photo(paletteIndex: Int)
    case document(name: String, size: String)
}

enum MessageStatus {
    case sending
    case sent
    case read
}

struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let isMine: Bool
    let time: String
    var status: MessageStatus = .read
    var attachment: ChatAttachment? = nil
    var showsDateSeparator: String? = nil
}

// MARK: - Mock Data

enum MessagesMockData {

    static let conversations: [Conversation] = [
        Conversation(
            id: "sarah-chen", name: "Sarah Chen", role: .tenant,
            context: "Unit 304 · Maple Duplex",
            lastMessage: "It's getting worse — the bucket filled twice…",
            lastTime: "18m", unreadCount: 2, isOnline: true, isPinned: true
        ),
        Conversation(
            id: "mike-torres", name: "Mike Torres", role: .vendor,
            context: "Rapid Plumbing Co.",
            lastMessage: "I can be there today between 2–4 PM.",
            lastTime: "32m", unreadCount: 1, isOnline: true, isPinned: true
        ),
        Conversation(
            id: "marcus-johnson", name: "Marcus Johnson", role: .tenant,
            context: "Unit 102 · Queen West Lofts",
            lastMessage: "Thursday works, I'll be home all morning.",
            lastTime: "22h", unreadCount: 0, isOnline: false, isPinned: false
        ),
        Conversation(
            id: "isabella-rossi", name: "Isabella Rossi", role: .tenant,
            context: "Suite 2204 · Harbourfront",
            lastMessage: "The GFCI reset worked — outlet is back!",
            lastTime: "1d", unreadCount: 0, isOnline: true, isPinned: false
        ),
        Conversation(
            id: "dana-wells", name: "Dana Wells", role: .vendor,
            context: "Volt Electric",
            lastMessage: "Friday AM confirmed for the hallway fixture.",
            lastTime: "2d", unreadCount: 0, isOnline: false, isPinned: false
        ),
        Conversation(
            id: "priya-patel", name: "Priya Patel", role: .tenant,
            context: "Unit 201 · Danforth Triplex",
            lastMessage: "Renewal docs received — reviewing this week.",
            lastTime: "3d", unreadCount: 0, isOnline: false, isPinned: false
        )
    ]

    static let threads: [String: [ChatMessage]] = [
        "sarah-chen": [
            ChatMessage(
                text: "Hi! There's water pooling under my kitchen sink 😰",
                isMine: false, time: "9:41 AM", showsDateSeparator: "Today"
            ),
            ChatMessage(
                text: "", isMine: false, time: "9:42 AM",
                attachment: .photo(paletteIndex: 1)
            ),
            ChatMessage(
                text: "Thanks for the photos, Sarah. Can you turn the small valve under the sink clockwise? That stops the flow.",
                isMine: true, time: "9:47 AM"
            ),
            ChatMessage(
                text: "Done! It slowed down a lot but still drips.",
                isMine: false, time: "9:52 AM"
            ),
            ChatMessage(
                text: "A plumber is booked for today — I'll confirm the window within the hour.",
                isMine: true, time: "9:55 AM"
            ),
            ChatMessage(
                text: "It's getting worse — the bucket filled twice since this morning.",
                isMine: false, time: "10:22 AM"
            )
        ],
        "mike-torres": [
            ChatMessage(
                text: "Mike — urgent one at Maple Duplex, Unit 304. Kitchen supply line leak, tenant has shut the valve.",
                isMine: true, time: "10:25 AM", showsDateSeparator: "Today"
            ),
            ChatMessage(
                text: "", isMine: true, time: "10:25 AM",
                attachment: .document(name: "Unit304_WorkOrder.pdf", size: "180 KB")
            ),
            ChatMessage(
                text: "I can be there today between 2–4 PM.",
                isMine: false, time: "10:31 AM"
            )
        ],
        "marcus-johnson": [
            ChatMessage(
                text: "Hi Marcus — the dishwasher part arrived. Does Thursday 9 AM work for the tech visit?",
                isMine: true, time: "Tue 3:02 PM", showsDateSeparator: "Tuesday"
            ),
            ChatMessage(
                text: "Thursday works, I'll be home all morning.",
                isMine: false, time: "Tue 3:40 PM"
            )
        ],
        "isabella-rossi": [
            ChatMessage(
                text: "Quick thing to try: press 'reset' on the bathroom outlet — it sometimes controls the bedroom circuit.",
                isMine: true, time: "Sun 6:10 PM", showsDateSeparator: "Sunday"
            ),
            ChatMessage(
                text: "The GFCI reset worked — outlet is back!",
                isMine: false, time: "Sun 6:26 PM"
            )
        ],
        "dana-wells": [
            ChatMessage(
                text: "Friday AM confirmed for the hallway fixture.",
                isMine: false, time: "Wed 11:05 AM", showsDateSeparator: "Wednesday"
            )
        ],
        "priya-patel": [
            ChatMessage(
                text: "Hi Priya — your renewal package is ready. Sent to your email with the updated terms we discussed.",
                isMine: true, time: "Mon 2:15 PM", showsDateSeparator: "Monday"
            ),
            ChatMessage(
                text: "Renewal docs received — reviewing this week.",
                isMine: false, time: "Mon 5:48 PM"
            )
        ]
    ]
}
