import SwiftUI

/// A single row in the JSON tree, showing key, value, and edit controls
struct JSONNodeRow: View {
    let label: String?
    let node: JSONNode
    let path: [JSONPathComponent]
    let isInObject: Bool
    @Bindable var viewModel: DocumentViewModel
    @Environment(\.undoManager) private var undoManager

    @State private var isEditing = false
    @State private var editText = ""

    var isSelected: Bool {
        viewModel.selectedKeyPath == path
    }

    var body: some View {
        HStack(spacing: 4) {
            // Key label
            if let label = label, isInObject {
                Text(label)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(":")
                    .foregroundStyle(.secondary)
            }

            // Value
            if isEditing {
                TextField("Value", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 80)
                    .onSubmit { commitEdit() }
                    .onExitCommand { isEditing = false }
            } else {
                JSONValueLabel(node: node)
                    .onTapGesture(count: 2) {
                        if node.isLeaf {
                            beginEditing()
                        }
                    }
                    .accessibilityAction(.default) {
                        if node.isLeaf { beginEditing() }
                    }
            }

            Spacer()

            // Child count badge for containers
            if node.isContainer {
                Text(node.childCount == 1 ? "1 item" : "\(node.childCount) items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectNode(at: path)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(label ?? node.typeName)
    }

    private func beginEditing() {
        switch node {
        case .string(let s): editText = s
        case .number(let n):
            if n == n.rounded(.towardZero) && !n.isInfinite && abs(n) < 1e15 {
                editText = String(format: "%.0f", n)
            } else {
                editText = String(n)
            }
        case .bool(let b): editText = b ? "true" : "false"
        case .null: editText = "null"
        default: return
        }
        isEditing = true
    }

    private func commitEdit() {
        isEditing = false
        let newNode = parseEditedValue(editText)
        if newNode != node {
            viewModel.updateNode(at: path, with: newNode, undoManager: undoManager)
        }
    }

    private func parseEditedValue(_ text: String) -> JSONNode {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "null" { return .null }
        if trimmed == "true" { return .bool(true) }
        if trimmed == "false" { return .bool(false) }
        if let n = Double(trimmed) { return .number(n) }
        return .string(trimmed)
    }
}
