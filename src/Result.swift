enum Result<T> {
    case success(T)
    case failure(Error)
}


// MARK: - Freezing and thawing tried actions
extension Result {
    /// Freezes a throwing action's result.
    static func of(trying action: () throws -> T) -> Result<T> {
        do {
            return .success(try action())
        } catch {
            return .failure(error)
        }
    }

    /// Thaws a throwing action's result.
    func unwrap() throws -> T {
        switch self {
        case let .success(value):
            return value

        case let .failure(error):
            throw error
        }
    }
}
