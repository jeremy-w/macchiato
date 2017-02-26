import Foundation

extension ServicePack {
    static func displayingFakeData() -> ServicePack {
        return ServicePack(
            postRepository: FakePostRepository(),
            accountRepository: FakeAccountRepository(),
            sessionManager: FakeSessionManager(),
            requestAuthenticator: NopRequestAuthenticator(),
            photoUploader: FailingPhotoUploader()
        )
    }
}


class FailingPhotoProvider: PhotoProvider {
    func requestOne(completion: @escaping (Photo?) -> Void) {
        completion(nil)
    }
}


class FailingPhotoUploader: PhotoUploader {
    func upload(_ photo: Photo, completion: @escaping (Result<URL>) -> Void) {
        completion(.failure(notYetImplemented))
    }
}
