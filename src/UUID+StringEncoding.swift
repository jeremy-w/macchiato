import Foundation

private typealias StringEncoding = UUID
extension StringEncoding {
    var lowercaseHexString: String {
        return uuidString.lowercased().components(separatedBy: "-").joined()
    }

    init?(lowercaseHexString: String) {
        // E621E1F8-C36C-495A-93FC-0C247A3E6E5F
        // 4 - 2 - 2 - 2 - 6
        let uppercase = lowercaseHexString.uppercased()
        guard uppercase.components(separatedBy: CharacterSet(charactersIn: "0123456789ABCDEF").inverted).count == 1 else {
            preconditionFailure("\(#function): ERROR: non-hex characters in: \(lowercaseHexString)")
        }

        let utf8 = uppercase.utf8
        guard utf8.count == 32 else {
            preconditionFailure("\(#function): ERROR: expected 32 characters corresponding to 16 bytes, "
                + "found \(utf8.count) instead in: \(lowercaseHexString)")
        }

        var rest = utf8
        let chunks: [String] = [4, 2, 2, 2, 6].map { (byteCount: Int) -> String in
            let characterCount = byteCount * 2
            let chunk: String.UTF8View = utf8.prefix(characterCount)
            rest = rest.dropFirst(characterCount)
            guard let string = String(chunk) else {
                preconditionFailure("\(#function): ERROR: failed to stringify chunk: \(chunk)")
            }
            return string
        }
        self.init(uuidString: chunks.joined(separator: "-"))
    }
}
