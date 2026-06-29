@testable import CodebaseExplorerApp
import Foundation
import XCTest

final class ClipboardDraftStoreTests: XCTestCase {
    func testSaveLoadAndClearDraft() throws {
        try withTemporaryDirectory { root in
            let store = ClipboardDraftStore(baseDirectory: root)
            let draft = ClipboardDraft(
                text: "ready payload",
                format: .markdown,
                fileCount: 2,
                tokenCount: 12,
                byteCount: 128,
                rootPath: "/tmp/project",
                generatedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )

            try store.save(draft)
            XCTAssertEqual(try store.load(), draft)

            try store.clear()
            XCTAssertNil(try store.load())
        }
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let resolvedRoot = root.resolvingSymlinksInPath()
    defer {
        try? FileManager.default.removeItem(at: resolvedRoot)
    }
    try body(resolvedRoot)
}
