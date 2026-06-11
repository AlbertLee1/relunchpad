import Foundation

struct AppItem: Identifiable, Hashable, Sendable {
    /// Bundle identifier — the stable key used throughout layout persistence.
    let id: String
    let name: String
    let url: URL
}
