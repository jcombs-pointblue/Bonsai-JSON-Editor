import SwiftUI
import UniformTypeIdentifiers

/// Root content view for a JSON document
struct ContentView: View {
    @Binding var document: JSONDocument
    @State private var viewModel: DocumentViewModel?
    @State private var queryPanelHeight: CGFloat = 250
    @State private var isQueryPanelVisible: Bool = true
    @State private var showSourceView: Bool = false
    @State private var searchText: String = ""

    var body: some View {
        Group {
            if let vm = viewModel {
                documentContent(vm)
            } else {
                ProgressView()
                    .onAppear { setupViewModel() }
            }
        }
        .onChange(of: document.rawText) { _, newValue in
            guard viewModel?.document.rawText != newValue else { return }
            viewModel?.document = document
        }
    }

    @ViewBuilder
    private func documentContent(_ vm: DocumentViewModel) -> some View {
        VStack(spacing: 0) {
            // Main content: Tree view, source view, or error state
            if showSourceView {
                sourceContent(vm)
            } else if let root = vm.document.root {
                treeContent(root, vm: vm)
            } else if let error = vm.document.parseError {
                parseErrorContent(error, vm: vm)
            } else {
                ContentUnavailableView(
                    "Empty Document",
                    systemImage: "doc.text",
                    description: Text("This document is empty.")
                )
            }

            // Query panel
            if isQueryPanelVisible {
                Divider()
                queryPanel(vm)
                    .frame(height: queryPanelHeight)
            }
        }
        .toolbar {
            DocumentToolbarContent(viewModel: vm)

            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showSourceView) {
                    Label("Source", systemImage: "doc.plaintext")
                }
                .help("Toggle between tree view and source text")
            }

            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $isQueryPanelVisible) {
                    Label("Query Panel", systemImage: "terminal")
                }
                .help("Toggle query panel")
            }
        }
        .searchable(text: $searchText, prompt: "Filter by key or value")
        .onChange(of: searchText) { _, newValue in
            vm.searchText = newValue
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    @ViewBuilder
    private func treeContent(_ root: JSONNode, vm: DocumentViewModel) -> some View {
        List {
            JSONTreeView(
                node: root,
                path: [],
                label: "root",
                isInObject: false,
                viewModel: vm
            )
        }
        .listStyle(.sidebar)
        .font(.system(.body, design: .monospaced))
    }

    @ViewBuilder
    private func parseErrorContent(_ error: JSONParseError, vm: DocumentViewModel) -> some View {
        VStack(spacing: 0) {
            // Error banner
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error.errorDescription ?? "Unknown parse error")
                    .font(.callout)
                Spacer()
                Button("Retry Parse") {
                    vm.document.reparse()
                    document = vm.document
                }
                .controlSize(.small)
            }
            .padding(10)
            .background(.red.opacity(0.1))

            // Raw text editor
            TextEditor(text: Binding(
                get: { vm.document.rawText },
                set: { newValue in
                    vm.document.rawText = newValue
                    document.rawText = newValue
                }
            ))
            .font(.system(.body, design: .monospaced))
        }
    }

    @ViewBuilder
    private func queryPanel(_ vm: DocumentViewModel) -> some View {
        VStack(spacing: 0) {
            // Resize handle
            Rectangle()
                .fill(.clear)
                .frame(height: 6)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newHeight = queryPanelHeight - value.translation.height
                            queryPanelHeight = max(100, min(500, newHeight))
                        }
                )

            QueryBarView(viewModel: vm)
            QueryResultsView(viewModel: vm)
        }
    }

    @ViewBuilder
    private func sourceContent(_ vm: DocumentViewModel) -> some View {
        TextEditor(text: Binding(
            get: { vm.document.rawText },
            set: { newValue in
                vm.document.rawText = newValue
                vm.document.reparse()
            }
        ))
        .font(.system(.body, design: .monospaced))
    }

    private func setupViewModel() {
        let vm = DocumentViewModel(document: document)
        vm.onDocumentChanged = { newDoc in
            document = newDoc
        }
        viewModel = vm
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }
            DispatchQueue.main.async {
                NSDocumentController.shared.openDocument(
                    withContentsOf: url,
                    display: true
                ) { _, _, _ in }
            }
        }
        return true
    }
}
