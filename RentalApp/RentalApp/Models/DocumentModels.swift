//
//  DocumentsModels.swift
//  RentalApp (RentOS)
//
//  Documents — Models, mock library, and the shared store with a
//  simulated upload pipeline. A DocumentService plugs in later.
//

import SwiftUI
import Observation

// MARK: - File Type

enum DocFileType: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case image = "Image"
    case spreadsheet = "Sheet"
    case contract = "Contract"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pdf: "doc.text.fill"
        case .image: "photo.fill"
        case .spreadsheet: "tablecells.fill"
        case .contract: "signature"
        }
    }

    var accent: DSAccent {
        switch self {
        case .pdf:         .coral
        case .image:       .sky
        case .spreadsheet: .mint
        case .contract:    .violet
        }
    }

    /// AA-safe foreground. Use `accent.fill` for solid chips, with
    /// `accent.onFill` text on top.
    var tint: Color { accent.ink }
}

// MARK: - Models

struct DocFolder: Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: Color
}

struct DocFile: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let type: DocFileType
    let size: String
    let date: String
    let folderID: String
    var tags: [String]
    let paletteIndex: Int
    var isFavorite: Bool = false
}

struct DocUpload: Identifiable {
    let id = UUID()
    let name: String
    let type: DocFileType
    var progress: Double = 0
}

// MARK: - Mock Data

enum DocumentsMockData {

    static let files: [DocFile] = [
        DocFile(name: "Lease — Sarah Chen · Unit 304", type: .contract, size: "1.1 MB",
                date: "Aug 2025", folderID: "leases", tags: ["Signed", "Maple Duplex"], paletteIndex: 0),
        DocFile(name: "Q2 Portfolio Financials", type: .spreadsheet, size: "840 KB",
                date: "Jul 2026", folderID: "financials", tags: ["2026", "Tax"], paletteIndex: 3, isFavorite: true),
        DocFile(name: "Building Insurance Certificate", type: .pdf, size: "480 KB",
                date: "Jan 2026", folderID: "insurance", tags: ["2026"], paletteIndex: 1),
        DocFile(name: "Unit 304 — Leak Photos", type: .image, size: "4.2 MB",
                date: "Today", folderID: "photos", tags: ["Urgent", "Maple Duplex"], paletteIndex: 1),
        DocFile(name: "Lease — Marcus Johnson · Unit 102", type: .contract, size: "1.0 MB",
                date: "Sep 2025", folderID: "leases", tags: ["Signed", "Queen West"], paletteIndex: 5),
        DocFile(name: "Property Tax Statement 2026", type: .pdf, size: "220 KB",
                date: "Jun 2026", folderID: "financials", tags: ["2026", "Tax"], paletteIndex: 2, isFavorite: true),
        DocFile(name: "Annual Inspection — Danforth", type: .pdf, size: "1.6 MB",
                date: "May 2026", folderID: "inspections", tags: ["2026"], paletteIndex: 2),
        DocFile(name: "Move-in Photos — Suite 2204", type: .image, size: "6.8 MB",
                date: "Jun 2026", folderID: "photos", tags: [], paletteIndex: 3),
        DocFile(name: "Rent Roll — July 2026", type: .spreadsheet, size: "310 KB",
                date: "Jul 2026", folderID: "financials", tags: ["2026"], paletteIndex: 4),
        DocFile(name: "Renewal Draft — Priya Patel", type: .contract, size: "980 KB",
                date: "2d ago", folderID: "leases", tags: ["Urgent"], paletteIndex: 4)
    ]
}
