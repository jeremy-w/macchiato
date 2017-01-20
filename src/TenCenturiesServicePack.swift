import Foundation

extension ServicePack {
    static func connectingTenCenturies(session: URLSession) -> ServicePack {
        let sessionManager = TenCenturiesSessionManager(session: session)
        return ServicePack(
            postRepository: TenCenturiesPostRepository(session: session, authenticator: sessionManager),
            accountRepository: TenCenturiesAccountRepository(session: session, authenticator: sessionManager),
            sessionManager: sessionManager,
            requestAuthenticator: sessionManager
        )
    }
}
