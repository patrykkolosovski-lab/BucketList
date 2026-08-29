import SwiftUI

enum AppPalette {
    static let done = Color(red: 0.18, green: 0.66, blue: 0.35)
    static let nearFuture = Color(red: 0.95, green: 0.52, blue: 0.12)
    static let todo = Color(red: 0.86, green: 0.20, blue: 0.22)
    static let recap = Color(red: 0.88, green: 0.66, blue: 0.16)

    static func color(for section: AppSection) -> Color {
        switch section {
        case .done: done
        case .nearFuture: nearFuture
        case .todo: todo
        case .recap: recap
        }
    }
}
