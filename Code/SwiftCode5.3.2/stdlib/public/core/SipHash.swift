
// 这个类, 就是通用 hash 的实现方式, 实现的方式, 不用记忆.
// 具体的实现, 可以理解为, 按照字节进行 hash 值的计算. 具体的过程, 应该是按照通用的算法设计出来的.
extension Hasher {
    // Swift 的这种组织方式, 使得类里面定义功能类, 异常的方便.
    internal struct _State {
        private var v0: UInt64 = 0x736f6d6570736575
        private var v1: UInt64 = 0x646f72616e646f6d
        private var v2: UInt64 = 0x6c7967656e657261
        private var v3: UInt64 = 0x7465646279746573
        private var v4: UInt64 = 0
        private var v5: UInt64 = 0
        private var v6: UInt64 = 0
        private var v7: UInt64 = 0
        internal init(rawSeed: (UInt64, UInt64)) {
            v3 ^= rawSeed.1
            v2 ^= rawSeed.0
            v1 ^= rawSeed.1
            v0 ^= rawSeed.0
        }
    }
}

// 为什么 private 的函数, 可以用到下面的地方.
// Private access restricts the use of an entity to the enclosing declaration, and to extensions of that declaration that are in the same file.
// 最新的 private 更改了访问的范围. 在同一文件的 extension 里面也可以使用了. 这样, 可以放心的在定义里面, 仅仅写数据结构和 init 方法了.
extension Hasher._State {
    private static func _rotateLeft(_ x: UInt64, by amount: UInt64) -> UInt64 {
        return (x &<< amount) | (x &>> (64 - amount))
    }
    
    private mutating func _round() {
        v0 = v0 &+ v1
        v1 = Hasher._State._rotateLeft(v1, by: 13)
        v1 ^= v0
        v0 = Hasher._State._rotateLeft(v0, by: 32)
        v2 = v2 &+ v3
        v3 = Hasher._State._rotateLeft(v3, by: 16)
        v3 ^= v2
        v0 = v0 &+ v3
        v3 = Hasher._State._rotateLeft(v3, by: 21)
        v3 ^= v0
        v2 = v2 &+ v1
        v1 = Hasher._State._rotateLeft(v1, by: 17)
        v1 ^= v2
        v2 = Hasher._State._rotateLeft(v2, by: 32)
    }
    
    private func _extract() -> UInt64 {
        return v0 ^ v1 ^ v2 ^ v3
    }
}

extension Hasher._State {
    @inline(__always)
    internal mutating func compress(_ m: UInt64) {
        v3 ^= m
        _round()
        v0 ^= m
    }
    
    @inline(__always)
    internal mutating func finalize(tailAndByteCount: UInt64) -> UInt64 {
        compress(tailAndByteCount)
        v2 ^= 0xff
        for _ in 0..<3 {
            _round()
        }
        return _extract()
    }
}

extension Hasher._State {
    // 如果, 没有明确的标明 seed 为何物, 那么使用全局的量.
    internal init() {
        self.init(rawSeed: Hasher._executionSeed)
    }
    // 否则, 使用传递过来的 seed. 这里, 还是使用了某些算法
    internal init(seed: Int) {
        let executionSeed = Hasher._executionSeed
        let seed = UInt(bitPattern: seed)
        self.init(rawSeed: (
                    executionSeed.0 ^ UInt64(truncatingIfNeeded: seed),
                    executionSeed.1))
    }
}
