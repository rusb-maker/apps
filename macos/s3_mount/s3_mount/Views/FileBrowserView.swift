import SwiftUI
import AppKit

// MARK: - Supporting Enums

enum ViewStyle: String, CaseIterable { case browser, outline }
enum SortField: String, CaseIterable {
    case name = "Name"
    case date = "Date Modified"
    case size = "Size"
}

enum SortOrder: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"
}

struct FileBrowserView: View {
    let profile: S3Profile
    @Environment(S3Service.self) var s3Service

    @State private var currentBucket: String? = nil
    @State private var currentPrefix: String = ""
    @State private var buckets: [S3Bucket] = []
    @State private var objects: [S3Object] = []
    @State private var continuationToken: String? = nil
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var loadError: String?
    @State private var uploadError: String?

    // Multi-select
    @State private var selectedKeys: Set<String> = []
    @State private var selectionAnchorKey: String? = nil

    // View controls
    @State private var viewStyle: ViewStyle = .browser
    @State private var sortField: SortField = .name
    @State private var sortAscending = true

    // Outline mode state
    @State private var expandedKeys: Set<String> = []
    @State private var childItems: [String: [S3Object]] = [:]
    @State private var loadingKeys: Set<String> = []
    
    // Cache
    @State private var objectsCache: [String: [S3Object]] = [:]
    @State private var bucketsCache: [S3Bucket]? = nil
    @State private var sortedObjectsCache: [S3Object] = []
    @State private var objectLookup: [String: S3Object] = [:]

    private var secretKey: String {
        (try? KeychainService.load(for: profile.keychainKey)) ?? ""
    }

    private var sortedObjects: [S3Object] { sortedObjectsCache }

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

    private var downloadableSelection: [S3Object] {
        selectedKeys.compactMap { objectLookup[$0] }.filter { !$0.isFolder }
    }

    private func rebuildObjectLookup() {
        var next: [String: S3Object] = [:]
        for obj in objects {
            next[obj.key] = obj
        }
        for children in childItems.values {
            for child in children {
                next[child.key] = child
            }
        }
        objectLookup = next
    }

