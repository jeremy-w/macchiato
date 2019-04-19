protocol AccountRepository {
    /**
     - parameter id: The numeric ID of the persona. (*Not* their handle.)
     */
    func bioForPersona(id: String, completion: @escaping (Result<Account>) -> Void)

    func follow(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
    func unfollow(accountWithID: String, completion: @escaping (Result<Account>) -> Void)

    func mute(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
    func unmute(accountWithID: String, completion: @escaping (Result<Account>) -> Void)

    func silence(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
    func unsilence(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
}
