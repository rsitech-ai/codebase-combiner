import SwiftUI

struct FileNodeRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let node: FileNode
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(get: { isSelected }, set: { onToggle($0) })) {
                HStack(spacing: 8) {
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc.text")
                        .foregroundStyle(node.isDirectory ? Color.accentColor : .secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.name)
                            .font(.body.weight(node.isDirectory ? .semibold : .regular))
                            .lineLimit(1)
                        Text(node.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .toggleStyle(.checkbox)
            .buttonStyle(.plain)

            Spacer()

            if !node.isDirectory {
                Text("\(node.tokenCount) tkn")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering || isSelected ? Color.accentColor.opacity(isSelected ? 0.12 : 0.06) : Color.clear)
        )
        .scaleEffect(isHovering && !reduceMotion ? 1.006 : 1, anchor: .leading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: isSelected)
        .onHover { isHovering = $0 }
    }
}
