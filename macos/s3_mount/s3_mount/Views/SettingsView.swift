import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        Form {
            Section("General") {
                Text("S3 Browser Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450)
        .padding()
    }
}
