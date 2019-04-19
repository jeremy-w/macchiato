import Foundation

class FakeAccountRepository: AccountRepository {
    func bioForPersona(id: String, completion: @escaping (Result<Account>) -> Void) {
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


    func mute(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(Account.makeFake()))
        }
    }

    func unmute(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(Account.makeFake()))
        }
    }


    func silence(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(Account.makeFake()))
        }
    }

    func unsilence(accountWithID: String, completion: @escaping (Result<Account>) -> Void) {
        DispatchQueue.main.async {
            completion(.success(Account.makeFake()))
        }
    }
}
