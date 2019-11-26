import UIKit

// let 常量, var 变量.
// OC 里面, 必须特殊的指明 const 才可以. 对于对象, 可以用 readonly 模拟属性不可写.

let maxNumberLoginAttempt = 10
var currentLoginAttempt = 0
//maxNumberLoginAttempt = 100 // 报错
currentLoginAttempt = 1

let x = 0.0, y = 2.0, z = 3.0, name = "Justin"
print("x = \(x), y = \(y), z = \(z)")

// short, char, int 的长度和机器相关, 而 Int32, Int16, 这些, 明确的定义了长度. Int 则是当前机器的平台长度相同的类型的长度.
// Int, Double 其实是一个类型, 所以才能够在上面进行 .max, .min 的读取, 根据类型的操作符重载, 才能进行各种操作符的操作. 如果类型没有定义相关类型的操作符, 那么这个操作符就会报错.
// Bool, Bool 只会有 true, false. 如果还想用 指针有值, 不为 nil, 不为 0 代替 Bool, swift 现在不允许了. 必须明确的用, 可以返回 Bool 的表达式代替.
// 这里有个疑问, 如果从外界得到的值, 它的范围, 大于了 Int 的范围, 那会直接让程序 crash 吗?


// 元组, tuple, 把多个值合并成为单一的复合型的值. 可以指定每一个元素的名称, 也可以用下标的方式进行引用. 元祖在定义了之后, 不能修改值得类型, 如果是 var 定义的元组, 可以修改元组内的各个成员的值. 但不能是类型.
// 最主要的用处, 还是在函数返回值那里.
// 简单的数据结构, 可以用元组来进行代替, 这样可以大大减少对象类型的定义.

func writeFile(content: String) -> (errorCode:Int, errorMessage: String) {
    return (1, "没有权限")
}


// Optional, 这里有一个值, 它是特定类型的, 或者, 这里根本没有值. nil 不是指针, 而是一个特殊值, 其实, 它是一个 enum 的 case 值.
// ! 表示, 明确的知道里面有值, 进行展开. !一定是确定安全的情况下使用, 例如, 已经进行了 nil 的判断了.
// option 绑定. 一种语言提供的, 判断 option 里面有没有值的方法.
// option 可选链. 可选项后面加 ? 来调用. 可选链的得到的值, 也是一个 optional 值.
// 本质上, 这是一个 enum类型, case none, case some.
var str: Optional<String> = "abc"
var stroption: String? = "ablc" // 所以说,  String? 是语言层面上对于上面的语句的包装.
stroption = str // 这里没有报错. 说明是一个类型.
str.unsafelyUnwrapped // 这个值可以得到 some 中 association 的值, 这就是 optional 的展开做的事情.
str = .none
/*
 OC 中的 nil 是无类型的指针.
 OC 中 nil 只能用在对象上, 而其他地方, 只能用特殊值, NSNotFound 来表示值得缺失
 */



// 字符串
// 字面量, 被双引号包裹的固定顺序字符串. """ 内容 """ 可以定义多行字面量.
// \u{}

