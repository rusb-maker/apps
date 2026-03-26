import SwiftUI
import SwiftData

struct TrashView: View {
    @Query(filter: #Predicate<CardGroup> { $0.isTrashed }, sort: \CardGroup.trashedAt, order: .reverse) private var allTrashedGroups: [CardGroup]
    @Query(filter: #Predicate<Card> { $0.isTrashed }, sort: \Card.trashedAt, order: .reverse) private var allTrashedCards: [Card]
    @Query(filter: #Predicate<RecordingSession> { $0.isTrashed }, sort: \RecordingSession.trashedAt, order: .reverse) private var allTrashedRecordings: [RecordingSession]
    @Environment(\.modelContext) private var context
    @State private var showEmptyTrashConfirm = false
    @State private var showDeleteConfirm = false
    @State private var itemToDelete: TrashItemRef?

    /// Top-level trashed folders (whose parent is not itself trashed)
    private var trashedFolders: [CardGroup] {
        allTrashedGroups.filter { $0.parent == nil || !($0.parent?.isTrashed ?? false) }
    }

    /// Cards that were individually trashed (not part of a trashed folder)
    private var trashedCards: [Card] {
        allTrashedCards.filter { !($0.group?.isTrashed ?? false) }
    }

    private var isEmpty: Bool {
        trashedFolders.isEmpty && trashedCards.isEmpty && allTrashedRecordings.isEmpty
    }

    private var totalCount: Int {
        trashedFolders.count + trashedCards.count + allTrashedRecordings.count
    }

    var body: some View {
        List {
            if isEmpty {
                ContentUnavailableView(
                    "Trash is Empty",
                    systemImage: "trash",
                    description: Text("Deleted items will appear here for 7 days before being permanently removed.")
                )
            }

            if !trashedFolders.isEmpty {
                Section("Folders") {
                    ForEach(trashedFolders) { folder in
                        TrashFolderRow(folder: folder)
                            .swipeActions(edge: .leading) {
                                Button {
                                    folder.restoreFromTrash()
                                    try? context.save()
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    itemToDelete = .folder(folder)
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash.slash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    folder.restoreFromTrash()
                                    try? context.save()
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                Button(role: .destructive) {
                                    itemToDelete = .folder(folder)
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete Permanently", systemImage: "trash.slash")
                                }
                            }
                    }
                }
            }

            if !trashedCards.isEmpty {
                Section("Cards") {
                    ForEach(trashedCards) { card in
                        TrashCardRow(card: card)
                            .swipeActions(edge: .leading) {
                                Button {
                                    card.isTrashed = false
                                    card.trashedAt = nil
                                    try? context.save()
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    itemToDelete = .card(card)
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash.slash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    card.isTrashed = false
                                    card.trashedAt = nil
                                    try? context.save()
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                Button(role: .destructive) {
                                    itemToDelete = .card(card)
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete Permanently", systemImage: "trash.slash")
                                }
                            }
                    }
                }
            }

            if !allTrashedRecordings.isEmpty {
                Section("Recordings") {
                    ForEach(allTrashedRecordings) { recording in
                        TrashRecordingRow(recording: recording)
                            .swipeActions(edge: .leading) {
                                Button {
                                    recording.isTrashed = false
                                    recording.trashedAt = nil
                                    try? context.save()
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    itemToDelete = .recording(recording)
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash.slash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    recording.isTrashed = false
                                    recording.trashedAt = nil
                                    try? context.save()
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                Button(role: .destructive) {
                                    itemToDelete = .recording(recording)
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete Permanently", systemImage: "trash.slash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Trash")
        .toolbar {
            if !isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Empty Trash") {
                        showEmptyTrashConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .alert("Empty Trash?", isPresented: $showEmptyTrashConfirm) {
            Button("Empty Trash", role: .destructive) {
                emptyTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(totalCount) items. This action cannot be undone.")
        }
        .alert("Delete Permanently?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    permanentlyDelete(item)
                    itemToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func emptyTrash() {
        for folder in trashedFolders {
            context.delete(folder)
        }
        for card in trashedCards {
            context.delete(card)
        }
        for recording in allTrashedRecordings {
            context.delete(recording)
        }
        try? context.save()
    }

    private func permanentlyDelete(_ item: TrashItemRef) {
        switch item {
        case .folder(let folder):
            context.delete(folder)
        case .card(let card):
            context.delete(card)
        case .recording(let recording):
            context.delete(recording)
        }
        try? context.save()
    }
}

// MARK: - Trash item reference for confirmation

private enum TrashItemRef {
    case folder(CardGroup)
    case card(Card)
    case recording(RecordingSession)
}

// MARK: - Row views

private struct TrashFolderRow: View {
    let folder: CardGroup

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(folder.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("\(folder.cards.count) cards")
                    if !folder.children.isEmpty {
                        Text("· \(folder.children.count) subfolders")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let trashedAt = folder.trashedAt {
                TrashTimeLabel(trashedAt: trashedAt)
            }
        }
    }
}

private struct TrashCardRow: View {
    let card: Card

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.front)
                    .font(.headline)
                if !card.back.isEmpty {
                    Text(card.back)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            Spacer()
            if let trashedAt = card.trashedAt {
                TrashTimeLabel(trashedAt: trashedAt)
            }
        }
    }
}

private struct TrashRecordingRow: View {
    let recording: RecordingSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(recording.createdAt, style: .date)
                        .font(.subheadline.weight(.medium))
                    Text(recording.createdAt, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(recording.rawTranscript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let trashedAt = recording.trashedAt {
                TrashTimeLabel(trashedAt: trashedAt)
            }
        }
    }
}

private struct TrashTimeLabel: View {
    let trashedAt: Date

    private var daysAgo: Int {
        Calendar.current.dateComponents([.day], from: trashedAt, to: Date()).day ?? 0
    }

    private var daysRemaining: Int {
        max(0, 7 - daysAgo)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if daysAgo == 0 {
                Text("Today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(daysAgo)d ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(daysRemaining)d left")
                .font(.caption2)
                .foregroundStyle(daysRemaining <= 1 ? .red : .orange)
        }
    }
}
