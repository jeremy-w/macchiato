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
        guard let limit = header("x-ratelimit-limit", in: headers)
        , let remaining = header("x-ratelimit-remaining", in: headers)
        , let resetsAfter = header("x-ratelimit-reset", in: headers).map(TimeInterval.init) else { return nil }

        self.limit = limit
        self.remaining = remaining
        self.resetsAfter = resetsAfter
        self.resetsAt = date + resetsAfter
    }
}


private func header(_ key: String, in headers: [AnyHashable: Any]) -> Int? {
    return headers
        .first(where: { ($0.key as? String)?.lowercased() == key }
        )?.value as? Int
}
