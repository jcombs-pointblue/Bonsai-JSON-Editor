import SwiftUI

/// Recursive tree view for displaying JSON structure
struct JSONTreeView: View {
    let node: JSONNode
    let path: [JSONPathComponent]
    let label: String?
    let isInObject: Bool
    @Bindable var viewModel: DocumentViewModel
    let isReadOnly: Bool

    init(node: JSONNode, path: [JSONPathComponent] = [], label: String? = nil,
         isInObject: Bool = false, viewModel: DocumentViewModel, isReadOnly: Bool = false) {
        self.node = node
        self.path = path
        self.label = label
        self.isInObject = isInObject
        self.viewModel = viewModel
        self.isReadOnly = isReadOnly
    }

    var body: some View {
        if node.isContainer {
            containerView
        } else {
            leafView
        }
    }

    @ViewBuilder
    private var containerView: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { viewModel.isExpanded(path) },
                set: { _ in viewModel.toggleExpansion(path) }
            )
        ) {
            let children = filteredChildren
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                JSONTreeView(
                    node: child.node,
                    path: path + [child.component],
                    label: child.label,
                    isInObject: isObjectChild,
                    viewModel: viewModel,
                    isReadOnly: isReadOnly
                )
            }
        } label: {
            JSONNodeRow(
                label: label,
                node: node,
                path: path,
                isInObject: isInObject,
                viewModel: viewModel
            )
        }
        .listRowBackground(
            viewModel.selectedKeyPath == path
            ? Color.accentColor.opacity(0.15)
            : Color.clear
        )
    }

    @ViewBuilder
    private var leafView: some View {
        JSONNodeRow(
            label: label,
            node: node,
            path: path,
            isInObject: isInObject,
            viewModel: viewModel
        )
        .listRowBackground(
            viewModel.selectedKeyPath == path
            ? Color.accentColor.opacity(0.15)
            : Color.clear
        )
    }

    private var isObjectChild: Bool {
        if case .object = node { return true }
        return false
    }

    private var filteredChildren: [(label: String, node: JSONNode, component: JSONPathComponent)] {
        let children = node.orderedChildren
        if viewModel.searchText.isEmpty { return children }
        return children.filter { child in
            viewModel.subtreeMatchesSearch(child.node, key: child.label)
        }
    }
}
