import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showMoreMenu = false
    @State private var showHistory = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecordingView()
                    .tabItem {
                        Label("Record", systemImage: "mic.fill")
                    }
                    .tag(0)
                TextInputView()
                    .tabItem {
                        Label("Text", systemImage: "doc.text")
                    }
                    .tag(1)
                GroupsListView()
                    .tabItem {
                        Label("Folders", systemImage: "folder.fill")
                    }
                    .tag(2)
                StudySessionView()
                    .tabItem {
                        Label("Study", systemImage: "brain.head.profile")
                    }
                    .tag(3)
                moreTabContent
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(4)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 4 {
                    previousTab = oldValue
                    withAnimation(.easeOut(duration: 0.2)) {
                        showMoreMenu = true
                    }
                } else {
                    if showMoreMenu {
                        withAnimation(.easeIn(duration: 0.15)) {
                            showMoreMenu = false
                        }
                    }
                    previousTab = newValue
                }
            }

            // Glass overlay
            if showMoreMenu {
                // Scrim — visual only, taps pass through to tab bar
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack {
                    // Tappable area above popup — dismisses on tap
                    Spacer()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeIn(duration: 0.15)) {
                                showMoreMenu = false
                            }
                            selectedTab = previousTab
                        }

                    VStack(spacing: 0) {
                        Button {
                            showMoreMenu = false
                            showHistory = true
                        } label: {
                            Label("History", systemImage: "clock.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                        }
                        .foregroundStyle(.primary)

                        Divider()
                            .padding(.horizontal, 16)

                        Button {
                            showMoreMenu = false
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                        }
                        .foregroundStyle(.primary)
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 5)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 70)
                }
                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showHistory, onDismiss: {
            selectedTab = previousTab
        }) {
            RecordingsListView()
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            selectedTab = previousTab
        }) {
            SettingsView()
        }
        .task {
            cleanupExpiredTrash()
        }
    }

    @ViewBuilder
    private var moreTabContent: some View {
        switch previousTab {
        case 1:  TextInputView()
        case 2:  GroupsListView()
        case 3:  StudySessionView()
        default: RecordingView()
        }
    }

    private func cleanupExpiredTrash() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        // Fetch only trashed items instead of all records
        let cardDescriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.isTrashed }
        )
        if let trashedCards = try? context.fetch(cardDescriptor) {
            for card in trashedCards {
                if let trashedAt = card.trashedAt, trashedAt < cutoff {
                    context.delete(card)
                }
            }
        }

        let groupDescriptor = FetchDescriptor<CardGroup>(
            predicate: #Predicate<CardGroup> { $0.isTrashed }
        )
        if let trashedGroups = try? context.fetch(groupDescriptor) {
            for group in trashedGroups {
                if let trashedAt = group.trashedAt, trashedAt < cutoff {
                    if group.parent == nil || !(group.parent?.isTrashed ?? false) {
                        context.delete(group)
                    }
                }
            }
        }

        let recordingDescriptor = FetchDescriptor<RecordingSession>(
            predicate: #Predicate<RecordingSession> { $0.isTrashed }
        )
        if let trashedRecordings = try? context.fetch(recordingDescriptor) {
            for recording in trashedRecordings {
                if let trashedAt = recording.trashedAt, trashedAt < cutoff {
                    context.delete(recording)
                }
            }
        }

        try? context.save()
    }
}
