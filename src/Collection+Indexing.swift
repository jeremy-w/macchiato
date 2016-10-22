extension Collection {
    func isValid(index: Index) -> Bool {
        return startIndex <= index && index < endIndex
    }
}
