import SwiftUI

@main
struct Bonsai_JSON_EditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: JSONDocument()) { file in
            ContentView(document: file.$document)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 900, height: 700)
    }
}
