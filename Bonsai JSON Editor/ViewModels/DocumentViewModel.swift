import SwiftUI

/// ViewModel for a JSON document, managing selection, expansion, query, and editing state.
@Observable
class DocumentViewModel {
    var document: JSONDocument {
        didSet { onDocumentChanged?(document) }
    }
    var selectedKeyPath: [JSONPathComponent] = []
    var expandedNodes: Set<[JSONPathComponent]> = []
    var searchText: String = ""
    var queryText: String = ""
    var queryResults: [JSONNode] = []
    var queryError: String? = nil
    var isQuerying: Bool = false

    /// Called whenever the document is modified by the viewModel, so ContentView can sync back to the binding.
    var onDocumentChanged: ((JSONDocument) -> Void)?

    private var debounceTask: Task<Void, Never>?

    init(document: JSONDocument) {
        self.document = document
        // Auto-expand root
        expandedNodes.insert([])
    }

    // MARK: - Key path display

    var formattedKeyPath: String {
        if selectedKeyPath.isEmpty { return "." }
        var result = ""
        for component in selectedKeyPath {
            result += component.displayString
        }
        return result
    }

    // MARK: - Selection

    func selectNode(at path: [JSONPathComponent]) {
        selectedKeyPath = path
    }

    var selectedNode: JSONNode? {
        document.root?.node(at: selectedKeyPath)
    }

    // MARK: - Expansion

    func isExpanded(_ path: [JSONPathComponent]) -> Bool {
        expandedNodes.contains(path)
    }

    func toggleExpansion(_ path: [JSONPathComponent]) {
        if expandedNodes.contains(path) {
            expandedNodes.remove(path)
        } else {
            expandedNodes.insert(path)
        }
    }

    func expandAll() {
        guard let root = document.root else { return }
        expandAllRecursive(root, path: [])
    }

    func collapseAll() {
        expandedNodes.removeAll()
        expandedNodes.insert([]) // keep root expanded
    }

    private func expandAllRecursive(_ node: JSONNode, path: [JSONPathComponent]) {
        guard node.isContainer else { return }
        expandedNodes.insert(path)
        for child in node.orderedChildren {
            expandAllRecursive(child.node, path: path + [child.component])
        }
    }

    // MARK: - Editing

    func updateNode(at path: [JSONPathComponent], with newValue: JSONNode, undoManager: UndoManager?) {
        guard let root = document.root else { return }
        let oldRoot = root
        let newRoot = root.replacing(at: path, with: newValue)
        document.updateRoot(newRoot)

        undoManager?.registerUndo(withTarget: self) { vm in
            vm.document.updateRoot(oldRoot)
        }
    }

    // MARK: - Formatting

    func formatDocument() {
        guard let root = document.root else { return }
        document.rawText = root.prettyPrinted()
    }

    func minifyDocument() {
        guard let root = document.root else { return }
        document.rawText = root.minified()
    }

    // MARK: - Search / Filter

    /// Returns whether a node at the given path matches the current search text
    func matchesSearch(_ node: JSONNode, key: String?) -> Bool {
        guard !searchText.isEmpty else { return true }
        let search = searchText.lowercased()

        // Match key name
        if let key = key, key.lowercased().contains(search) {
            return true
        }

        // Match value
        switch node {
        case .string(let s): return s.lowercased().contains(search)
        case .number(let n): return String(n).contains(search)
        case .bool(let b): return (b ? "true" : "false").contains(search)
        case .null: return "null".contains(search)
        default: return false
        }
    }

    /// Recursively checks if a node or any of its children match the search
    func subtreeMatchesSearch(_ node: JSONNode, key: String?) -> Bool {
        guard !searchText.isEmpty else { return true }
        if matchesSearch(node, key: key) { return true }
        for child in node.orderedChildren {
            if subtreeMatchesSearch(child.node, key: child.label) { return true }
        }
        return false
    }

    // MARK: - jq Query

    func runQuery(_ text: String) {
        debounceTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            queryResults = []
            queryError = nil
            isQuerying = false
            return
        }

        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isQuerying = true
            let inputRoot = document.root ?? .null

            let result: Result<[JSONNode], Error> = await Task.detached(priority: .userInitiated) {
                do {
                    let results = try JQEvaluator.evaluate(expression: text, input: inputRoot)
                    return .success(results)
                } catch {
                    return .failure(error)
                }
            }.value

            guard !Task.isCancelled else { return }

            switch result {
            case .success(let results):
                queryResults = results
                queryError = nil
            case .failure(let error):
                queryResults = []
                queryError = error.localizedDescription
            }
            isQuerying = false
        }
    }
}
