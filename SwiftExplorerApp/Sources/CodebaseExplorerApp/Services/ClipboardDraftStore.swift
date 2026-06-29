import Foundation

struct ClipboardDraftStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let draftURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager

        let directory = baseDirectory ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Codebase Combiner", isDirectory: true)

        draftURL = directory.appendingPathComponent("LastReadyClipboard.json")
    }

    func load() throws -> ClipboardDraft? {
        guard fileManager.fileExists(atPath: draftURL.path) else { return nil }
        let data = try Data(contentsOf: draftURL)
        return try JSONDecoder().decode(ClipboardDraft.self, from: data)
    }

    func save(_ draft: ClipboardDraft) throws {
        let directory = draftURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(draft)
        try data.write(to: draftURL, options: [.atomic])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: draftURL.path) else { return }
        try fileManager.removeItem(at: draftURL)
    }
}
