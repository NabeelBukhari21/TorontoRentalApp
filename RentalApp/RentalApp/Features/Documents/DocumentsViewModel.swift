//
//  DocumentsViewModel.swift
//  RentalApp (Purrperty)
//
//  Documents — Document center view model.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class DocumentsViewModel {

    private let repository: DocumentRepositoryProtocol

    var searchText = "" {
        didSet { guard oldValue != searchText else { return }; scheduleReload(debounced: true) }
    }
    var selectedFolderID: String? {
        didSet { guard oldValue != selectedFolderID else { return }; scheduleReload() }
    }
    var typeFilter: DocFileType? {
        didSet { guard oldValue != typeFilter else { return }; scheduleReload() }
    }
    var selectedTags: Set<String> = [] {
        didSet { guard oldValue != selectedTags else { return }; scheduleReload() }
    }

    var isGrid = true
    var isDropTargeted = false
    var previewFile: DocFile?

    private(set) var list: AsyncListModel<DocFile>!
    private(set) var folders: [DocFolder] = []
    private(set) var allTags: [String] = []
    private(set) var folderCounts: [String: Int] = [:]

    private var reloadTask: Task<Void, Never>?

    init(repository: DocumentRepositoryProtocol) {
        self.repository = repository

        self.list = AsyncListModel<DocFile>(pageSize: 30) { [weak self] page, forceRefresh in
            guard let self else { return .empty }
            let query = DocumentQuery(
                search: self.searchText,
                filter: DocumentFilter(
                    folderID: self.selectedFolderID,
                    type: self.typeFilter,
                    tags: self.selectedTags
                ),
                sort: SortOrder(.date, .descending),
                page: page
            )
            return try await self.repository.files(matching: query, forceRefresh: forceRefresh)
        }
    }

    var files: [DocFile] { list.items }
    var filteredFiles: [DocFile] { list.items }
    var uploads: [DocUpload] { repository.uploads }

    var isLoading: Bool { list.state.isLoading }
    var isRefreshing: Bool { list.isRefreshing }
    var error: AppError? { list.error }
    var isEmpty: Bool { list.isEmpty }

    func fileCount(in folderID: String) -> Int { folderCounts[folderID] ?? 0 }

    /// Every file, not just the page loaded so far. Each file is in
    /// exactly one folder, so the folder counts add up to it.
    var totalFileCount: Int { max(folderCounts.values.reduce(0, +), files.count) }

    func load() async {
        folders = (try? await repository.folders()) ?? []
        allTags = (try? await repository.tags()) ?? []
        await list.load()
        await refreshCounts()
    }

    func refresh() async {
        await list.refresh()
        await refreshCounts()
    }

    func retry() async { await list.retry() }

    func loadMoreIfNeeded(currentItem item: DocFile) async {
        await list.loadMoreIfNeeded(currentItem: item)
    }

    func toggleFavorite(_ id: UUID) async {
        try? await repository.toggleFavorite(id)
        await list.reload()
    }

    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    /// Stands in for the system file importer.
    func importSampleFile() async {
        let samples: [(String, DocFileType, String)] = [
            ("Signed Lease — Unit 118.pdf", .contract, "leases"),
            ("August Rent Roll.xlsx", .spreadsheet, "financials"),
            ("Boiler Inspection Report.pdf", .pdf, "inspections"),
            ("Balcony Repair Photos.zip", .image, "photos")
        ]
        let pick = samples[(files.count + uploads.count) % samples.count]
        try? await repository.upload(named: pick.0, type: pick.1, folderID: pick.2)
        await list.reload()
        await refreshCounts()
    }

    private func refreshCounts() async {
        var counts: [String: Int] = [:]
        for folder in folders {
            counts[folder.id] = (try? await repository.fileCount(inFolderID: folder.id)) ?? 0
        }
        folderCounts = counts
    }

    private func scheduleReload(debounced: Bool = false) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            if debounced {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            await self?.list.reload()
        }
    }
}
