import SwiftUI

struct ProfileRowView: View {
    let profile: S3Profile
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .fontWeight(.medium)
                Text(profile.storageType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit connection")
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
