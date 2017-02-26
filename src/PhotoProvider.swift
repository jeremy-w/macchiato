protocol PhotoProvider {
    func requestOne(completion: @escaping (Photo?) -> Void)
}
