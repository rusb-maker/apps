import SwiftUI
import SwiftData

struct ReviewListView: View {
    @State private var viewModel = ReviewViewModel()
    @State private var showGroupPicker = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(phrases: [ExtractedPhrase]) {
        _viewModel = State(initialValue: {
            let vm = ReviewViewModel()
            vm.phrases = phrases
            return vm
        }())
    }

    var body: some View {
        List {
            ForEach(Array(viewModel.phrases.enumerated()), id: \.element.id) { index, phrase in
                ReviewRow(phrase: phrase)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.phrases[index].isSelected = false
                        } label: {
                            Label("Skip", systemImage: "xmark")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.phrases[index].isSelected = true
                        } label: {
                            Label("Keep", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
            }
            .onDelete { offsets in
                viewModel.remove(at: offsets)
            }
        }
        .navigationTitle("Review Phrases")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save \(viewModel.selectedCount)") {
                    viewModel.saveSelectedCards(context: context)
                    dismiss()
                }
                .disabled(viewModel.selectedCount == 0)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Choose Group") {
                    showGroupPicker = true
                }
            }
        }
        .sheet(isPresented: $showGroupPicker) {
            GroupPickerView(selected: $viewModel.selectedGroup)
        }
    }
}

struct ReviewRow: View {
    let phrase: ExtractedPhrase

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(phrase.phrase)
                    .font(.headline)
                Spacer()
                if let level = phrase.cefrLevel {
                    Text(level)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(cefrColor(level).opacity(0.2))
                        .foregroundStyle(cefrColor(level))
                        .clipShape(Capsule())
                }
            }
            Text(phrase.translation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .opacity(phrase.isSelected ? 1.0 : 0.4)
    }

    private func cefrColor(_ level: String) -> Color {
        switch level.uppercased() {
        case "C2": .purple
        case "C1": .red
        case "B2": .orange
        default: .blue
        }
    }
}
