import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

struct AppCommandState: Equatable {
    let hasWorkspace: Bool
    let isScanning: Bool
    let hasSelection: Bool

    var canRefresh: Bool { hasWorkspace && !isScanning }
    var canExport: Bool { hasSelection }
    var copyHelp: String {
        hasSelection
            ? "Copy combined output"
            : "Select at least one file to copy the combined output."
    }

    var saveHelp: String {
        hasSelection
            ? "Save combined output"
            : "Select at least one file to save the combined output."
    }

    var refreshHelp: String {
        if !hasWorkspace {
            return "Choose a folder before refreshing the workspace."
        }
        if isScanning {
            return "Wait for the current workspace scan to finish."
        }
        return "Refresh workspace"
    }
}

@MainActor
final class AppController: ObservableObject {
    typealias FolderPicker = () -> URL?
    typealias SaveDestinationPicker = (CombinedOutputFormat) -> URL?

    let preferences: AppPreferences
    let workspace: WorkspaceStore
    let output: OutputStore

    @Published var isInspectorPresented = true

    private let folderPicker: FolderPicker
    private let saveDestinationPicker: SaveDestinationPicker
    private var cancellables: Set<AnyCancellable> = []
    private var scanTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var rebuildTask: Task<Void, Never>?
    private var hasStarted = false

    var commandState: AppCommandState {
        AppCommandState(
            hasWorkspace: workspace.rootURL != nil,
            isScanning: workspace.isScanning,
            hasSelection: !workspace.selectedFiles.isEmpty
        )
    }

    static func live() -> AppController {
        let preferences = AppPreferences()
        return AppController(
            preferences: preferences,
            workspace: WorkspaceStore(),
            output: OutputStore(
                drafts: ClipboardDraftStore(),
                clipboard: SystemClipboardWriter()
            ),
            folderPicker: Self.presentOpenPanel,
            saveDestinationPicker: Self.presentSavePanel
        )
    }

    init(
        preferences: AppPreferences,
        workspace: WorkspaceStore,
        output: OutputStore,
        folderPicker: @escaping FolderPicker,
        saveDestinationPicker: @escaping SaveDestinationPicker
    ) {
        self.preferences = preferences
        self.workspace = workspace
        self.output = output
        self.folderPicker = folderPicker
        self.saveDestinationPicker = saveDestinationPicker
        output.format = preferences.values.outputMarkdown ? .markdown : .plainText
        bindSharedState()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await output.loadRecoveredDraft()
    }

    func chooseFolder() {
        guard let rootURL = folderPicker() else { return }
        beginScan(rootURL: rootURL)
    }

    func refresh() {
        guard commandState.canRefresh, let rootURL = workspace.rootURL else { return }
        beginScan(rootURL: rootURL)
    }

    func copy() {
        guard commandState.canExport else { return }
        output.copyCurrent()
    }

    func save() {
        guard commandState.canExport,
              let destination = saveDestinationPicker(output.format)
        else { return }

        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            await output.saveCurrent(to: destination)
        }
    }

    func toggleFilters() {
        preferences.values.showFilters.toggle()
    }

    func toggleInspector() {
        isInspectorPresented.toggle()
    }

    func scan(rootURL: URL) async {
        let snapshot = preferences.values
        await workspace.scan(rootURL: rootURL, preferences: snapshot)
    }

    private func beginScan(rootURL: URL) {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            await scan(rootURL: rootURL)
        }
    }

    private func bindSharedState() {
        preferences.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        workspace.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        output.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        preferences.$values
            .map(\.outputMarkdown)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] outputMarkdown in
                guard let self else { return }
                let format: CombinedOutputFormat = outputMarkdown ? .markdown : .plainText
                if output.format.rawValue != format.rawValue {
                    output.format = format
                }
            }
            .store(in: &cancellables)

        output.$format
            .map(\.rawValue)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] rawValue in
                guard let self else { return }
                let outputMarkdown = rawValue == CombinedOutputFormat.markdown.rawValue
                if preferences.values.outputMarkdown != outputMarkdown {
                    preferences.values.outputMarkdown = outputMarkdown
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            workspace.$state
                .map { RebuildSource(files: $0.selectedFiles, rootPath: $0.rootURL?.path) }
                .removeDuplicates(),
            output.$promptPrefix.removeDuplicates(),
            output.$format.map(\.rawValue).removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] source, _, _ in
            self?.rebuildOutput(from: source)
        }
        .store(in: &cancellables)
    }

    private func rebuildOutput(from source: RebuildSource) {
        rebuildTask?.cancel()
        rebuildTask = Task { [weak self] in
            guard let self else { return }
            await output.rebuild(files: source.files, rootPath: source.rootPath)
        }
    }

    private static func presentOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose a workspace root"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func presentSavePanel(format: CombinedOutputFormat) -> URL? {
        let panel = NSSavePanel()
        let markdownType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [format == .markdown ? markdownType : .plainText]
        panel.nameFieldStringValue = format == .markdown ? "combined.md" : "combined.txt"
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private struct RebuildSource: Equatable {
    let files: [FileNode]
    let rootPath: String?
}
