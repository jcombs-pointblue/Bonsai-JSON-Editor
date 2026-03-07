import SwiftUI

/// Toolbar content for the document window
struct DocumentToolbarContent: ToolbarContent {
    @Bindable var viewModel: DocumentViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                viewModel.formatDocument()
            } label: {
                Label("Format", systemImage: "text.alignleft")
            }
            .help("Pretty-print JSON with 2-space indent")

            Button {
                viewModel.minifyDocument()
            } label: {
                Label("Minify", systemImage: "arrow.down.right.and.arrow.up.left")
            }
            .help("Compact JSON with no whitespace")
        }

        ToolbarItem(placement: .automatic) {
            Button {
                let path = viewModel.formattedKeyPath
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            .help("Copy key path of selected node")
            .disabled(viewModel.selectedKeyPath.isEmpty)
        }

        ToolbarItem(placement: .automatic) {
            // Key path display
            Text(viewModel.formattedKeyPath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .help("Path to selected node")
        }

        ToolbarItem(placement: .automatic) {
            Menu {
                Button("Expand All") {
                    viewModel.expandAll()
                }
                Button("Collapse All") {
                    viewModel.collapseAll()
                }
            } label: {
                Label("View", systemImage: "sidebar.squares.leading")
            }
        }
    }
}
