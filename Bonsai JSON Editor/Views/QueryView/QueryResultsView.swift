import SwiftUI

/// Displays jq query results as formatted JSON
struct QueryResultsView: View {
    @Bindable var viewModel: DocumentViewModel
    var showRawText: Bool

    var body: some View {
        Group {
            if viewModel.queryResults.isEmpty && viewModel.queryError == nil && !viewModel.queryText.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("The query returned no results.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.queryResults.isEmpty {
                if showRawText {
                    rawTextView
                } else {
                    cardListView
                }
            } else {
                // Empty state when no query entered
                VStack(spacing: 8) {
                    Text("Enter a jq expression above to query your JSON")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Examples: .name, .users[0], .items | map(.price)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var rawTextView: some View {
        let text = viewModel.queryResults
            .map { $0.prettyPrinted() }
            .joined(separator: "\n")

        return ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private var cardListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(viewModel.queryResults.enumerated()), id: \.offset) { index, result in
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.queryResults.count > 1 {
                            Text("Result \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Text(result.prettyPrinted())
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    if index < viewModel.queryResults.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}
