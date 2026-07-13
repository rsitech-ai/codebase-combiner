@testable import CodebaseExplorerApp
import XCTest

@MainActor
final class AppCommandStateTests: XCTestCase {
    func testCommandsNameMissingPrerequisites() {
        let empty = AppCommandState(hasWorkspace: false, isScanning: false, hasSelection: false)
        XCTAssertFalse(empty.canRefresh)
        XCTAssertEqual(empty.copyHelp, "Select at least one file to copy the combined output.")

        let ready = AppCommandState(hasWorkspace: true, isScanning: false, hasSelection: true)
        XCTAssertTrue(ready.canRefresh)
        XCTAssertTrue(ready.canExport)
    }

    func testRefreshHelpNamesWhetherWorkspaceOrScanIsBlocking() {
        let missingWorkspace = AppCommandState(hasWorkspace: false, isScanning: false, hasSelection: false)
        XCTAssertEqual(missingWorkspace.refreshHelp, "Choose a folder before refreshing the workspace.")

        let scanning = AppCommandState(hasWorkspace: true, isScanning: true, hasSelection: true)
        XCTAssertEqual(scanning.refreshHelp, "Wait for the current workspace scan to finish.")

        let ready = AppCommandState(hasWorkspace: true, isScanning: false, hasSelection: true)
        XCTAssertEqual(ready.refreshHelp, "Refresh workspace")
    }

    func testSaveHelpNamesMissingSelection() {
        let empty = AppCommandState(hasWorkspace: true, isScanning: false, hasSelection: false)
        XCTAssertEqual(empty.saveHelp, "Select at least one file to save the combined output.")

        let ready = AppCommandState(hasWorkspace: true, isScanning: false, hasSelection: true)
        XCTAssertEqual(ready.saveHelp, "Save combined output")
    }

    func testControllerScansWithPreferenceSnapshotAndRebuildsForSharedInputs() async throws {
        let defaultsName = "AppCommandStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.values.allowList = "swift,md"
        preferences.values.maxFileSizeKB = 768

        let rootURL = URL(fileURLWithPath: "/controller-workspace")
        let file = FileNode(
            name: "App.swift",
            relativePath: "App.swift",
            url: rootURL.appendingPathComponent("App.swift"),
            isDirectory: false,
            tokenCount: 2,
            sizeBytes: 8,
            content: "let app = true"
        )
        let result = TreeLoadResult(
            root: FileNode(
                name: "controller-workspace",
                relativePath: "controller-workspace",
                url: rootURL,
                isDirectory: true,
                children: [file],
                tokenCount: file.tokenCount,
                sizeBytes: file.sizeBytes,
                content: nil
            ),
            summary: ScanSummary()
        )
        let loader = RecordingControllerWorkspaceLoader(result: result)
        let workspace = WorkspaceStore(loader: loader)
        let output = OutputStore(
            drafts: ControllerDraftStore(),
            clipboard: ControllerClipboard()
        )
        let controller = AppController(
            preferences: preferences,
            workspace: workspace,
            output: output,
            folderPicker: { nil },
            saveDestinationPicker: { _ in nil }
        )

        await controller.scan(rootURL: rootURL)
        await waitUntilController { output.currentPayload?.contains("let app = true") == true }

        let receivedPreferences = await loader.receivedPreferences
        XCTAssertEqual(receivedPreferences?.allowList, "swift,md")
        XCTAssertEqual(receivedPreferences?.maxFileSizeKB, 768)
        XCTAssertTrue(controller.commandState.canExport)

        output.promptPrefix = "Review this workspace."
        await waitUntilController { output.currentPayload?.contains("Review this workspace.") == true }

        output.format = .plainText
        await waitUntilController { output.currentPayload?.contains("// File: App.swift") == true }

        workspace.clearSelection()
        await waitUntilController { output.currentPayload == nil }
        XCTAssertFalse(controller.commandState.canExport)
    }
}

private actor RecordingControllerWorkspaceLoader: WorkspaceLoading {
    private(set) var receivedPreferences: AppPreferences.Values?
    private let result: TreeLoadResult

    init(result: TreeLoadResult) {
        self.result = result
    }

    func load(rootURL _: URL, preferences: AppPreferences.Values) async throws -> TreeLoadResult {
        receivedPreferences = preferences
        return result
    }
}

private actor ControllerDraftStore: DraftPersisting {
    private var draft: ClipboardDraft?

    func load() async throws -> ClipboardDraft? { draft }
    func save(_ draft: ClipboardDraft) async throws { self.draft = draft }
    func clear() async throws { draft = nil }
}

@MainActor
private final class ControllerClipboard: ClipboardWriting {
    func write(_: String) throws {}
}

@MainActor
private func waitUntilController(
    _ condition: @escaping @MainActor () -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    for _ in 0 ..< 10000 {
        if condition() { return }
        await Task.yield()
    }
    XCTFail("Condition did not become true", file: file, line: line)
}
