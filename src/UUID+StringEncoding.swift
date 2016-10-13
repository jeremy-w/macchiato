import Foundation

private typealias StringEncoding = UUID
extension StringEncoding {
    var lowercaseHexString: String {
        return uuidString.lowercased().components(separatedBy: "-").joined()
    }
}
