import SwiftUI

/// Main help window with feature documentation and jq reference
struct HelpView: View {
    @State private var selectedSection: HelpSection = .gettingStarted

    enum HelpSection: String, CaseIterable, Identifiable {
        case gettingStarted = "Getting Started"
        case treeView = "Tree View"
        case editing = "Editing"
        case searchFilter = "Search & Filter"
        case queryPanel = "Query Panel"
        case toolbar = "Toolbar"
        case keyboardShortcuts = "Keyboard Shortcuts"
        case jqReference = "jq Reference"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .gettingStarted: return "sparkles"
            case .treeView: return "list.bullet.indent"
            case .editing: return "pencil"
            case .searchFilter: return "magnifyingglass"
            case .queryPanel: return "terminal"
            case .toolbar: return "menubar.rectangle"
            case .keyboardShortcuts: return "keyboard"
            case .jqReference: return "function"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(HelpSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedSection {
                    case .gettingStarted:
                        GettingStartedSection()
                    case .treeView:
                        TreeViewSection()
                    case .editing:
                        EditingSection()
                    case .searchFilter:
                        SearchFilterSection()
                    case .queryPanel:
                        QueryPanelSection()
                    case .toolbar:
                        ToolbarHelpSection()
                    case .keyboardShortcuts:
                        KeyboardShortcutsSection()
                    case .jqReference:
                        JQReferenceSection()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Getting Started

private struct GettingStartedSection: View {
    var body: some View {
        HelpSectionHeader(title: "Getting Started", icon: "sparkles")

        HelpParagraph("Bonsai is a native macOS JSON viewer, editor, and query tool. It renders JSON documents as an interactive tree, supports inline editing, and includes a built-in jq query engine for filtering and transforming data.")

        HelpSubheading("Opening Files")
        HelpParagraph("There are several ways to open a JSON file:")
        HelpBullet("Use File > Open (\u{2318}O) to browse for a .json file.")
        HelpBullet("Drag and drop a .json file onto the Bonsai window or Dock icon.")
        HelpBullet("Double-click any .json file in Finder if Bonsai is set as the default handler.")
        HelpBullet("Use \"Paste from Clipboard\" on the welcome screen to create a new document from copied JSON text.")

        HelpSubheading("The Interface")
        HelpParagraph("A Bonsai document window has two main areas:")
        HelpBullet("Tree View (top) \u{2014} an interactive, collapsible outline of your JSON document. Click nodes to select them, expand or collapse objects and arrays, and edit values in place. You can switch to a Source View to see and edit the raw JSON text.")
        HelpBullet("Query Panel (bottom) \u{2014} a jq expression bar with live results. Type a jq expression and see results update as you type. Toggle this panel with the terminal button in the toolbar.")

        HelpSubheading("Document Types")
        HelpParagraph("Bonsai opens files with the .json extension. When you create a new document (File > New), it starts as an empty document that you can paste or type JSON into.")
    }
}

// MARK: - Tree View

private struct TreeViewSection: View {
    var body: some View {
        HelpSectionHeader(title: "Tree View", icon: "list.bullet.indent")

        HelpParagraph("The tree view displays your JSON document as a navigable outline. Each node shows its key (for object properties) or index (for array elements) alongside its value.")

        HelpSubheading("Node Types & Colors")
        HelpParagraph("Values are color-coded for quick identification:")
        HelpBullet("Strings \u{2014} displayed in green with quotation marks.")
        HelpBullet("Numbers \u{2014} displayed in blue.")
        HelpBullet("Booleans \u{2014} displayed in orange (true/false).")
        HelpBullet("Null \u{2014} displayed in gray italic.")
        HelpBullet("Objects \u{2014} shown with a disclosure triangle and child count badge (e.g., \"{ 5 }\").")
        HelpBullet("Arrays \u{2014} shown with a disclosure triangle and element count badge (e.g., \"[ 3 ]\").")

        HelpSubheading("Expanding & Collapsing")
        HelpParagraph("Click the disclosure triangle next to an object or array to expand or collapse it. You can also use the View menu in the toolbar to expand or collapse all nodes at once.")

        HelpSubheading("Selecting Nodes")
        HelpParagraph("Click any node to select it. The toolbar displays the jq-compatible key path to the selected node (e.g., .users[0].name). You can copy this path to the clipboard using the Copy Path button.")

        HelpSubheading("Key Path")
        HelpParagraph("The key path shown in the toolbar uses jq syntax, so you can paste it directly into the query panel. For example, a path like .config.database.host can be pasted into the jq bar to extract that value.")

        HelpSubheading("Source View")
        HelpParagraph("Click the Source toggle (document icon) in the toolbar to switch from the tree view to a raw text editor showing the JSON source. In source view you can:")
        HelpBullet("See the full JSON text, including the effects of Format and Minify.")
        HelpBullet("Edit the JSON directly as text. Changes are reparsed live and reflected in the tree when you switch back.")
        HelpBullet("Copy and paste large sections of JSON freely.")
        HelpParagraph("Click the Source toggle again to return to the tree view.")
    }
}

// MARK: - Editing

private struct EditingSection: View {
    var body: some View {
        HelpSectionHeader(title: "Editing", icon: "pencil")

        HelpParagraph("Bonsai supports inline editing of leaf values (strings, numbers, booleans, and null). Container nodes (objects and arrays) cannot be edited inline but can be modified through their children.")

        HelpSubheading("Inline Editing")
        HelpBullet("Double-click a leaf value to enter edit mode.")
        HelpBullet("Type the new value and press Return to confirm, or press Escape to cancel.")
        HelpBullet("For strings, enter the text without surrounding quotes.")
        HelpBullet("For numbers, enter a valid numeric value (e.g., 42, 3.14, -1).")
        HelpBullet("For booleans, type \"true\" or \"false\".")
        HelpBullet("For null, type \"null\".")

        HelpSubheading("Undo & Redo")
        HelpParagraph("All edits support undo (\u{2318}Z) and redo (\u{21E7}\u{2318}Z). Bonsai preserves the full undo history for the current editing session.")

        HelpSubheading("Formatting")
        HelpParagraph("Use the toolbar buttons to reformat the underlying JSON text:")
        HelpBullet("Format \u{2014} pretty-prints the JSON with 2-space indentation for readability.")
        HelpBullet("Minify \u{2014} compresses the JSON to a single line with no whitespace, reducing file size.")

        HelpSubheading("Parse Errors")
        HelpParagraph("If a file contains invalid JSON, Bonsai shows an error banner with the error location (line and column) and drops into a raw text editor so you can fix the syntax manually. Click \"Retry Parse\" after making corrections.")
    }
}

// MARK: - Search & Filter

private struct SearchFilterSection: View {
    var body: some View {
        HelpSectionHeader(title: "Search & Filter", icon: "magnifyingglass")

        HelpParagraph("The search bar (\u{2318}F) lets you filter the tree view in real time. As you type, the tree hides nodes that don't match, making it easy to find specific keys or values in large documents.")

        HelpSubheading("What Gets Matched")
        HelpBullet("Key names \u{2014} matches against object property names.")
        HelpBullet("String values \u{2014} matches against the text content.")
        HelpBullet("Number values \u{2014} matches against the number's string representation.")
        HelpBullet("Boolean and null values \u{2014} matches against \"true\", \"false\", or \"null\".")

        HelpSubheading("Behavior")
        HelpParagraph("Search is case-insensitive. Parent nodes remain visible when any of their descendants match, so you can always see the structural context of a match. Clear the search field to show all nodes again.")
    }
}

// MARK: - Query Panel

private struct QueryPanelSection: View {
    var body: some View {
        HelpSectionHeader(title: "Query Panel", icon: "terminal")

        HelpParagraph("The query panel at the bottom of the window provides a built-in jq query engine. Type any jq expression and see results update live with a 300ms debounce.")

        HelpSubheading("Using the Query Panel")
        HelpBullet("Toggle the panel \u{2014} click the terminal icon in the toolbar to show or hide the query panel.")
        HelpBullet("Resize \u{2014} drag the divider between the tree view and query panel to adjust the split.")
        HelpBullet("Enter expressions \u{2014} type a jq expression in the text field. Results appear below as formatted JSON.")
        HelpBullet("Copy a path \u{2014} select a node in the tree, click Copy Path, then paste it into the query field as a starting point.")

        HelpSubheading("Results")
        HelpParagraph("Query results are shown as pretty-printed JSON. When a query produces multiple outputs (jq is a generator-based language), each result is displayed separately with a numbered label. You can select and copy result text.")

        HelpSubheading("Errors")
        HelpParagraph("If your query has a syntax error or runtime error, a red error banner appears below the query field with a description of the problem.")

        HelpSubheading("Quick Examples")
        HelpCode(". ", description: "The identity filter \u{2014} returns the entire document.")
        HelpCode(".name", description: "Access a top-level field called \"name\".")
        HelpCode(".users[0]", description: "Get the first element of the \"users\" array.")
        HelpCode(".items | map(.price)", description: "Get all prices from the items array.")
        HelpCode(".[] | select(.active == true)", description: "Filter for elements where active is true.")

        HelpParagraph("See the jq Reference section for comprehensive syntax documentation.")
    }
}

// MARK: - Toolbar

private struct ToolbarHelpSection: View {
    var body: some View {
        HelpSectionHeader(title: "Toolbar", icon: "menubar.rectangle")

        HelpParagraph("The toolbar provides quick access to common operations:")

        HelpSubheading("Format")
        HelpParagraph("Pretty-prints the JSON with 2-space indentation. This reformats the underlying text while preserving the data structure.")

        HelpSubheading("Minify")
        HelpParagraph("Compresses the JSON to its most compact form \u{2014} no whitespace, no newlines. Useful for reducing file size or preparing JSON for transport.")

        HelpSubheading("Copy Path")
        HelpParagraph("Copies the jq-compatible key path of the currently selected node to the clipboard. The path uses dot notation for object keys and bracket notation for array indices (e.g., .users[2].email). Disabled when no node is selected.")

        HelpSubheading("Key Path Display")
        HelpParagraph("Shows the path to the currently selected node in a monospaced badge. Displays \".\" (root) when nothing is selected.")

        HelpSubheading("View Menu")
        HelpBullet("Expand All \u{2014} expands every object and array in the document.")
        HelpBullet("Collapse All \u{2014} collapses everything except the root node.")

        HelpSubheading("Source Toggle")
        HelpParagraph("The document icon switches between the tree view and a raw JSON text editor. Use this to see the full formatted or minified text, or to edit JSON as source.")

        HelpSubheading("Query Panel Toggle")
        HelpParagraph("The terminal icon toggles the jq query panel at the bottom of the window.")
    }
}

// MARK: - Keyboard Shortcuts

private struct KeyboardShortcutsSection: View {
    var body: some View {
        HelpSectionHeader(title: "Keyboard Shortcuts", icon: "keyboard")

        HelpParagraph("Standard macOS keyboard shortcuts are available throughout Bonsai:")

        HelpSubheading("File Operations")
        HelpKeyboardShortcut(key: "\u{2318}N", action: "New document")
        HelpKeyboardShortcut(key: "\u{2318}O", action: "Open file")
        HelpKeyboardShortcut(key: "\u{2318}S", action: "Save")
        HelpKeyboardShortcut(key: "\u{21E7}\u{2318}S", action: "Save As")
        HelpKeyboardShortcut(key: "\u{2318}W", action: "Close window")

        HelpSubheading("Editing")
        HelpKeyboardShortcut(key: "\u{2318}Z", action: "Undo")
        HelpKeyboardShortcut(key: "\u{21E7}\u{2318}Z", action: "Redo")
        HelpKeyboardShortcut(key: "\u{2318}C", action: "Copy")
        HelpKeyboardShortcut(key: "\u{2318}V", action: "Paste")
        HelpKeyboardShortcut(key: "Return", action: "Confirm inline edit")
        HelpKeyboardShortcut(key: "Escape", action: "Cancel inline edit")

        HelpSubheading("Search")
        HelpKeyboardShortcut(key: "\u{2318}F", action: "Focus search field")
    }
}

// MARK: - Reusable Help Components

struct HelpSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.title)
            .fontWeight(.bold)
            .padding(.bottom, 16)
    }
}

struct HelpSubheading: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

struct HelpParagraph: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
    }
}

struct HelpBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\u{2022}")
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 12)
        .padding(.bottom, 4)
    }
}

struct HelpCode: View {
    let code: String
    let description: String

    init(_ code: String, description: String) {
        self.code = code
        self.description = description
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 12)
        .padding(.bottom, 6)
    }
}

struct HelpKeyboardShortcut: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .frame(width: 120, alignment: .leading)
            Text(action)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 12)
        .padding(.bottom, 4)
    }
}
