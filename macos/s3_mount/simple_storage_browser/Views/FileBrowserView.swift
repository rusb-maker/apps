import SwiftUI
import AppKit

// MARK: - Supporting Enums

enum SortField: String, CaseIterable {
    case name = "Name"
    case date = "Date Modified"
    case size = "Size"
}

private struct TreeNodeKey: Hashable {
    let bucket: String
    let prefix: String
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

    // Cache
    @State private var bucketsCache: [S3Bucket]? = nil
    @State private var objectLookup: [String: S3Object] = [:]
    @State private var objectBucketLookup: [String: String] = [:]

    private var secretKey: String {
        (try? KeychainService.load(for: profile.keychainKey)) ?? ""
    }
    private let minSizeColumnWidth: CGFloat = 70
    private let minDateColumnWidth: CGFloat = 120
    private let tableRowHeight: CGFloat = 24
    private let tableHeaderHeight: CGFloat = 26

    private func rowID(bucket: String, key: String) -> String {
        "\(bucket)||\(key)"
    }

    private func bucketRowID(_ bucket: String) -> String {
        "bucket||\(bucket)"
    }

    private func sorted(_ items: [S3Object]) -> [S3Object] {
        items.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            let ascending: Bool
            switch sortField {
            case .name: ascending = a.name.localizedCompare(b.name) == .orderedAscending
            case .date: ascending = (a.lastModified ?? .distantPast) < (b.lastModified ?? .distantPast)
            case .size: ascending = a.size < b.size
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

            if !s3Service.transfers.isEmpty {
                Divider()
                transferBar
            }
        }
        .navigationTitle(profile.name)
        .toolbar { toolbarItems }
        .task(id: "\(profile.id)") { await loadWithCache() }
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
            columnHeaderButton("Size", field: .size, width: sizeColumnWidth)
            resizeSeparator {
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dateColumnWidth = max(minDateColumnWidth, dateColumnWidthAtDragStart - value.translation.width)
                    }
                    .onEnded { _ in
                        dateColumnWidthAtDragStart = dateColumnWidth
                    }
            }
            columnHeaderButton("Date Added", field: .date, width: dateColumnWidth)
        }
        .frame(height: tableHeaderHeight)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var columnSeparator: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1)
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

    private func columnHeaderButton(_ title: String, field: SortField, width: CGFloat? = nil) -> some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(width: width)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Outline List

    private var outlineList: some View {
        VStack(spacing: 0) {
            columnHeader
            Divider()
            List {
                let bucketIDs = buckets.map { bucketRowID($0.name) }
                ForEach(buckets) { bucket in
                    bucketRow(bucket, orderedIDs: bucketIDs)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
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

        let isSelected = selectedKeys.contains(id)
        return DisclosureGroup(isExpanded: isExpanded) {
            treeChildren(for: node, bucket: bucket.name)
        } label: {
            HStack(spacing: 0) {
                nameCell(
                    id: id,
                    orderedIDs: orderedIDs,
                    iconName: "externaldrive",
                    iconColor: .blue,
                    text: bucket.name,
                    onDoubleTap: {
                        toggleNodeExpansion(bucket: bucket.name, prefix: "")
                    }
                )

                columnSeparator

                Text("—")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .frame(width: sizeColumnWidth, alignment: .center)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { handlePrimaryClickSelection(for: id, in: orderedIDs) }

                columnSeparator

                Text("Bucket")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .frame(width: dateColumnWidth, alignment: .center)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { handlePrimaryClickSelection(for: id, in: orderedIDs) }
            }
            .frame(height: tableRowHeight)
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    uploadFiles(to: bucket.name, prefix: "")
                } label: {
                    Label("Upload Files Here", systemImage: "arrow.up.circle")
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
        .listRowBackground(isSelected ? Color.accentColor : nil)
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
                    folderRow(child, bucket: bucket, orderedIDs: orderedIDs)
                } else {
                    objectRow(child, bucket: bucket, orderedIDs: orderedIDs)
                }
            }
        }
    }

    private func folderRow(_ obj: S3Object, bucket: String, orderedIDs: [String]) -> AnyView {
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
                objectRowContent(
                    obj,
                    id: id,
                    orderedIDs: orderedIDs,
                    onDoubleTap: {
                        toggleNodeExpansion(bucket: bucket, prefix: obj.key)
                    }
                )
                .contextMenu {
                    objectContextMenu(obj, bucket: bucket)
                }
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            .listRowBackground(selectedKeys.contains(id) ? Color.accentColor : nil)
        )
    }

    private func objectRow(_ obj: S3Object, bucket: String, orderedIDs: [String]) -> some View {
        let id = rowID(bucket: bucket, key: obj.key)

        return objectRowContent(
            obj,
            id: id,
            orderedIDs: orderedIDs,
            onDoubleTap: {
                downloadObject(obj, bucket: bucket)
            }
        )
        .contextMenu {
            objectContextMenu(obj, bucket: bucket)
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
        .listRowBackground(selectedKeys.contains(id) ? Color.accentColor : nil)
    }

    // MARK: - Context Menu

    private func objectContextMenu(_ obj: S3Object, bucket: String) -> some View {
        Group {
            if !obj.isFolder {
                Button {
                    downloadObject(obj, bucket: bucket)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            Button {
                uploadFiles(to: bucket, prefix: obj.isFolder ? obj.key : "")
            } label: {
                Label("Upload Files Here", systemImage: "arrow.up.circle")
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
        }
    }

    private func handlePrimaryClickSelection(for key: String, in orderedKeys: [String]) {
        let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
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

    // MARK: - Shared row content

    @ViewBuilder
    private func objectRowContent(
        _ obj: S3Object,
        id: String,
        orderedIDs: [String],
        onDoubleTap: @escaping () -> Void
    ) -> some View {
        let isSelected = selectedKeys.contains(id)
        HStack(spacing: 0) {
            if obj.isFolder {
                nameCell(
                    id: id,
                    orderedIDs: orderedIDs,
                    iconName: "folder.fill",
                    iconColor: .yellow,
                    text: obj.name,
                    onDoubleTap: onDoubleTap
                )
            } else {
                nameCell(
                    id: id,
                    orderedIDs: orderedIDs,
                    iconName: fileIcon(for: obj.name),
                    iconColor: .blue,
                    text: obj.name,
                    onDoubleTap: onDoubleTap
                )
            }

            columnSeparator

            Text(obj.isFolder ? "—" : obj.formattedSize)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(width: sizeColumnWidth, alignment: .center)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { handlePrimaryClickSelection(for: id, in: orderedIDs) }

            columnSeparator

            Text(obj.lastModified?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(width: dateColumnWidth, alignment: .center)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { handlePrimaryClickSelection(for: id, in: orderedIDs) }
        }
        .frame(height: tableRowHeight)
    }

    private func nameCell(
        id: String,
        orderedIDs: [String],
        iconName: String,
        iconColor: Color,
        text: String,
        onDoubleTap: @escaping () -> Void
    ) -> some View {
        let isSelected = selectedKeys.contains(id)
        return HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(isSelected ? Color.white : iconColor)
            Text(text)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            handlePrimaryClickSelection(for: id, in: orderedIDs)
        }
        .onTapGesture(count: 2) {
            selectSingleObject(id)
            onDoubleTap()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func fileIcon(for name: String) -> String {
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

    // MARK: - Error view

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundStyle(.orange)
            Text(msg).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Retry") { Task { await load() } }
        }
        .padding()
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

    private func downloadObject(_ obj: S3Object, bucket: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = obj.name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let dest = panel.url else { return }

        Task {
            do {
                let tmp = try await s3Service.download(
                    profile: profile,
                    secretKey: secretKey,
                    bucket: bucket,
                    key: obj.key
                )
                let destinationFolder = dest.deletingLastPathComponent()
                let destination: URL
                if FileManager.default.fileExists(atPath: dest.path) {
                    destination = uniqueDestinationURL(in: destinationFolder, fileName: dest.lastPathComponent)
                } else {
                    destination = dest
                }
                try FileManager.default.moveItem(at: tmp, to: destination)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func downloadSelectedObjects(_ items: [(bucket: String, object: S3Object)]) {
        let files = items.filter { !$0.object.isFolder }
        guard !files.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        guard panel.runModal() == .OK, let destinationFolder = panel.url else { return }

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
}
