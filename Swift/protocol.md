* IteratorProtocol

```Swift
public protocol IteratorProtocol {
    associatedtype Element
    mutating func next() -> Self.Element?
}
```
swift 里面的迭代器的功能很有限, 就是 next 函数里面返回对象而已. 相比 hasNext, 以及 getValue的写法, 以及 C++ 中, *, ++, -- 等操作符重载可以带来迭代顺序的改变, Swift 里面的迭代功能变得简单了很多.
迭代器的作用, 就是按照顺序返回数据, 在 Swift 里面, 任何 Sequence 都能返回一个迭代器, 让这个迭代器返回数据. 真正的实现了迭代 Protocol 的类, 必须要在自己的内部, 存储相应的成员变量, 控制迭代的结束条件.
For in loop 的内部实现, 就是获取迭代器, 然后取值赋值, 这是 swift 的语句所隐藏的内部逻辑.

```Swift
   let animals = ["Antelope", "Butterfly", "Camel", "Dolphin"]
   for animal in animals {
       print(animal)
   }
   // 其实内部逻辑是. 注意, 这里 animalIterator 是 var, 因为 next 每次都会修改自己的内部属性.
   var animalIterator = animals.makeIterator()
   while let animal = animalIterator.next() {
       print(animal)
   }
```
真正的实现了 IteratorProtocol 的具体类型, 还是应该每个 Sequence 对应着不同的 Iterator 类, 在这个类里面有着遍历的控制逻辑, 而表现出来的, 则是 IteratorProtocol 接口. 这在 OC 里面, 也是通过 NSEnumerator 父类体现出来的.
