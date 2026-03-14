import SwiftUI

/// Welcome screen shown when no document is open
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon area
            Image(systemName: "tree.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green.gradient)
                .accessibilityHidden(true)

            Text("Bonsai")
                .font(.largeTitle)
                .bold()

            Text("JSON Viewer, Editor & Query Tool")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button {
                    NSDocumentController.shared.openDocument(nil)
                } label: {
                    Label("Open JSON File", systemImage: "doc.badge.plus")
                        .frame(minWidth: 200)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .frame(minWidth: 200)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
            }

            // Recent files
            recentFilesSection

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    @ViewBuilder
    private var recentFilesSection: some View {
        let recentURLs = NSDocumentController.shared.recentDocumentURLs.prefix(5)
        if !recentURLs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Files")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ForEach(Array(recentURLs), id: \.self) { url in
                    Button {
                        NSDocumentController.shared.openDocument(
                            withContentsOf: url,
                            display: true) { _, _, _ in }
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Text(url.deletingLastPathComponent().lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: 400)
        }
    }

    private func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        let controller = NSDocumentController.shared
        guard let _ = try? controller.openUntitledDocumentAndDisplay(true) else { return }
        NotificationCenter.default.post(
            name: .pasteClipboardContent,
            object: nil,
            userInfo: ["content": string]
        )
    }
}

extension Notification.Name {
    static let pasteClipboardContent = Notification.Name("pasteClipboardContent")
}
