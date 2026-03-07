import SwiftUI

@main
struct Bonsai_JSON_EditorApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        DocumentGroup(newDocument: JSONDocument()) { file in
            ContentView(document: file.$document)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Bonsai Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Window("Bonsai Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 800, height: 600)
    }
}
