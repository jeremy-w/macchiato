import Foundation

struct RateLimit {
    let limit: Int
    let remaining: Int
    let resetsAfter: TimeInterval
    let resetsAt: Date

    init(limit: Int, remaining: Int, resetsAfter: TimeInterval, from: Date = Date()) {
        self.limit = limit
        self.remaining = remaining
        self.resetsAfter = resetsAfter
        self.resetsAt = from + resetsAfter
    }

    init?(headers: [AnyHashable: Any], at date: Date = Date()) {
        var maybeLimit: Int?
        var maybeRemaining: Int?
        var maybeResetsAfter: TimeInterval?

        for header in headers {
            guard let key = header.key as? String
                , let value = header.value as? String
                , let number = Int(value) else {
                continue
            }

            switch key.lowercased() {
            case "x-ratelimit-limit": maybeLimit = number
            case "x-ratelimit-remaining": maybeRemaining = number
            case "x-ratelimit-reset": maybeResetsAfter = TimeInterval(number)
            default: continue
            }
        }

        guard let limit = maybeLimit
        , let remaining = maybeRemaining
        , let resetsAfter = maybeResetsAfter else { return nil }

        self.limit = limit
        self.remaining = remaining
        self.resetsAfter = resetsAfter
        self.resetsAt = date + resetsAfter
    }
}
