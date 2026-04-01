import SwiftUI
import SwiftData

struct FolderListView: View {
    var parentFolder: CardFolder? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var language

    @State private var childFolders: [CardFolder] = []
    @State private var cards: [Card] = []
    @State private var showingNewFolder = false
    @State private var showingGenerate = false
    @State private var showingAddCard = false
    @State private var newFolderName = ""
    @State private var renamingFolder: CardFolder?
    @State private var renameText = ""
    @State private var studyFolder = false
    @State private var movingCard: Card?
    @State private var allFoldersForMove: [CardFolder] = []

    // Multi-select
    @State private var isSelecting = false
    @State private var selectedCardIds: Set<UUID> = []
    @State private var showingBatchMove = false
    @State private var editingCard: Card?

    private var dueCount: Int {
        let now = Date()
        return cards.filter { $0.nextReviewDate <= now }.count
    }

    var body: some View {
        List {
            if !childFolders.isEmpty {
                Section("Папки") {
                    ForEach(childFolders, id: \.id) { folder in
                        NavigationLink(value: folder.id) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.teal)
                                Text(folder.name)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteFolder(folder)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                renamingFolder = folder
                                renameText = folder.name
                            } label: {
                                Label("Переименовать", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }

            if !cards.isEmpty {
                Section {
                    if dueCount > 0 && !isSelecting {
                        Button {
                            studyFolder = true
                        } label: {
                            Label("Учить (\(dueCount))", systemImage: "brain.head.profile")
                        }
                    }

                    // Selection toolbar
                    if isSelecting && !selectedCardIds.isEmpty {
                        HStack {
                            Text("\(selectedCardIds.count) выбрано")
                                .font(.subheadline.bold())
                            Spacer()
                            Button {
                                allFoldersForMove = loadAllFolders()
                                showingBatchMove = true
                            } label: {
                                Label("Переместить", systemImage: "folder")
                                    .font(.subheadline)
                            }
                            Button(role: .destructive) {
                                deleteSelected()
                            } label: {
                                Label("Удалить", systemImage: "trash")
                                    .font(.subheadline)
                            }
                        }
                    }

                    ForEach(cards, id: \.id) { card in
                        HStack {
                            if isSelecting {
                                Image(systemName: selectedCardIds.contains(card.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCardIds.contains(card.id) ? .blue : .secondary)
                                    .onTapGesture {
                                        toggleSelection(card)
                                    }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.front).font(.body.bold())
                                Text(card.back).font(.subheadline).foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelecting {
                                toggleSelection(card)
                            } else {
                                editingCard = card
                            }
                        }
                        .contextMenu {
                            if !isSelecting {
                                Button {
                                    editingCard = card
                                } label: {
                                    Label("Редактировать", systemImage: "pencil")
                                }
                                Button {
                                    allFoldersForMove = loadAllFolders()
                                    movingCard = card
                                } label: {
                                    Label("Переместить", systemImage: "folder")
                                }
                                Button(role: .destructive) {
                                    card.isTrashed = true
                                    card.trashedAt = Date()
                                    try? modelContext.save()
                                    loadData()
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if !isSelecting {
                                Button(role: .destructive) {
                                    card.isTrashed = true
                                    card.trashedAt = Date()
                                    try? modelContext.save()
                                    loadData()
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Карточки (\(cards.count))")
                        Spacer()
                        Button(isSelecting ? "Готово" : "Выбрать") {
                            withAnimation {
                                isSelecting.toggle()
                                if !isSelecting {
                                    selectedCardIds.removeAll()
                                }
                            }
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }

            if childFolders.isEmpty && cards.isEmpty {
                ContentUnavailableView(
                    "Пусто",
                    systemImage: "folder",
                    description: Text("Добавьте папку или сгенерируйте карточки")
                )
            }
        }
        .navigationTitle(parentFolder?.name ?? "Мои карточки")
        .themed()
        .navigationDestination(for: UUID.self) { folderId in
            FolderDetailDestination(folderId: folderId)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isSelecting {
                    Button("Все") {
                        if selectedCardIds.count == cards.count {
                            selectedCardIds.removeAll()
                        } else {
                            selectedCardIds = Set(cards.map(\.id))
                        }
                    }
                } else {
                    Menu {
                        Button {
                            newFolderName = ""
                            showingNewFolder = true
                        } label: {
                            Label("Новая папка", systemImage: "folder.badge.plus")
                        }
                        Button {
                            showingAddCard = true
                        } label: {
                            Label("Новая карточка", systemImage: "plus.circle")
                        }
                        Button {
                            showingGenerate = true
                        } label: {
                            Label("Сгенерировать (AI)", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("Новая папка", isPresented: $showingNewFolder) {
            TextField("Название", text: $newFolderName)
            Button("Создать") {
                createFolder()
                loadData()
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Переименовать", isPresented: Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )) {
            TextField("Название", text: $renameText)
            Button("Сохранить") {
                renamingFolder?.name = renameText
                try? modelContext.save()
                renamingFolder = nil
            }
            Button("Отмена", role: .cancel) { renamingFolder = nil }
        }
        .sheet(isPresented: $showingAddCard, onDismiss: loadData) {
            CustomCardView(folderId: parentFolder?.id)
        }
        .sheet(isPresented: $showingGenerate, onDismiss: loadData) {
            CustomGenerationView(folderId: parentFolder?.id)
        }
        .fullScreenCover(isPresented: $studyFolder) {
            NavigationStack {
                StudySessionView(customOnly: true, folderId: parentFolder?.id)
            }
        }
        .onAppear { loadData() }
        .sheet(item: $movingCard) { card in
            MoveToFolderSheet(cards: [card], folders: allFoldersForMove) {
                loadData()
            }
        }
        .sheet(item: $editingCard) { card in
            EditCardView(card: card) { loadData() }
        }
        .sheet(isPresented: $showingBatchMove) {
            let selected = cards.filter { selectedCardIds.contains($0.id) }
            MoveToFolderSheet(cards: selected, folders: allFoldersForMove) {
                selectedCardIds.removeAll()
                isSelecting = false
                loadData()
            }
        }
    }

    // MARK: - Selection

    private func toggleSelection(_ card: Card) {
        if selectedCardIds.contains(card.id) {
            selectedCardIds.remove(card.id)
        } else {
            selectedCardIds.insert(card.id)
        }
    }

    private func deleteSelected() {
        for card in cards where selectedCardIds.contains(card.id) {
            card.isTrashed = true
            card.trashedAt = Date()
        }
        try? modelContext.save()
        selectedCardIds.removeAll()
        isSelecting = false
        loadData()
    }

    // MARK: - Data

    private func loadData() {
        let parentId = parentFolder?.id
        let folderDescriptor = FetchDescriptor<CardFolder>(
            sortBy: [SortDescriptor(\.name)]
        )
        let allFolders = (try? modelContext.fetch(folderDescriptor)) ?? []
        childFolders = allFolders.filter { $0.parent?.id == parentId }

        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.graduated && !$0.isTrashed },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let customId = Card.customId(for: language)
        let allCustom = (try? modelContext.fetch(descriptor)) ?? []
        cards = allCustom.filter {
            ($0.lessonId == customId || (language == .spanish && $0.lessonId == Card.customLessonId))
            && $0.folderId == parentId
        }
    }

    private func loadAllFolders() -> [CardFolder] {
        let descriptor = FetchDescriptor<CardFolder>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let folder = CardFolder(name: newFolderName.trimmingCharacters(in: .whitespaces), parent: parentFolder)
        modelContext.insert(folder)
        try? modelContext.save()
    }

    private func deleteFolder(_ folder: CardFolder) {
        let fid = folder.id
        for card in cards where card.folderId == fid {
            card.isTrashed = true
            card.trashedAt = Date()
        }
        modelContext.delete(folder)
        try? modelContext.save()
        loadData()
    }
}

// MARK: - Move Sheet (supports batch)

struct MoveToFolderSheet: View {
    let cards: [Card]
    let folders: [CardFolder]
    var onDismiss: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    moveCards(to: nil)
                } label: {
                    HStack {
                        Image(systemName: "tray")
                        Text("Корень (Мои карточки)")
                        Spacer()
                        if cards.allSatisfy({ $0.folderId == nil }) {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                }

                ForEach(folders, id: \.id) { folder in
                    Button {
                        moveCards(to: folder.id)
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill").foregroundStyle(.teal)
                            Text(folder.name)
                            Spacer()
                            if cards.allSatisfy({ $0.folderId == folder.id }) {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(cards.count == 1 ? "Переместить" : "Переместить (\(cards.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private func moveCards(to folderId: UUID?) {
        for card in cards {
            card.folderId = folderId
        }
        try? modelContext.save()
        onDismiss()
        dismiss()
    }
}

// MARK: - Folder Detail Destination

struct FolderDetailDestination: View {
    let folderId: UUID
    @Environment(\.modelContext) private var modelContext
    @State private var folder: CardFolder?

    var body: some View {
        Group {
            if let folder {
                FolderListView(parentFolder: folder)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            let descriptor = FetchDescriptor<CardFolder>()
            let all = (try? modelContext.fetch(descriptor)) ?? []
            folder = all.first { $0.id == folderId }
        }
    }
}
