import Foundation

protocol PhotoUploader {
    func upload(_ photo: Photo, completion: @escaping (Result<URL>) -> Void)
}
