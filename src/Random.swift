import Darwin

func pick<T>(_ array: [T]) -> T {
    return array[randomNumber(in: 0 ..< array.count)]
}

func randomNumber(in range: Range<Int>) -> Int {
    return range.lowerBound + Int(arc4random_uniform(UInt32(range.count)))
}
