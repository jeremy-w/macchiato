struct ServicePack {
    var postRepository: PostRepository
    var accountRepository: AccountRepository
    var sessionManager: SessionManager
    var requestAuthenticator: RequestAuthenticator
}
