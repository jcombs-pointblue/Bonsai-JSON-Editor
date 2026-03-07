import SwiftUI
import UniformTypeIdentifiers

/// Document model for JSON files. Stores both the parsed tree and raw text
/// for round-trip fidelity. Never crashes on invalid input.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    /// The parsed JSON tree (nil if parsing failed)
    var root: JSONNode?

    /// Raw text — preserved for round-trip fidelity and for display when parse fails
    var rawText: String

    /// Non-nil if the file failed to parse
    var parseError: JSONParseError?

    init(rawText: String = "{\n  \n}") {
        self.rawText = rawText
        do {
            self.root = try JSONParser.parse(rawText)
            self.parseError = nil
        } catch let error as JSONParseError {
            self.root = nil
            self.parseError = error
        } catch {
            self.root = nil
            self.parseError = JSONParseError(message: error.localizedDescription, line: 0, column: 0)
        }
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.rawText = text
        do {
            self.root = try JSONParser.parse(text)
            self.parseError = nil
        } catch let error as JSONParseError {
            self.root = nil
            self.parseError = error
        } catch {
            self.root = nil
            self.parseError = JSONParseError(message: error.localizedDescription, line: 0, column: 0)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let text: String
        if let root = root {
            text = root.prettyPrinted()
        } else {
            text = rawText
        }
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }

    /// Reparse the raw text
    mutating func reparse() {
        do {
            self.root = try JSONParser.parse(rawText)
            self.parseError = nil
        } catch let error as JSONParseError {
            self.root = nil
            self.parseError = error
        } catch {
            self.root = nil
            self.parseError = JSONParseError(message: error.localizedDescription, line: 0, column: 0)
        }
    }

    /// Update the tree and sync raw text
    mutating func updateRoot(_ newRoot: JSONNode) {
        self.root = newRoot
        self.rawText = newRoot.prettyPrinted()
        self.parseError = nil
    }
}
