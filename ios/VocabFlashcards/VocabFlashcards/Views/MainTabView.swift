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
                Color.clear
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(4)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 4 {
                    previousTab = oldValue
                    selectedTab = oldValue
                    withAnimation(.easeOut(duration: 0.2)) {
                        showMoreMenu = true
                    }
                } else {
                    previousTab = newValue
                }
            }

            // Glass overlay
            if showMoreMenu {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.15)) {
                            showMoreMenu = false
                        }
                    }

                VStack {
                    Spacer()

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
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                RecordingsListView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showHistory = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
        .task {
            cleanupExpiredTrash()
        }
    }

    private func cleanupExpiredTrash() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        if let cards = try? context.fetch(FetchDescriptor<Card>()) {
            for card in cards where card.isTrashed {
                if let trashedAt = card.trashedAt, trashedAt < cutoff {
                    context.delete(card)
                }
            }
        }

        if let groups = try? context.fetch(FetchDescriptor<CardGroup>()) {
            for group in groups where group.isTrashed {
                if let trashedAt = group.trashedAt, trashedAt < cutoff {
                    if group.parent == nil || !(group.parent?.isTrashed ?? false) {
                        context.delete(group)
                    }
                }
            }
        }

        if let recordings = try? context.fetch(FetchDescriptor<RecordingSession>()) {
            for recording in recordings where recording.isTrashed {
                if let trashedAt = recording.trashedAt, trashedAt < cutoff {
                    context.delete(recording)
                }
            }
        }

        try? context.save()
    }
}
