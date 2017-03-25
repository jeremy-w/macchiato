import Foundation

class FakeAccountRepository: AccountRepository {
    func account(id: String, completion: @escaping (Result<Account>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(Account.makeFake()))
        }
    }

    func follow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(Account.makeFake()))
        }
    }

    func unfollow(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(Account.makeFake()))
        }
    }
}
