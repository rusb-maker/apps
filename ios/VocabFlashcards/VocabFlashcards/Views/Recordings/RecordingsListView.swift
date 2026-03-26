import SwiftUI
import SwiftData

struct RecordingsListView: View {
    @Query(filter: #Predicate<RecordingSession> { !$0.isTrashed }, sort: \RecordingSession.createdAt, order: .reverse) private var recordings: [RecordingSession]
    @Environment(\.modelContext) private var context
    @State private var recordingToDelete: RecordingSession?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    ContentUnavailableView(
                        "No Recordings",
                        systemImage: "waveform",
                        description: Text("Record a conversation to save your transcript here.")
                    )
                } else {
                    List {
                        ForEach(recordings) { session in
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
                                recordingToDelete = recordings[index]
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
                    Text(session.duration.formattedDuration)
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

}
