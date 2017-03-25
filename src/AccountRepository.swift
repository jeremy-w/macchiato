protocol AccountRepository {
    /**
     - parameter id: The numeric ID of the user. (*Not* their handle.)

       The special ID "me" fetches the logged-in user's info.
     */
    func account(id: String, completion: @escaping (Result<Account>) -> Void)

    // POST /users/follow { "follow_id": 53 }; returns updated account for ID (with you_follow updated)
    func follow(accountWithID: String, completion: @escaping (Result<Account>) -> Void)

    // DELETE /users/follow { "follow_id": 53 }; returns update account for ID (with you_follow updated)
    func unfollow(accountWithID: String, completion: @escaping (Result<Account>) -> Void)

//    func mute(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
//    func unmute(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
//
//    func silence(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
//    func unsilence(accountWithID: String, completion: @escaping (Result<Account>) -> Void)
}
