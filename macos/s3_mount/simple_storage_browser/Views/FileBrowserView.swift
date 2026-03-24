import SwiftUI
import AppKit

// MARK: - Helpers

private func finderFormattedDate(_ date: Date?) -> String {
    guard let date else { return "—" }
    let cal = Calendar.current
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mm a"
    let timeStr = timeFormatter.string(from: date)
    if cal.isDateInToday(date) {
        return "Today at \(timeStr)"
    } else if cal.isDateInYesterday(date) {
        return "Yesterday at \(timeStr)"
    } else {
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return fullFormatter.string(from: date)
    }
}

// MARK: - Supporting Enums

enum SortField: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case date = "Date Modified"
}

private struct TreeNodeKey: Hashable {
    let bucket: String
    let prefix: String
}

// MARK: - Equatable row views (prevents O(N) re-renders on selection change)

private struct ObjectRowView: View, Equatable {
    let obj: S3Object
    let id: String
    let isSelected: Bool
    let sizeColumnWidth: CGFloat
    let dateColumnWidth: CGFloat
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onSelectSingle: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
        lhs.isSelected == rhs.isSelected &&
        lhs.sizeColumnWidth == rhs.sizeColumnWidth &&
        lhs.dateColumnWidth == rhs.dateColumnWidth
    }

    var body: some View {
        let iconName: String
        let iconColor: Color
        if obj.isFolder {
            iconName = "folder.fill"
            iconColor = Color(nsColor: .systemBlue)
        } else {
            iconName = fileIconName(for: obj.name)
            iconColor = .blue
        }

        return HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                Text(obj.name)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
            .onTapGesture(count: 1) { onTap() }
            .onTapGesture(count: 2) { onSelectSingle(); onDoubleTap() }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(obj.isFolder ? "—" : obj.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: sizeColumnWidth, alignment: .trailing)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            Text(finderFormattedDate(obj.lastModified))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: dateColumnWidth, alignment: .trailing)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
        }
        .frame(height: 28)
    }

    private func fileIconName(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "webp": return "photo"
        case "mp4", "mov", "avi": return "film"
        case "mp3", "wav", "flac", "aac": return "music.note"
        case "pdf": return "doc.richtext"
        case "txt", "md": return "doc.text"
        case "json", "xml", "yaml", "yml": return "curlybraces"
        case "zip", "gz", "tar": return "archivebox"
        default: return "doc"
        }
    }
}

private struct BucketRowContentView: View, Equatable {
    let id: String
    let bucketName: String
    let isSelected: Bool
    let sizeColumnWidth: CGFloat
    let dateColumnWidth: CGFloat
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onSelectSingle: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
        lhs.isSelected == rhs.isSelected &&
        lhs.sizeColumnWidth == rhs.sizeColumnWidth &&
        lhs.dateColumnWidth == rhs.dateColumnWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive")
                    .foregroundStyle(Color(nsColor: .systemBlue))
                Text(bucketName)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
            .onTapGesture(count: 1) { onTap() }
            .onTapGesture(count: 2) { onSelectSingle(); onDoubleTap() }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: sizeColumnWidth, alignment: .trailing)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: dateColumnWidth, alignment: .trailing)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
        }
        .frame(height: 28)
    }
}

struct FileBrowserView: View {
    let profile: S3Profile
    @Environment(S3Service.self) var s3Service

    @State private var buckets: [S3Bucket] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var uploadError: String?

    // Multi-select
    @State private var selectedKeys: Set<String> = []
    @State private var selectionAnchorKey: String? = nil

    @State private var sortField: SortField = .name
    @State private var sortAscending = true
    @State private var sizeColumnWidth: CGFloat = 100
    @State private var dateColumnWidth: CGFloat = 170
    @State private var sizeColumnWidthAtDragStart: CGFloat = 100
    @State private var dateColumnWidthAtDragStart: CGFloat = 170

    // Tree state
    @State private var expandedKeys: Set<TreeNodeKey> = []
    @State private var childItems: [TreeNodeKey: [S3Object]] = [:]
    @State private var loadingKeys: Set<TreeNodeKey> = []

    // Path breadcrumb
    @State private var breadcrumbPath: [String] = []

    // Cache
    @State private var bucketsCache: [S3Bucket]? = nil
    @State private var objectLookup: [String: S3Object] = [:]
    @State private var objectBucketLookup: [String: String] = [:]

