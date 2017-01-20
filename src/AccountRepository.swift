protocol AccountRepository {
    /**
     - parameter id: The numeric ID of the user. (*Not* their handle.)

       The special ID "me" fetches the logged-in user's info.
     */
    func account(id: String, completion: @escaping (Result<Account>) -> Void)
}
