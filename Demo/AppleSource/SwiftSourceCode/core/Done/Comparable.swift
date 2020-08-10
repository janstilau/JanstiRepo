/// A type that can be compared using the relational operators `<`, `<=`, `>=`,
/// and `>`.
/// 如果, 你想要实现一个有序的概念, 那么就应该让里面的元素, 实现 compareable 协议.

/// 算法是固定的行为, 如果能够保证操作的对象, 符合某种抽象了, 算法就能正常的运转. 限制元素符合协议, 就是保证元素符合某种抽象.
/*
 因为, > 的实现, 可以根据 ==, < 的实现推导出来, 所以这个协议的 primitive method 没有包含 > 的声明.
 这也就是 protocol 的设计原则, 能够使用已有方法的, 就用已有的方法. 给实现类的约束越小越好.
 */


public protocol Comparable: Equatable {
    /*
     因为, == 是 Equatable 提出的限制, 所以这里说 < 是唯一的 comparable 的限制.
     */
  static func < (lhs: Self, rhs: Self) -> Bool

    /*
     剩下的这几个, 都可以通过 <, 以及 == 推导出来.
     */
  static func <= (lhs: Self, rhs: Self) -> Bool
  static func >= (lhs: Self, rhs: Self) -> Bool
  static func > (lhs: Self, rhs: Self) -> Bool
}

/*
 可以看到, 下面的操作, 都是根据 primitive 翻转得到的.
 */

extension Comparable {
  @inlinable
  public static func > (lhs: Self, rhs: Self) -> Bool {
    return rhs < lhs
  }

  @inlinable
  public static func <= (lhs: Self, rhs: Self) -> Bool {
    return !(rhs < lhs)
  }
  @inlinable
  public static func >= (lhs: Self, rhs: Self) -> Bool {
    return !(lhs < rhs)
  }
}
