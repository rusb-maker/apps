import SwiftUI
import SwiftData

struct RecordingsListView: View {
    @Query(sort: \RecordingSession.createdAt, order: .reverse) private var recordings: [RecordingSession]
    @Environment(\.modelContext) private var context

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
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                context.delete(recordings[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: RecordingSession.self) { session in
                RecordingDetailView(session: session)
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
