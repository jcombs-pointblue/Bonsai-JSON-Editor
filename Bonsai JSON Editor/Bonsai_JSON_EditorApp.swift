//
//  Bonsai_JSON_EditorApp.swift
//  Bonsai JSON Editor
//
//  Created by JERRY COMBS on 3/7/26.
//

import SwiftUI

@main
struct Bonsai_JSON_EditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: Bonsai_JSON_EditorDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
