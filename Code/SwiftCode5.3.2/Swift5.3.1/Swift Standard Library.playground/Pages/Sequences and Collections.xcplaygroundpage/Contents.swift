/*:
[Table of Contents](Table%20of%20Contents) | [Previous](@previous) | [Next](@next)
****
# Sequences and Collections
The Swift standard library is built on many small protocols that define the behavior and interface required of conforming types. These protocols combine in ways that express powerful abstractions. In addition to specifying requirements, many of these protocols have extensions that implement some of these requirements as well as other functionality that conforming types can take advantage of. 

For example, because collections like `Array`, `Dictionary`, and `Set` share some functionality, they adopt a set of related protocols. Some of these protocols, such as `Sequence` and `Collection`, define iteration and indexing, making it simple to write generic code that precisely expresses the functionality required to complete a task.

In this chapter, you will learn how to consume and manipulate various collection types. Then you'll use standard library protocols to build your own collection type, and use it to implement features in a photo timeline app.

****
[Table of Contents](Table%20of%20Contents) | [Previous](@previous) | [Next](@next)
*/
// 标准库, 是一个个小的协议组织起来的. 这些小的协议, 各自代表着各自的抽象. 协议, 可能会实现某些方法, 也可以从现有的方法里面, 扩展一些方法.
// Sequence 主要的工作, 是迭代
// Collection, 主要的工作是, 下标取值.
