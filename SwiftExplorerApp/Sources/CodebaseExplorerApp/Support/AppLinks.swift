import AppKit
import Foundation

enum AppLinks {
    static let supportURL = URL(string: "https://buymeacoffee.com/s1korrrr")!

    @MainActor
    static func openSupportPage() {
        NSWorkspace.shared.open(supportURL)
    }
}