    private func refreshSortedObjects() {
        sortedObjectsCache = sorted(objects)
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            Divider()

            ZStack {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    errorView(err)
                } else if viewStyle == .browser {
                    browserList
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
        .task(id: "\(profile.id)/\(currentBucket ?? "")/\(currentPrefix)") { await loadWithCache() }
        .onChange(of: sortField) { _ in refreshSortedObjects() }
        .onChange(of: sortAscending) { _ in refreshSortedObjects() }
    }

    // MARK: - Breadcrumb

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                breadcrumbButton(label: profile.name, isLast: currentBucket == nil) {
                    currentBucket = nil
                    currentPrefix = ""
                }
                if let bucket = currentBucket {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    breadcrumbButton(label: bucket, isLast: currentPrefix.isEmpty) {
                        currentPrefix = ""
                    }
                    let parts = currentPrefix.split(separator: "/").map(String.init)
                    ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        let prefix = parts[0...idx].joined(separator: "/") + "/"
                        breadcrumbButton(label: part, isLast: idx == parts.count - 1) {
                            currentPrefix = prefix
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func breadcrumbButton(label: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .fontWeight(isLast ? .semibold : .regular)
                .foregroundStyle(isLast ? .primary : .secondary)
        }
        .buttonStyle(.borderless)
        .disabled(isLast)
    }

    // MARK: - Column Header
    
    private var columnHeader: some View {
        HStack(spacing: 0) {
            columnHeaderButton("Name", field: .name, minWidth: 200)
            Spacer()
            columnHeaderButton("Size", field: .size, width: 80)
            columnHeaderButton("Date Added", field: .date, width: 150)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func columnHeaderButton(_ title: String, field: SortField, width: CGFloat? = nil, minWidth: CGFloat? = nil) -> some View {
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
            .frame(width: width, alignment: field == .name ? .leading : .trailing)
            .frame(minWidth: minWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Browser List

    private var browserList: some View {
        VStack(spacing: 0) {
            if currentBucket != nil {
                columnHeader
                Divider()
            }
            List(selection: $selectedKeys) {
                if currentBucket == nil {
                    ForEach(buckets) { bucket in
                        HStack(spacing: 10) {
                            Image(systemName: "externaldrive")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text(bucket.name)
                            Spacer()
                            Text("Bucket").font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(bucket.name)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            currentBucket = bucket.name
                            currentPrefix = ""
                        }
                    }
                } else {
                    let orderedKeys = sortedObjects.map(\.key)
                    ForEach(sortedObjects) { obj in
                        objectRowContent(obj)
                            .tag(obj.key)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 1) {
                                handlePrimaryClickSelection(for: obj.key, in: orderedKeys)
                            }
                            .onTapGesture(count: 2) {
                                if obj.isFolder {
                                    currentPrefix = obj.key
                                } else {
                                    downloadObject(obj)
                                }
                            }
                            .contextMenu {
                                objectContextMenu(obj)
                            }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
    
    // MARK: - Outline List

    private var outlineList: some View {
        VStack(spacing: 0) {
            if currentBucket != nil {
                columnHeader
                Divider()
            }
            outlineListContent
        }
    }
    
    private var outlineListContent: some View {
        List(selection: $selectedKeys) {
            if currentBucket == nil {
                ForEach(buckets) { bucket in
                    let ck = cacheKey(bucket: bucket.name, prefix: "")
                    let isExpanded = Binding(
                        get: { expandedKeys.contains(ck) },
                        set: { expanded in
                            if expanded {
                                expandedKeys.insert(ck)
                                Task { await loadChildren(bucket: bucket.name, prefix: "") }
                            } else {
                                expandedKeys.remove(ck)
                            }
                        }
                    )
                    DisclosureGroup(isExpanded: isExpanded) {
                        if loadingKeys.contains(ck) {
                            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 4)
                        } else {
                            let childObjects = sorted(childItems[ck] ?? [])
                            let childKeys = childObjects.map(\.key)
                            ForEach(childObjects) { child in
                                if child.isFolder {
                                    folderRow(child, bucket: bucket.name, orderedKeys: childKeys)
                                } else {
                                    objectRowContent(child).tag(child.key)
                                        .onTapGesture(count: 1) {
                                            handlePrimaryClickSelection(for: child.key, in: childKeys)
                                        }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "externaldrive")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text(bucket.name)
                            Spacer()
                            Text("Bucket").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(bucket.name)
                }
            } else {
                let orderedKeys = sortedObjects.map(\.key)
                ForEach(sortedObjects) { obj in
                    if obj.isFolder {
                        folderRow(obj, bucket: currentBucket!, orderedKeys: orderedKeys)
                    } else {
                        objectRowContent(obj)
                            .tag(obj.key)
                            .onTapGesture(count: 1) {
                                handlePrimaryClickSelection(for: obj.key, in: orderedKeys)
                            }
                            .contextMenu {
                                objectContextMenu(obj)
                            }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
    
    // MARK: - Context Menu
    
    private func objectContextMenu(_ obj: S3Object) -> some View {
        Group {
            if !obj.isFolder {
                Button {
                    downloadObject(obj)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }
            
            if currentBucket != nil {
                Button {
                    uploadFiles()
                } label: {
                    Label("Upload Files Here", systemImage: "arrow.up.circle")
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
        }
    }

    private func folderRow(_ obj: S3Object, bucket: String, orderedKeys: [String]) -> AnyView {
        let ck = cacheKey(bucket: bucket, prefix: obj.key)
        let isExpanded = Binding(
            get: { expandedKeys.contains(ck) },
            set: { expanded in
                if expanded {
                    expandedKeys.insert(ck)
                    Task { await loadChildren(bucket: bucket, prefix: obj.key) }
                } else {
                    expandedKeys.remove(ck)
                }
            }
        )
        return AnyView(
            DisclosureGroup(isExpanded: isExpanded) {
                if loadingKeys.contains(ck) {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 4)
                } else {
                    let childObjects = sorted(childItems[ck] ?? [])
                    let childKeys = childObjects.map(\.key)
                    ForEach(childObjects) { child in
                        if child.isFolder {
                            folderRow(child, bucket: bucket, orderedKeys: childKeys)
                        } else {
                            objectRowContent(child)
                                .tag(child.key)
                                .onTapGesture(count: 1) {
                                    handlePrimaryClickSelection(for: child.key, in: childKeys)
                                }
                                .contextMenu {
                                    objectContextMenu(child)
                                }
                        }
                    }
                }
            } label: {
                objectRowContent(obj)
            }
            .tag(obj.key)
            .onTapGesture(count: 1) {
                handlePrimaryClickSelection(for: obj.key, in: orderedKeys)
            }
            .contextMenu {
                objectContextMenu(obj)
            }
        )
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

    // MARK: - Shared row content

    @ViewBuilder
    private func objectRowContent(_ obj: S3Object) -> some View {
        HStack(spacing: 10) {
            Image(systemName: obj.isFolder ? "folder.fill" : fileIcon(for: obj.name))
                .foregroundStyle(obj.isFolder ? .yellow : .blue)
                .frame(width: 20)
            Text(obj.name)
            Spacer()
            if !obj.isFolder {
                Text(obj.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            if let mod = obj.lastModified {
                Text(mod.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .trailing)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .trailing)
            }
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
        ToolbarItemGroup(placement: .secondaryAction) {
            Menu {
                Picker("Sort by", selection: $sortField) {
                    ForEach(SortField.allCases, id: \.self) { field in
                        Text(field.rawValue).tag(field)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Toggle(isOn: $sortAscending) {
                    Label("Ascending", systemImage: "arrow.up")
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }

            Picker("View", selection: $viewStyle) {
                Image(systemName: "folder").tag(ViewStyle.browser)
                Image(systemName: "list.bullet.indent").tag(ViewStyle.outline)
            }
            .pickerStyle(.segmented)
            .frame(width: 64)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            let downloadable = downloadableSelection
            if !downloadable.isEmpty {
                Button {
                    downloadSelectedObjects(downloadable)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            if currentBucket != nil {
                Button {
                    uploadFiles()
                } label: {
                    Label("Upload", systemImage: "arrow.up.circle")
                }
            }

            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - Outline helpers

    private func cacheKey(bucket: String, prefix: String) -> String {
        "b:\(bucket)/\(prefix)"
    }

    private func loadChildren(bucket: String, prefix: String) async {
        let key = cacheKey(bucket: bucket, prefix: prefix)
        guard childItems[key] == nil else { return }
        loadingKeys.insert(key)
        do {
            // Load ALL objects in subfolder
            var allObjects: [S3Object] = []
            var nextToken: String? = nil
            
            repeat {
                let result = try await s3Service.listObjects(
                    profile: profile, secretKey: secretKey,
                    bucket: bucket, prefix: prefix,
                    continuationToken: nextToken)
                allObjects.append(contentsOf: result.objects)
                nextToken = result.nextToken
            } while nextToken != nil
            
            childItems[key] = allObjects
            rebuildObjectLookup()
        } catch {
            childItems[key] = []
        }
        loadingKeys.remove(key)
    }

    // MARK: - Actions
    
    private func cacheKeyForPath() -> String {
        "\(profile.id)/\(currentBucket ?? "")/\(currentPrefix)"
    }
    
    private func loadWithCache() async {
        let key = cacheKeyForPath()
        
        // Check cache first
        if currentBucket == nil {
            if let cached = bucketsCache {
                buckets = cached
                selectedKeys.removeAll()
                selectionAnchorKey = nil
                objects = []
                sortedObjectsCache = []
                objectLookup = [:]
                return
            }
        } else {
            if let cached = objectsCache[key] {
                objects = cached
                continuationToken = nil
                refreshSortedObjects()
                rebuildObjectLookup()
                return
            }
        }
        
        // Not in cache, load from server
        await loadAllFromServer()
    }

    private func load() async {
        // Clear cache and reload
        let key = cacheKeyForPath()
        if currentBucket == nil {
            bucketsCache = nil
        } else {
            objectsCache.removeValue(forKey: key)
        }
        await loadAllFromServer()
    }
    
    private func loadAllFromServer() async {
        isLoading = true
        loadError = nil
        continuationToken = nil
        
        do {
            if let bucket = currentBucket {
                // Load ALL objects in folder for proper sorting
                var allObjects: [S3Object] = []
                var nextToken: String? = nil
                
                repeat {
                    let result = try await s3Service.listObjects(
                        profile: profile, secretKey: secretKey,
                        bucket: bucket, prefix: currentPrefix,
                        continuationToken: nextToken)
                    allObjects.append(contentsOf: result.objects)
                    nextToken = result.nextToken
                } while nextToken != nil
                
                objects = allObjects
                continuationToken = nil
                refreshSortedObjects()
                
                // Cache the result
                let key = cacheKeyForPath()
                objectsCache[key] = allObjects
                rebuildObjectLookup()
            } else {
                buckets = try await s3Service.listBuckets(profile: profile, secretKey: secretKey)
                bucketsCache = buckets
                selectedKeys.removeAll()
                selectionAnchorKey = nil
                objects = []
                sortedObjectsCache = []
                objectLookup = [:]
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
    
    private func loadMore() async {
        // No longer needed since we load all at once
        // Kept for compatibility but does nothing
    }

    private func downloadObject(_ obj: S3Object) {
        guard let bucket = currentBucket else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = obj.name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let dest = panel.url else { return }

        Task {
            do {
                let tmp = try await s3Service.download(
                    profile: profile, secretKey: secretKey,
                    bucket: bucket, key: obj.key)
                try FileManager.default.moveItem(at: tmp, to: dest)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func downloadSelectedObjects(_ items: [S3Object]) {
        guard let bucket = currentBucket else { return }
        let files = items.filter { !$0.isFolder }
        guard !files.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        guard panel.runModal() == .OK, let destinationFolder = panel.url else { return }

        Task {
            do {
                for obj in files {
                    let tmp = try await s3Service.download(
                        profile: profile,
                        secretKey: secretKey,
                        bucket: bucket,
                        key: obj.key
                    )

                    let destination = uniqueDestinationURL(in: destinationFolder, fileName: obj.name)
                    try FileManager.default.moveItem(at: tmp, to: destination)
                }
            } catch {
                loadError = error.localizedDescription
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

    private func uploadFiles() {
        guard let bucket = currentBucket else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls

        Task {
            for url in urls {
                do {
                    try await s3Service.upload(
                        profile: profile, secretKey: secretKey,
                        bucket: bucket, prefix: currentPrefix, from: url)
                } catch {
                    uploadError = error.localizedDescription
                }
            }
            await load()
        }
    }
}
