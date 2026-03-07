//
//  ContentView.swift
//  Bonsai JSON Editor
//
//  Created by JERRY COMBS on 3/7/26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: Bonsai_JSON_EditorDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(Bonsai_JSON_EditorDocument()))
}
