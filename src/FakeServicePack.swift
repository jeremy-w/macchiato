import Foundation

extension ServicePack {
    static func displayingFakeData() -> ServicePack {
        return ServicePack(
            postRepository: FakePostRepository(),
            accountRepository: FakeAccountRepository(),
            sessionManager: FakeSessionManager(),
            requestAuthenticator: NopRequestAuthenticator()
        )
    }
}
