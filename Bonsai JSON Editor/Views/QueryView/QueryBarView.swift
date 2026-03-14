import SwiftUI
import UniformTypeIdentifiers

/// Query input bar with jq expression field and status indicators
struct QueryBarView: View {
    @Bindable var viewModel: DocumentViewModel
    @Binding var showRawText: Bool
    @FocusState private var isQueryFieldFocused: Bool
    @State private var showCopiedFeedback: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("jq")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

                TextField("Enter jq expression...", text: $viewModel.queryText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isQueryFieldFocused)
                    .onSubmit {
                        viewModel.runQuery(viewModel.queryText)
                    }
                    .onChange(of: viewModel.queryText) { _, newValue in
                        viewModel.runQuery(newValue)
                    }

                if viewModel.isQuerying {
                    ProgressView()
                        .controlSize(.small)
                }

                if !viewModel.queryResults.isEmpty {
                    Text("\(viewModel.queryResults.count) result\(viewModel.queryResults.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        copyResults()
                    } label: {
                        Label(showCopiedFeedback ? "Copied" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .controlSize(.small)
                    .help("Copy all results to clipboard")

                    Button {
                        exportResults()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .controlSize(.small)
                    .help("Save results to a JSON file")

                    Toggle(isOn: $showRawText) {
                        Label("Text", systemImage: showRawText ? "doc.plaintext" : "list.bullet.rectangle")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .help(showRawText ? "Show results as cards" : "Show results as raw text")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)

            // Error banner
            if let error = viewModel.queryError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            }
        }
    }

    private func formattedResults() -> String {
        let results = viewModel.queryResults
        if results.count == 1 {
            return results[0].prettyPrinted()
        }
        // Multiple results: output each on its own line, matching jq CLI behavior
        return results.map { $0.prettyPrinted() }.joined(separator: "\n")
    }

    private func copyResults() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedResults(), forType: .string)
        showCopiedFeedback = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showCopiedFeedback = false
        }
    }

    private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "results.json"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let text = formattedResults()
            do {
                try text.data(using: .utf8)?.write(to: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
