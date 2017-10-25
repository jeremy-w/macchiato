import Foundation

private typealias StringEncoding = UUID
extension StringEncoding {
    var lowercaseHexString: String {
        return uuidString.lowercased().components(separatedBy: "-").joined()
    }

    /**
     Given a UUID string of lowercase hexdigits without any separator,
     builds a UUID.

     Fails if the string has invalid characters, too few, or too many.
     */
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

        let chunkLengths = [4, 2, 2, 2, 6]
        var chunks = [String]()
        var rest = utf8.dropFirst(0)
        for length in chunkLengths {
            let chunk = String(rest.prefix(length))!
            chunks.append(chunk)
            rest = rest.dropFirst(length)
        }
        self.init(uuidString: chunks.joined(separator: "-"))
    }
}
