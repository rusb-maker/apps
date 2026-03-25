import SwiftUI
import SwiftData

struct RecordingsListView: View {
    @Query(sort: \RecordingSession.createdAt, order: .reverse) private var recordings: [RecordingSession]
    @Environment(\.modelContext) private var context
    @State private var recordingToDelete: RecordingSession?
    @State private var showDeleteConfirm = false

    private var activeRecordings: [RecordingSession] {
        recordings.filter { !$0.isTrashed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeRecordings.isEmpty {
                    ContentUnavailableView(
                        "No Recordings",
                        systemImage: "waveform",
                        description: Text("Record a conversation to save your transcript here.")
                    )
                } else {
                    List {
                        ForEach(activeRecordings) { session in
                            NavigationLink(value: session) {
                                RecordingRow(session: session)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    recordingToDelete = session
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            if let index = offsets.first {
                                recordingToDelete = activeRecordings[index]
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: RecordingSession.self) { session in
                RecordingDetailView(session: session)
            }
            .alert("Move to Trash?", isPresented: $showDeleteConfirm) {
                Button("Move to Trash", role: .destructive) {
                    if let recording = recordingToDelete {
                        recording.isTrashed = true
                        recording.trashedAt = Date()
                        try? context.save()
                    }
                    recordingToDelete = nil
                }
                Button("Cancel", role: .cancel) { recordingToDelete = nil }
            } message: {
                Text("This recording will be moved to Trash.")
            }
        }
    }
}

struct RecordingRow: View {
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.createdAt, style: .date)
                    .font(.subheadline.weight(.medium))
                Text(session.createdAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if session.duration > 0 {
                    Text(formatDuration(session.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(session.rawTranscript)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !session.extractedPhrases.isEmpty {
                Text("\(session.extractedPhrases.count) phrases extracted")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
