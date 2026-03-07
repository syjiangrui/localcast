import Foundation

struct DlnaDevice: Codable, Identifiable, Hashable {
    let index: Int
    let friendlyName: String
    let deviceUrl: String

    var id: String { deviceUrl }
}