    private var secretKey: String {
        (try? KeychainService.load(for: profile.keychainKey)) ?? ""
    }
    private let minSizeColumnWidth: CGFloat = 70
    private let minDateColumnWidth: CGFloat = 120
    private let tableRowHeight: CGFloat = 28
    private let tableHeaderHeight: CGFloat = 22
    private let tableHorizontalInset: CGFloat = 8
    private let disclosureGridCompensation: CGFloat = 16

    private func rowID(bucket: String, key: String) -> String {
        "\(bucket)||\(key)"
    }

    private func bucketRowID(_ bucket: String) -> String {
        "bucket||\(bucket)"
    }
    
    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: tableHorizontalInset, bottom: 0, trailing: tableHorizontalInset)
    }

    private func sorted(_ items: [S3Object]) -> [S3Object] {
        items.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            let ascending: Bool
            switch sortField {
            case .name: ascending = a.name.localizedCompare(b.name) == .orderedAscending
            case .size: ascending = a.size < b.size
            case .date: ascending = (a.lastModified ?? .distantPast) < (b.lastModified ?? .distantPast)
            }
            return sortAscending ? ascending : !ascending
        }
    }

    private var downloadableSelection: [(bucket: String, object: S3Object)] {
        selectedKeys.compactMap { key in
            guard let obj = objectLookup[key],
                  let bucket = objectBucketLookup[key],
                  !obj.isFolder else { return nil }
            return (bucket, obj)
        }
    }

    private var allSelectedItems: [(bucket: String, object: S3Object)] {
        selectedKeys.compactMap { key in
            guard let obj = objectLookup[key],
                  let bucket = objectBucketLookup[key] else { return nil }
            return (bucket, obj)
        }
    }

    private func rebuildObjectLookup() {
        var nextObjectLookup: [String: S3Object] = [:]
        var nextBucketLookup: [String: String] = [:]

        for (node, children) in childItems {
            for child in children {
                let id = rowID(bucket: node.bucket, key: child.key)
                nextObjectLookup[id] = child
                nextBucketLookup[id] = node.bucket
            }
        }

        objectLookup = nextObjectLookup
        objectBucketLookup = nextBucketLookup
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    errorView(err)
                } else {
                    outlineList
                }
            }

            Divider()
            pathBar

            if !s3Service.transfers.isEmpty {
                Divider()
                transferBar
            }
        }
        .navigationTitle(profile.name)
        .toolbar { toolbarItems }
        .task(id: "\(profile.id)") { await loadWithCache() }
        .onChange(of: selectedKeys) { _, newKeys in
            breadcrumbPath = buildBreadcrumb(from: newKeys.first)
        }
    }

    // MARK: - Path Bar

    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if breadcrumbPath.isEmpty {
                    Text(profile.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(breadcrumbPath.enumerated()), id: \.offset) { index, segment in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(segment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func buildBreadcrumb(from rowID: String?) -> [String] {
        guard let rowID else { return [profile.name] }
        // Bucket row: "bucket||name"
        if rowID.hasPrefix("bucket||") {
            let bucketName = String(rowID.dropFirst("bucket||".count))
            return [profile.name, bucketName]
        }
        // Object/folder row: "bucketName||key/path/"
        guard let separatorRange = rowID.range(of: "||") else { return [profile.name] }
        let bucket = String(rowID[rowID.startIndex..<separatorRange.lowerBound])
        let key = String(rowID[separatorRange.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var segments = [profile.name, bucket]
        let pathComponents = key.split(separator: "/").map(String.init)
        segments.append(contentsOf: pathComponents)
        return segments
    }

    // MARK: - Column Header

    private var columnHeader: some View {
        HStack(spacing: 0) {
            columnHeaderButton("Name", field: .name)
            resizeSeparator {
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        sizeColumnWidth = max(minSizeColumnWidth, sizeColumnWidthAtDragStart - value.translation.width)
                    }
                    .onEnded { _ in
                        sizeColumnWidthAtDragStart = sizeColumnWidth
                    }
            }
            columnHeaderButton("Size", field: .size, width: sizeColumnWidth, alignment: .center)
            resizeSeparator {
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dateColumnWidth = max(minDateColumnWidth, dateColumnWidthAtDragStart - value.translation.width)
                    }
                    .onEnded { _ in
                        dateColumnWidthAtDragStart = dateColumnWidth
                    }
            }
            columnHeaderButton("Date Modified", field: .date, width: dateColumnWidth, alignment: .center)
        }
        .frame(height: tableHeaderHeight)
        .padding(.leading, tableHorizontalInset)
        .padding(.trailing, tableHorizontalInset + disclosureGridCompensation)
        .background(.bar)
    }

    private var columnSeparator: some View {
        Divider()
    }

    private func resizeSeparator(_ gesture: () -> some Gesture) -> some View {
        columnSeparator
            .overlay(
                Color.clear
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .highPriorityGesture(gesture())
            )
    }

    private func columnHeaderButton(_ title: String, field: SortField, width: CGFloat? = nil, alignment: Alignment = .leading) -> some View {
        Button {
            if sortField == field {
                sortAscending.toggle()
            } else {
                sortField = field
                sortAscending = true
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if sortField == field {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .frame(width: width)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Outline List

    private var outlineList: some View {
        List {
            let bucketIDs = buckets.map { bucketRowID($0.name) }
            ForEach(buckets) { bucket in
                bucketRow(bucket, orderedIDs: bucketIDs)
            }
        }
        .listStyle(.plain)
        .safeAreaBar(edge: .top) {
            columnHeader
        }
    }

    private func bucketRow(_ bucket: S3Bucket, orderedIDs: [String]) -> some View {
        let node = TreeNodeKey(bucket: bucket.name, prefix: "")
        let id = bucketRowID(bucket.name)
        let isExpanded = Binding(
            get: { expandedKeys.contains(node) },
            set: { expanded in
                if expanded {
                    expandedKeys.insert(node)
                    Task { await loadChildren(bucket: bucket.name, prefix: "") }
                } else {
                    expandedKeys.remove(node)
                }
            }
        )

        return DisclosureGroup(isExpanded: isExpanded) {
            treeChildren(for: node, bucket: bucket.name)
        } label: {
            BucketRowContentView(
                id: id,
                bucketName: bucket.name,
                isSelected: selectedKeys.contains(id),
                sizeColumnWidth: sizeColumnWidth,
                dateColumnWidth: dateColumnWidth,
                onTap: { handlePrimaryClickSelection(for: id, in: orderedIDs) },
                onDoubleTap: { toggleNodeExpansion(bucket: bucket.name, prefix: "") },
                onSelectSingle: { selectSingleObject(id) }
            )
            .equatable()
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    uploadFiles(to: bucket.name, prefix: "")
                } label: {
                    Label("Upload Files Here", systemImage: "arrow.up.circle")
                }

                Divider()

                Button {
                    Task { await refreshNode(bucket: bucket.name, prefix: "") }
                } label: {
                    Label("Refresh Bucket", systemImage: "arrow.clockwise")
                }
            }
        }
        .listRowInsets(rowInsets)
        .listRowSeparator(.visible)
        .listRowBackground(selectedKeys.contains(id) ? Color.accentColor.opacity(0.2) : Color.clear)
    }

    @ViewBuilder
    private func treeChildren(for node: TreeNodeKey, bucket: String) -> some View {
        if loadingKeys.contains(node) {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 4)
        } else {
            let children = sorted(childItems[node] ?? [])
            let orderedIDs = children.map { rowID(bucket: bucket, key: $0.key) }

            ForEach(children) { child in
                if child.isFolder {
                    folderRow(child, bucket: bucket, orderedIDs: orderedIDs, parentPrefix: node.prefix)
                } else {
                    objectRow(child, bucket: bucket, orderedIDs: orderedIDs, parentPrefix: node.prefix)
                }
            }
        }
    }

    private func folderRow(_ obj: S3Object, bucket: String, orderedIDs: [String], parentPrefix: String) -> AnyView {
        let node = TreeNodeKey(bucket: bucket, prefix: obj.key)
        let id = rowID(bucket: bucket, key: obj.key)
        let isExpanded = Binding(
            get: { expandedKeys.contains(node) },
            set: { expanded in
                if expanded {
                    expandedKeys.insert(node)
                    Task { await loadChildren(bucket: bucket, prefix: obj.key) }
                } else {
                    expandedKeys.remove(node)
                }
            }
        )

        return AnyView(
            DisclosureGroup(isExpanded: isExpanded) {
                treeChildren(for: node, bucket: bucket)
            } label: {
                ObjectRowView(
                    obj: obj,
                    id: id,
                    isSelected: selectedKeys.contains(id),
                    sizeColumnWidth: sizeColumnWidth,
                    dateColumnWidth: dateColumnWidth,
                    onTap: { handlePrimaryClickSelection(for: id, in: orderedIDs) },
                    onDoubleTap: { toggleNodeExpansion(bucket: bucket, prefix: obj.key) },
                    onSelectSingle: { selectSingleObject(id) }
                )
                .equatable()
                .contextMenu {
                    objectContextMenu(obj, bucket: bucket, parentPrefix: parentPrefix)
                }
            }
            .listRowInsets(rowInsets)
            .listRowSeparator(.visible)
                .listRowBackground(selectedKeys.contains(id) ? Color.accentColor.opacity(0.2) : Color.clear)
        )
    }

    private func objectRow(_ obj: S3Object, bucket: String, orderedIDs: [String], parentPrefix: String) -> some View {
        let id = rowID(bucket: bucket, key: obj.key)

        return ObjectRowView(
            obj: obj,
            id: id,
            isSelected: selectedKeys.contains(id),
            sizeColumnWidth: sizeColumnWidth,
            dateColumnWidth: dateColumnWidth,
            onTap: { handlePrimaryClickSelection(for: id, in: orderedIDs) },
            onDoubleTap: { downloadObject(obj, bucket: bucket) },
            onSelectSingle: { selectSingleObject(id) }
        )
        .equatable()
        .contextMenu {
            objectContextMenu(obj, bucket: bucket, parentPrefix: parentPrefix)
        }
        .listRowInsets(rowInsets)
        .listRowSeparator(.visible)
        .listRowBackground(selectedKeys.contains(id) ? Color.accentColor.opacity(0.2) : Color.clear)
    }

    // MARK: - Context Menu

    private func objectContextMenu(_ obj: S3Object, bucket: String, parentPrefix: String) -> some View {
        let id = rowID(bucket: bucket, key: obj.key)
        let downloadable = downloadableSelection
        let isMultiSelected = selectedKeys.count > 1 && selectedKeys.contains(id)

        return Group {
            if !obj.isFolder {
                if downloadable.count > 1 && isMultiSelected {
                    Button {
                        downloadSelectedObjects(downloadable)
                    } label: {
                        Label("Download \(downloadable.count) Files", systemImage: "arrow.down.circle")
                    }
                } else {
                    Button {
                        downloadObject(obj, bucket: bucket)
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
            }

            // Copy S3 URL
            if isMultiSelected {
                let selectedItems = allSelectedItems
                if !selectedItems.isEmpty {
                    Button {
                        copyS3URLs(selectedItems)
                    } label: {
                        Label("Copy \(selectedItems.count) S3 URLs", systemImage: "link")
                    }
                }
            } else {
                Button {
                    copyS3URL(bucket: bucket, key: obj.key)
                } label: {
                    Label("Copy S3 URL", systemImage: "link")
                }
            }

            Divider()

            Button {
                uploadFiles(to: bucket, prefix: obj.isFolder ? obj.key : "")
            } label: {
                Label("Upload Files Here", systemImage: "arrow.up.circle")
            }

            Divider()

            if obj.isFolder {
                Button {
                    Task { await refreshNode(bucket: bucket, prefix: obj.key) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } else {
                Button {
                    Task { await refreshNode(bucket: bucket, prefix: parentPrefix) }
                } label: {
                    Label("Refresh Folder", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            Menu("Sort By") {
                Button {
                    sortField = .name
                    sortAscending = true
                } label: {
                    Label("Name", systemImage: sortField == .name ? "checkmark" : "")
                }
                Button {
                    sortField = .size
                    sortAscending = false
                } label: {
                    Label("Size", systemImage: sortField == .size ? "checkmark" : "")
                }
                Button {
                    sortField = .date
                    sortAscending = false
                } label: {
                    Label("Date Added", systemImage: sortField == .date ? "checkmark" : "")
                }
                Divider()
                Button {
                    sortAscending = true
                } label: {
                    Label("Ascending", systemImage: sortAscending ? "checkmark" : "")
                }
                Button {
                    sortAscending = false
                } label: {
                    Label("Descending", systemImage: !sortAscending ? "checkmark" : "")
                }
            }

            Divider()

            // Delete
            if !obj.isFolder {
                if downloadable.count > 1 && isMultiSelected {
                    Button(role: .destructive) {
                        deleteFiles(downloadable.map { (bucket: $0.bucket, key: $0.object.key) })
                    } label: {
                        Label("Delete \(downloadable.count) Files", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        deleteFiles([(bucket: bucket, key: obj.key)])
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func handlePrimaryClickSelection(for key: String, in orderedKeys: [String]) {
        let currentModifiers = (NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags)
        let modifiers = currentModifiers.intersection(.deviceIndependentFlagsMask)
        let isShift = modifiers.contains(.shift)
        let isCommand = modifiers.contains(.command)

        if isShift,
           let anchor = selectionAnchorKey,
           let anchorIndex = orderedKeys.firstIndex(of: anchor),
           let keyIndex = orderedKeys.firstIndex(of: key) {
            let lower = min(anchorIndex, keyIndex)
            let upper = max(anchorIndex, keyIndex)
            let rangeSelection = Set(orderedKeys[lower...upper])
            if isCommand {
                selectedKeys.formUnion(rangeSelection)
            } else {
                selectedKeys = rangeSelection
            }
            return
        }

        if isCommand {
            if selectedKeys.contains(key) {
                selectedKeys.remove(key)
            } else {
                selectedKeys.insert(key)
            }
            selectionAnchorKey = key
        } else {
            selectedKeys = [key]
            selectionAnchorKey = key
        }
    }

    private func selectSingleObject(_ key: String) {
        selectedKeys = [key]
        selectionAnchorKey = key
    }

    private func toggleNodeExpansion(bucket: String, prefix: String) {
        let node = TreeNodeKey(bucket: bucket, prefix: prefix)
        if expandedKeys.contains(node) {
            expandedKeys.remove(node)
        } else {
            expandedKeys.insert(node)
            Task { await loadChildren(bucket: bucket, prefix: prefix) }
        }
    }

    // MARK: - Error view

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundStyle(.orange)
            Text(msg).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Retry") { Task { await load() } }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transfer bar

    private var transferBar: some View {
        HStack(spacing: 12) {
            ForEach(s3Service.transfers) { task in
                HStack(spacing: 6) {
                    switch task.status {
                    case .inProgress:
                        ProgressView().controlSize(.mini)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failed:
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    }
                    Text(task.name).font(.caption).lineLimit(1)
                }
            }
            Spacer()
            Button("Clear") { s3Service.clearFinishedTransfers() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            let downloadable = downloadableSelection
            if !downloadable.isEmpty {
                Button {
                    downloadSelectedObjects(downloadable)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - Actions

    private func loadWithCache() async {
        if let cached = bucketsCache {
            buckets = cached
            return
        }
        await loadAllFromServer()
    }

    private func load() async {
        bucketsCache = nil
        childItems.removeAll()
        expandedKeys.removeAll()
        loadingKeys.removeAll()
        objectLookup = [:]
        objectBucketLookup = [:]
        selectedKeys.removeAll()
        selectionAnchorKey = nil
        await loadAllFromServer()
    }

    private func loadAllFromServer() async {
        isLoading = true
        loadError = nil

        do {
            buckets = try await s3Service.listBuckets(profile: profile, secretKey: secretKey)
            bucketsCache = buckets
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func loadChildren(bucket: String, prefix: String) async {
        let node = TreeNodeKey(bucket: bucket, prefix: prefix)
        guard childItems[node] == nil else { return }

        loadingKeys.insert(node)
        defer { loadingKeys.remove(node) }

        do {
            var allObjects: [S3Object] = []
            var nextToken: String? = nil

            repeat {
                let result = try await s3Service.listObjects(
                    profile: profile,
                    secretKey: secretKey,
                    bucket: bucket,
                    prefix: prefix,
                    continuationToken: nextToken
                )
                allObjects.append(contentsOf: result.objects)
                nextToken = result.nextToken
            } while nextToken != nil

            childItems[node] = allObjects
            rebuildObjectLookup()
        } catch {
            childItems[node] = []
            loadError = error.localizedDescription
        }
    }

    private func refreshNode(bucket: String, prefix: String) async {
        let node = TreeNodeKey(bucket: bucket, prefix: prefix)
        childItems.removeValue(forKey: node)
        await loadChildren(bucket: bucket, prefix: prefix)
    }

    private func downloadObject(_ obj: S3Object, bucket: String) {
        guard let destinationFolder = chooseDownloadFolder() else { return }

        Task {
            do {
                let tmp = try await s3Service.download(
                    profile: profile,
                    secretKey: secretKey,
                    bucket: bucket,
                    key: obj.key
                )
                let destination = uniqueDestinationURL(in: destinationFolder, fileName: obj.name)
                try FileManager.default.moveItem(at: tmp, to: destination)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func downloadSelectedObjects(_ items: [(bucket: String, object: S3Object)]) {
        let files = items.filter { !$0.object.isFolder }
        guard !files.isEmpty else { return }

        guard let destinationFolder = chooseDownloadFolder() else { return }

        Task {
            for item in files {
                do {
                    let tmp = try await s3Service.download(
                        profile: profile,
                        secretKey: secretKey,
                        bucket: item.bucket,
                        key: item.object.key
                    )

                    let destination = uniqueDestinationURL(in: destinationFolder, fileName: item.object.name)
                    try FileManager.default.moveItem(at: tmp, to: destination)
                } catch {
                    loadError = error.localizedDescription
                }
            }
        }
    }
    
    private func chooseDownloadFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func uniqueDestinationURL(in folder: URL, fileName: String) -> URL {
        let fm = FileManager.default
        let ext = (fileName as NSString).pathExtension
        let base = (fileName as NSString).deletingPathExtension
        var candidate = folder.appendingPathComponent(fileName)
        var idx = 1

        while fm.fileExists(atPath: candidate.path) {
            let numberedName = ext.isEmpty ? "\(base) \(idx)" : "\(base) \(idx).\(ext)"
            candidate = folder.appendingPathComponent(numberedName)
            idx += 1
        }

        return candidate
    }

    private func uploadFiles(to bucket: String, prefix: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls

        Task {
            for url in urls {
                do {
                    try await s3Service.upload(
                        profile: profile,
                        secretKey: secretKey,
                        bucket: bucket,
                        prefix: prefix,
                        from: url
                    )
                } catch {
                    uploadError = error.localizedDescription
                }
            }
            childItems.removeAll()
            expandedKeys.removeAll()
            objectLookup = [:]
            objectBucketLookup = [:]
            await load()
        }
    }

    // MARK: - Copy S3 URL

    private func copyS3URL(bucket: String, key: String) {
        let url = profile.bucketURL(bucket: bucket).appendingPathComponent(key)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    private func copyS3URLs(_ items: [(bucket: String, object: S3Object)]) {
        let urls = items.map { profile.bucketURL(bucket: $0.bucket).appendingPathComponent($0.object.key).absoluteString }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urls.joined(separator: "\n"), forType: .string)
    }

    // MARK: - Delete

    private func deleteFiles(_ items: [(bucket: String, key: String)]) {
        guard !items.isEmpty else { return }

        let alert = NSAlert()
        if items.count == 1 {
            let name = (items[0].key as NSString).lastPathComponent
            alert.messageText = "Delete \"\(name)\"?"
            alert.informativeText = "This will permanently remove the file from S3."
        } else {
            alert.messageText = "Delete \(items.count) files?"
            alert.informativeText = "This will permanently remove these files from S3."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            var parentPrefixes: Set<String> = []
            for item in items {
                do {
                    try await s3Service.delete(
                        profile: profile,
                        secretKey: secretKey,
                        bucket: item.bucket,
                        key: item.key
                    )
                    parentPrefixes.insert(parentPrefix(forKey: item.key))
                } catch {
                    loadError = error.localizedDescription
                }
            }
            selectedKeys.removeAll()
            // Refresh each affected parent folder
            let affectedBuckets = Set(items.map(\.bucket))
            for bucket in affectedBuckets {
                for prefix in parentPrefixes {
                    await refreshNode(bucket: bucket, prefix: prefix)
                }
            }
        }
    }

    private func parentPrefix(forKey key: String) -> String {
        let trimmed = key.hasSuffix("/") ? String(key.dropLast()) : key
        guard let lastSlash = trimmed.lastIndex(of: "/") else { return "" }
        return String(trimmed[...lastSlash])
    }
}
