protocol AccountRepository {
    /**
     - parameter id: The numeric ID of the user. (*Not* their handle.)

       The special ID "me" fetches the logged-in user's info.
     */
    func account(id: String, completion: @escaping (Result<Account>) -> Void)
    // (jeremy-w/2019-04-14)FIXME: 10Cv5: There's now a public bio vs private profile distinction.

    func follow(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
    func unfollow(accountWithID: String, completion: @escaping (Result<Account>) -> Void)

    func mute(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
    func unmute(accountWithID: String, completion: @escaping (Result<Account>) -> Void)

    func silence(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
    func unsilence(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
}
