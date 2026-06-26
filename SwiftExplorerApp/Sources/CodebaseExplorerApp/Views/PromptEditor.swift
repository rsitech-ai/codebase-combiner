import SwiftUI

struct PromptEditor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var prompt: String
    let tokenCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Prompt Prefix", systemImage: "rectangle.and.pencil.and.ellipsis")
                    .font(.headline)
                Spacer()
                Text("~\(tokenCount) tokens")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .frame(minHeight: 120)
                    .padding(10)
                    .scrollContentBackground(.hidden)

                if prompt.isEmpty {
                    Text("Optional instructions to place above the selected files...")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.separator.opacity(0.45))
            }
        }
        .padding(12)
        .appSurface(cornerRadius: 12)
        .hoverLift()
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: prompt.isEmpty)
    }
}
