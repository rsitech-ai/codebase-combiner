import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var controller: AppController
    @ObservedObject private var preferences: AppPreferences
    @ObservedObject private var workspace: WorkspaceStore
    @ObservedObject private var output: OutputStore
    @SceneStorage("cc_sidebarWidth") private var sidebarWidth: Double = 320
    @SceneStorage("cc_previewWidth") private var previewWidth: Double = 460
    @State private var sidebarDragStartWidth: Double = 320
    @State private var previewDragStartWidth: Double = 460
    @State private var isResizingSidebar = false
    @State private var isResizingPreview = false
    @State private var showToast = false
    @State private var toastDismissWorkItem: DispatchWorkItem?

    private let estimator = TokenEstimator()
    private let previewCharacterLimit = 20000

    init(controller: AppController) {
        _controller = ObservedObject(wrappedValue: controller)
        _preferences = ObservedObject(wrappedValue: controller.preferences)
        _workspace = ObservedObject(wrappedValue: controller.workspace)
        _output = ObservedObject(wrappedValue: controller.output)
    }

    private var rootURL: URL? { workspace.rootURL }
    private var rootNode: FileNode? { workspace.rootNode }
    private var allFileNodes: [FileNode] { workspace.allFiles }
    private var selectedFileNodes: [FileNode] { workspace.selectedFiles }
    private var selectedBytes: Int { workspace.selectedBytes }
    private var selectedTokenCount: Int { workspace.selectedTokens }
    private var selectedIDs: Set<String> { workspace.selectedIDs }
    private var promptPrefix: String { output.promptPrefix }
    private var outputMarkdown: Bool { output.format == .markdown }
    private var isLoading: Bool { workspace.isScanning }

    private var showFilters: Bool { preferences.values.showFilters }
    private var restoredDraft: ClipboardDraft? { output.recoveredDraft }

    private var promptPrefixBinding: Binding<String> {
        Binding(
            get: { output.promptPrefix },
            set: { output.promptPrefix = $0 }
        )
    }

    private var outputMarkdownBinding: Binding<Bool> {
        Binding(
            get: { output.format == .markdown },
            set: { output.format = $0 ? .markdown : .plainText }
        )
    }

    private var showFiltersBinding: Binding<Bool> {
        Binding(
            get: { preferences.values.showFilters },
            set: { isPresented in
                if preferences.values.showFilters != isPresented {
                    controller.toggleFilters()
                }
            }
        )
    }

    private var allowListBinding: Binding<String> {
        Binding(
            get: { preferences.values.allowList },
            set: { preferences.values.allowList = $0 }
        )
    }

    private var excludeListBinding: Binding<String> {
        Binding(
            get: { preferences.values.excludeList },
            set: { preferences.values.excludeList = $0 }
        )
    }

    private var maxFileSizeBinding: Binding<Double> {
        Binding(
            get: { preferences.values.maxFileSizeKB },
            set: { preferences.values.maxFileSizeKB = $0 }
        )
    }

    private var skipHiddenBinding: Binding<Bool> {
        Binding(
            get: { preferences.values.skipHidden },
            set: { preferences.values.skipHidden = $0 }
        )
    }

    private var clearConfirmationBinding: Binding<Bool> {
        Binding(
            get: { output.isClearConfirmationPresented },
            set: { isPresented in
                if !isPresented {
                    output.cancelClearRecoveredOutput()
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: sidebarWidth)
                .background(.bar)

            sidebarGrabber

            centerWorkspace

            if controller.isInspectorPresented {
                previewGrabber

                outputPreview
                    .frame(width: previewWidth)
                    .background(.bar)
            }
        }
        .frame(minWidth: 1320, minHeight: 820)
        .overlay(alignment: .topTrailing) {
            if showToast {
                copyToast
                    .padding(.top, 18)
                    .padding(.trailing, 22)
                    .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82), value: showToast)
        .task {
            await controller.start()
        }
        .alert("Clear Saved Output?", isPresented: clearConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                output.cancelClearRecoveredOutput()
            }
            Button("Clear", role: .destructive) {
                Task {
                    await output.confirmClearRecoveredOutput()
                }
            }
        } message: {
            Text("This removes the saved recovery copy from this Mac. Your source files are not changed.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Codebase Combiner")
                    .font(.title2.weight(.semibold))
                Text(rootURL?.path ?? "Choose a workspace to begin.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Label(controller.displayStatus, systemImage: isLoading ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.secondary)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: 280, alignment: .trailing)
                .contentTransition(.opacity)
        }
        .padding(.bottom, 2)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label("Workspace", systemImage: "sidebar.left")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button(action: controller.chooseFolder) {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .help("Choose folder")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            explorer

            sidebarFooter
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Button {
                    AppLinks.openSupportPage()
                } label: {
                    Label("Support", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
            .controlSize(.small)
        }
        .padding(12)
    }

    private var controlBar: some View {
        ViewThatFits(in: .horizontal) {
            fullControlBar
            compactControlBar
        }
        .padding(10)
        .frame(minHeight: 50)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .hoverLift()
    }

    private var fullControlBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("Choose", systemImage: "folder", action: controller.chooseFolder)

                actionButton("Refresh", systemImage: "arrow.clockwise", action: controller.refresh)
                    .disabled(!controller.commandState.canRefresh)
                    .help(controller.commandState.refreshHelp)
            }
            .frame(minWidth: 220, alignment: .leading)

            Divider()
                .frame(height: 20)

            HStack(spacing: 8) {
                actionButton("All", systemImage: "checkmark.circle", action: workspace.selectAll)
                    .disabled(rootNode == nil)
                actionButton("Clear", systemImage: "xmark.circle", action: workspace.clearSelection)
                    .disabled(selectedIDs.isEmpty)
            }
            .frame(width: 154, alignment: .leading)

            Divider()
                .frame(height: 20)

            HStack(spacing: 8) {
                if selectedFileNodes.isEmpty {
                    actionButton("Copy", systemImage: "doc.on.doc", action: {})
                        .disabled(true)
                        .help(controller.commandState.copyHelp)
                } else {
                    Button(action: copyCombined) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(!controller.commandState.canExport)
                    .help(controller.commandState.copyHelp)
                }

                actionButton("Save", systemImage: "square.and.arrow.down", action: saveCombined)
                    .disabled(!controller.commandState.canExport)
                    .help(controller.commandState.saveHelp)
            }
            .frame(width: 176, alignment: .leading)

            Spacer()

            HStack(spacing: 10) {
                Picker("Output", selection: outputMarkdownBinding) {
                    Text("Markdown").tag(true)
                    Text("Plain Text").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .labelsHidden()

                Toggle(isOn: showFiltersBinding) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .toggleStyle(.button)
                .frame(width: 96)
                .help("Show filters")
            }
            .frame(width: 276, alignment: .trailing)
        }
    }

    private var compactControlBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("Choose", systemImage: "folder", action: controller.chooseFolder)
                actionButton("Refresh", systemImage: "arrow.clockwise", action: controller.refresh)
                    .disabled(!controller.commandState.canRefresh)
                    .help(controller.commandState.refreshHelp)
                actionButton("All", systemImage: "checkmark.circle", action: workspace.selectAll)
                    .disabled(rootNode == nil)
                actionButton("Clear", systemImage: "xmark.circle", action: workspace.clearSelection)
                    .disabled(selectedIDs.isEmpty)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if selectedFileNodes.isEmpty {
                    actionButton("Copy", systemImage: "doc.on.doc", action: {})
                        .disabled(true)
                        .help(controller.commandState.copyHelp)
                } else {
                    Button(action: copyCombined) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(!controller.commandState.canExport)
                    .help(controller.commandState.copyHelp)
                }

                actionButton("Save", systemImage: "square.and.arrow.down", action: saveCombined)
                    .disabled(!controller.commandState.canExport)
                    .help(controller.commandState.saveHelp)

                Spacer(minLength: 0)

                Picker("Output", selection: outputMarkdownBinding) {
                    Text("Markdown").tag(true)
                    Text("Plain Text").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
                .labelsHidden()

                Toggle(isOn: showFiltersBinding) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .toggleStyle(.button)
                .frame(width: 96)
                .help("Show filters")
            }
        }
    }

    private var promptEditor: some View {
        PromptEditor(prompt: promptPrefixBinding, tokenCount: estimator.estimateTokens(in: promptPrefix))
    }

    private var filters: some View {
        FiltersView(
            allowList: allowListBinding,
            excludeList: excludeListBinding,
            maxFileSizeKB: maxFileSizeBinding,
            skipHidden: skipHiddenBinding,
            onApply: controller.refresh
        )
    }

    private var explorer: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ScanningIndicator()
                    Text("Scanning files...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let root = rootNode {
                List {
                    OutlineGroup([root], children: \.childrenOrNil) { node in
                        FileNodeRow(
                            node: node,
                            isSelected: isSelected(node),
                            onToggle: { newValue in toggle(node: node, isOn: newValue) }
                        )
                    }
                }
                .listStyle(.sidebar)
                .animation(reduceMotion ? nil : .spring(response: 0.25), value: selectedIDs)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                VStack(spacing: 10) {
                    EmptyStateSymbol(systemImage: "folder.badge.questionmark")
                    Text("No folder selected")
                        .font(.title3.weight(.semibold))
                    Text("Pick a folder to view files and token counts.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: controller.chooseFolder) {
                        Label("Choose Folder", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
                }
                .padding(22)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: isLoading)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: rootNode?.id)
    }

    private var statsBar: some View {
        StatsBar(
            totalFiles: allFileNodes.count,
            selectedFiles: selectedFileNodes.count,
            tokenCount: selectedTokenCount + estimator.estimateTokens(in: promptPrefix),
            bytes: selectedBytes
        )
    }

    private var selectedPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Selected Files", systemImage: "checkmark.circle")
                    .font(.headline)
                Spacer()
                Text("\(selectedFileNodes.count) items")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if !selectedFileNodes.isEmpty {
                    Button {
                        copyCombined()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!controller.commandState.canExport)
                    .help(controller.commandState.copyHelp)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    Button {
                        saveCombined()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!controller.commandState.canExport)
                    .help(controller.commandState.saveHelp)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }

            if selectedFileNodes.isEmpty {
                VStack(spacing: 8) {
                    EmptyStateSymbol(systemImage: "doc.text.magnifyingglass")
                    Text("No Files Selected")
                        .font(.headline)
                    Text("Choose files from the sidebar to preview the combined payload.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 128)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(selectedFileNodes, id: \.id) { file in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                Text(file.relativePath)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("\(file.tokenCount) tkn")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Text(file.displaySize)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(2)
                }
                .frame(maxHeight: 180)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(12)
        .appSurface(cornerRadius: 12, emphasized: !selectedFileNodes.isEmpty)
        .hoverLift()
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84), value: selectedIDs)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84), value: selectedFileNodes.isEmpty)
    }

    @ViewBuilder
    private var restoredDraftBanner: some View {
        if let draft = restoredDraft {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Last ready copy is saved")
                        .font(.headline)
                    Text("\(draft.fileCount) files • \(draft.formatLabel) • \(draft.tokenCount) tokens • \(formattedDraftDate(draft.generatedAt))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    copyRestoredDraft()
                } label: {
                    Label("Copy Last", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    clearRestoredDraft()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .appSurface(cornerRadius: 12, emphasized: selectedFileNodes.isEmpty)
            .hoverLift()
            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98)))
        }
    }

    private var centerWorkspace: some View {
        VStack(spacing: 12) {
            header
            controlBar
            ScrollView {
                VStack(spacing: 12) {
                    promptEditor
                    if showFilters {
                        filters
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                    }
                    selectedPreview
                    restoredDraftBanner
                    statsBar
                }
                .padding(.bottom, 16)
            }
        }
        .padding(16)
        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86), value: showFilters)
    }

    private var outputPreview: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Label("Output Preview", systemImage: "doc.text.magnifyingglass")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(outputPreviewSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if rawOutputPreviewText.isEmpty {
                VStack(spacing: 10) {
                    EmptyStateSymbol(systemImage: "doc.plaintext")
                    Text("Nothing selected")
                        .font(.headline)
                    Text("Select files in the workspace to preview the exact payload.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(22)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Label(outputPreviewFormatLabel, systemImage: outputPreviewFormatIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if selectedFileNodes.isEmpty {
                            Button {
                                copyRestoredDraft()
                            } label: {
                                Label("Copy Last", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(!controller.commandState.canExport)
                            .help(controller.commandState.copyHelp)
                        } else {
                            Button {
                                copyCombined()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button {
                                saveCombined()
                            } label: {
                                Label("Save", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!controller.commandState.canExport)
                            .help(controller.commandState.saveHelp)
                        }
                    }
                    .padding(12)

                    Divider()

                    ScrollView([.vertical, .horizontal]) {
                        Text(outputPreviewText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineSpacing(2)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .background(.quaternary.opacity(0.2))
                }
            }
        }
        .frame(minWidth: 300, maxHeight: .infinity)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private var copyToast: some View {
        Label("Copied", systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.primary)
            .appSurface(cornerRadius: 20, emphasized: true)
    }

    private func copyRestoredDraft() {
        output.copyRecovered()
        if output.status == "Copied the recovered output." {
            showCopiedToast()
        }
    }

    private func clearRestoredDraft() {
        output.requestClearRecoveredOutput()
    }

    private func formattedDraftDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Selection helpers

    private func isSelected(_ node: FileNode) -> Bool {
        if node.isDirectory {
            let childIDs = gatherFileIDs(node)
            guard !childIDs.isEmpty else { return false }
            let selectedChildren = childIDs.filter { selectedIDs.contains($0) }
            return selectedChildren.count == childIDs.count
        }
        return selectedIDs.contains(node.id)
    }

    private func toggle(node: FileNode, isOn: Bool) {
        workspace.toggle(node: node, isOn: isOn)
    }

    private func gatherFileIDs(_ node: FileNode) -> [String] {
        if node.isDirectory {
            return node.children.flatMap { gatherFileIDs($0) }
        }
        return [node.id]
    }

    // MARK: - Actions

    private func copyCombined() {
        controller.copy()
        if output.status == "Copied the current output." {
            showCopiedToast()
        }
    }

    private func saveCombined() {
        controller.save()
    }

    private var outputPreviewSubtitle: String {
        if !selectedFileNodes.isEmpty {
            return "\(selectedFileNodes.count) files • \(selectedTokenCount + estimator.estimateTokens(in: promptPrefix)) tokens"
        }
        if let draft = restoredDraft {
            return "\(draft.fileCount) files • last copy"
        }
        return "No selection"
    }

    private var outputPreviewFormatLabel: String {
        if !selectedFileNodes.isEmpty {
            return outputMarkdown ? "Markdown" : "Plain Text"
        }
        return restoredDraft?.formatLabel ?? "Preview"
    }

    private var outputPreviewFormatIcon: String {
        outputPreviewFormatLabel == "Markdown" ? "curlybraces.square" : "text.alignleft"
    }

    private var rawOutputPreviewText: String {
        output.visiblePayload ?? ""
    }

    private var outputPreviewText: String {
        let text = rawOutputPreviewText
        guard text.count > previewCharacterLimit else { return text }
        return "\(text.prefix(previewCharacterLimit))\n\n… Preview truncated for speed. Copy or save to use the full output."
    }

    private func showCopiedToast() {
        showToast = true
        toastDismissWorkItem?.cancel()
        let work = DispatchWorkItem {
            showToast = false
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    private var sidebarGrabber: some View {
        splitGrabber(isActive: isResizingSidebar) { value in
            if !isResizingSidebar {
                sidebarDragStartWidth = sidebarWidth
            }
            isResizingSidebar = true
            let newWidth = sidebarDragStartWidth + Double(value.translation.width)
            sidebarWidth = min(max(220, newWidth), 600)
        } onEnded: { _ in
            isResizingSidebar = false
        }
    }

    private var previewGrabber: some View {
        splitGrabber(isActive: isResizingPreview) { value in
            if !isResizingPreview {
                previewDragStartWidth = previewWidth
            }
            isResizingPreview = true
            let newWidth = previewDragStartWidth - Double(value.translation.width)
            previewWidth = min(max(300, newWidth), 760)
        } onEnded: { _ in
            isResizingPreview = false
        }
    }

    private func splitGrabber(
        isActive: Bool,
        onChanged: @escaping (DragGesture.Value) -> Void,
        onEnded: @escaping (DragGesture.Value) -> Void
    ) -> some View {
        Rectangle()
            .fill(isActive ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.25))
            .frame(width: 1)
            .frame(width: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(onChanged)
                    .onEnded(onEnded)
            )
            .overlay(
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1),
                alignment: .trailing
            )
    }
}
