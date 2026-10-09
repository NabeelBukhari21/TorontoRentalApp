//
//  DocumentCenterView.swift
//  RentalApp (RentOS)
//
//  Documents — The document center: drop zone with live uploads,
//  folders, search, type filters, tags, and animated grid ⇄ list
//  layouts with a PDF preview sheet.
//

import SwiftUI

struct DocumentCenterView: View {

    @Environment(\.container) private var container
    @State private var viewModel: DocumentsViewModel

    init(container: AppContainer = .shared) {
        _viewModel = State(initialValue: DocumentsViewModel(repository: container.documents))
    }

    @Namespace private var layoutNamespace
    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    // MARK: Body

    var body: some View {
        ZStack {
            DSAmbientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {

                    // Drop zone.
                    DocDropZone(isTargeted: viewModel.isDropTargeted) {
                        Task { await viewModel.importSampleFile() }
                    }
                    .dropDestination(for: Data.self) { _, _ in
                        Task { await viewModel.importSampleFile() }
                        return true
                    } isTargeted: { targeted in
                        withAnimation(DS.Motion.bouncy) {
                            viewModel.isDropTargeted = targeted
                        }
                    }
                    .dsEntrance(index: 0)

                    // Active uploads.
                    if !viewModel.uploads.isEmpty {
                        VStack(spacing: DS.Spacing.sm) {
                            ForEach(viewModel.uploads) { upload in
                                DocUploadRow(upload: upload)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Folders.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(Array(viewModel.folders.enumerated()), id: \.element.id) { index, folder in
                                DocFolderCard(
                                    folder: folder,
                                    count: viewModel.fileCount(in: folder.id),
                                    isSelected: viewModel.selectedFolderID == folder.id
                                ) {
                                    withAnimation(DS.Motion.smooth) {
                                        viewModel.selectedFolderID = viewModel.selectedFolderID == folder.id ? nil : folder.id
                                    }
                                }
                                .dsEntrance(index: 1 + index)
                            }
                        }
                        .padding(.horizontal, 1)
                        .padding(.vertical, 3)
                    }

                    // Search + layout toggle.
                    HStack(spacing: DS.Spacing.md) {
                        DSSearchBar(text: $viewModel.searchText, placeholder: "Search files, tags…")

                        layoutToggle
                    }
                    .dsEntrance(index: 6)

                    // Type filter chips.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            DSChip(title: "All", isSelected: viewModel.typeFilter == nil) {
                                withAnimation(DS.Motion.smooth) { viewModel.typeFilter = nil }
                            }
                            ForEach(DocFileType.allCases) { type in
                                DSChip(
                                    title: type.rawValue,
                                    icon: type.icon,
                                    isSelected: viewModel.typeFilter == type
                                ) {
                                    withAnimation(DS.Motion.smooth) {
                                        viewModel.typeFilter = viewModel.typeFilter == type ? nil : type
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .dsEntrance(index: 7)

                    // Tag chips.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(viewModel.allTags, id: \.self) { tag in
                                DocTagChip(tag: tag, isSelected: viewModel.selectedTags.contains(tag)) {
                                    withAnimation(DS.Motion.smooth) {
                                        viewModel.toggleTag(tag)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .dsEntrance(index: 8)

                    // Files.
                    filesContent
                }
                .padding(DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.huge)
                .animation(DS.Motion.smooth, value: viewModel.filteredFiles.map(\.id))
                .animation(DS.Motion.smooth, value: viewModel.uploads.map(\.id))
            }
        }
        .dsHeader(
            title: "Documents",
            subtitle: "\(viewModel.files.count) files · \(viewModel.folders.count) folders",
            showsBack: true,
            trailingActions: [
                DSHeaderAction(icon: "square.and.arrow.up") {
                    Task { await viewModel.importSampleFile() }
                }
            ]
        )
        .task { await viewModel.load() }
        .liveUpdates(container.sync) {
            LiveList.reloadSubscription(topic: .documents) {
                await viewModel.refresh()
            }
        }
        .refreshable { await viewModel.refresh() }
        .sheet(item: $viewModel.previewFile) { file in
            DocPreviewSheet(file: file)
                .presentationDetents([.large])
                .presentationCornerRadius(DS.Radius.xxl)
                .presentationDragIndicator(.hidden)
                .presentationBackground(DS.Colors.surfaceRaised)
        }
    }

    // MARK: Layout Toggle

    private var layoutToggle: some View {
        HStack(spacing: 2) {
            toggleButton(icon: "square.grid.2x2.fill", active: viewModel.isGrid) {
                withAnimation(DS.Motion.smooth) { viewModel.isGrid = true }
            }
            toggleButton(icon: "list.bullet", active: !viewModel.isGrid) {
                withAnimation(DS.Motion.smooth) { viewModel.isGrid = false }
            }
        }
        .padding(3)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.outline, lineWidth: 1)
        )
    }

    private func toggleButton(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? DS.Colors.textOnBrand : DS.Colors.textSecondary)
                .frame(width: 40, height: 38)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(DS.Gradients.brand)
                            .matchedGeometryEffect(id: "doc.layout.pill", in: layoutNamespace)
                    }
                }
        }
        .buttonStyle(DSPressStyle(scale: 0.92))
    }

    // MARK: Files Content

    @ViewBuilder
    private var filesContent: some View {
        if viewModel.isLoading {
            DSCardSkeleton(cards: 3)
        } else if let error = viewModel.error {
            DSErrorView(error: error) { await viewModel.retry() }
        } else if viewModel.isEmpty {
            DSEmptyState(
                icon: DS.Icons.documents,
                title: "No documents found",
                message: "Adjust your search or filters, or upload your first file.",
                actionTitle: "Upload",
                action: { Task { await viewModel.importSampleFile() } }
            )
            .padding(.top, DS.Spacing.xl)
        } else if viewModel.isGrid {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
                ForEach(Array(viewModel.filteredFiles.enumerated()), id: \.element.id) { index, file in
                    DocFileGridCard(
                        file: file,
                        onOpen: { viewModel.previewFile = file },
                        onFavorite: { Task { await viewModel.toggleFavorite(file.id) } }
                    )
                    .matchedGeometryEffect(id: file.id, in: layoutNamespace)
                    .dsEntrance(index: min(9 + index, 16))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        } else {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(Array(viewModel.filteredFiles.enumerated()), id: \.element.id) { index, file in
                    DocFileListRow(
                        file: file,
                        onOpen: { viewModel.previewFile = file },
                        onFavorite: { Task { await viewModel.toggleFavorite(file.id) } }
                    )
                    .matchedGeometryEffect(id: file.id, in: layoutNamespace)
                    .dsEntrance(index: min(9 + index, 16))
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
    }

}

// MARK: - Previews

#Preview("Document Center") {
    NavigationStack {
        DocumentCenterView()
    }
    .environment(AppRouter())
}
