import SwiftUI

/// PRD §6.1: unsupported files are skipped and reported as "File not added" with a reason,
/// rather than failing silently or crashing the whole drop.
struct RejectedFilesView: View {
    var files: [ConverterViewModel.RejectedFile]
    var onDismiss: (ConverterViewModel.RejectedFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(files) { file in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("File not added")
                            .font(.subheadline)
                            .bold()
                        Text("\(file.fileName) — \(file.reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        onDismiss(file)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
