import Foundation

extension NSRange: CustomStringConvertible {
    // The default is just something like _C.NSRange. Useless!
    public var description: String {
        return "NSRange(\(self.location), \(self.length))"
    }
}
