import SwiftUI

/// Query input bar with jq expression field and status indicators
struct QueryBarView: View {
    @Bindable var viewModel: DocumentViewModel
    @FocusState private var isQueryFieldFocused: Bool

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
}
