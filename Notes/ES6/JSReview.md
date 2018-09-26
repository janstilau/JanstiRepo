# RefreshJS

## 变量, 作用域和内存

JS 变量松散类型的本质, 决定了它只是在特定的时间里, 用于保存特定值的一个名字. 变量的值和类型, 在脚本的生命周期里面都可以改变.

* 基本类型 -> 简单的数据段
* 引用类型 -> 多个值组成的对象

Undefined, Null, Boolean, Number, String 按值访问, 所以可以操作保存在变量里面的值. 注意 String, 是值类型. 这个其他语言不一样, 这也就意味着, string.append 等操作, 其实是生成一个新的 string 对象了.
引用类型的值, 是对象的地址, JS 不允许直接访问内存的位置, 也就是没有办法直接操作对象的内存空间. 其实可以这么理解, 所有的引用类型, 其实是 T* 这种形式的.

对于引用类型的对象, 我们可以添加属性和方法. 也可以修改和删除.
更大的区别在于, 复制变量的时候.

复制基本类型的值, 会在变量对象上创建一个新值, 然后把该值复制到新变量的位置上. 此后, 这两个值是完全独立的. 改变一个不会影响另外一个的值.
当复制引用类型的值得时候, 也会在变量对象上创建一个新的变量, 然后将地址复制到这个变量的位置上. 所以, 这两个变量引用的是一个内存地址, 改变一个的值, 就会影响到另外一个.

传递参数自然是和上面的类似的. 所有的形参, 都是被调函数的变量对象的 arguments 对象上的一个元素.

这里, 所有的遍历都是在变量对象上. 那么变量对象, 又是一个对象, 是不是可以理解, 所有的变量, 其实都是堆空间里面.

### typeof 和 instanceof

首先, 这是一个操作符. 它的作用就是判断变量的类型. 在 let 没有出现之前, 这是一个安全的操作, 就算是一个没有定义的遍历, typeof 也能返回 undefined, 不过, let 之后出现了作用域死锁. 注意, 这个操作符返回的是小写字母的字符串.

```JS
let s = 'justin'
let b = true
let i = 22
let u
let n = null
let o = new Object()

console.log(typeof s)
console.log(typeof b)
console.log(typeof i)
console.log(typeof u)
console.log(typeof n)
console.log(typeof o)

string
boolean
number
undefined
object
object
```

instanceof 操作符可以判断, 遍历是不是给定的类型. 形式是 variable instanceof constructor.
可以看到, 后面的第二参数是一个构造函数. MDN 上, 对它的解释如下.
The instanceof operator tests whether the prototype property of a constructor appears anywhere in the prototype chain of an object.
也就是说, 只要一个变量的原型链上有这个 Constructor 的原型的话, 这个操作符就会返回 true.

### 执行环境和作用域

每一个执行环境, 都有一个与之关联的变量对象, 环境里面定义的所有变量和函数, 都保存在这个对象上. 全局执行环境是最外层的一个执行环节, 根据宿主环境而变化.

每一个函数的都有自己的执行环境, 当进入一个函数之后, 函数的环境就被推入到有一个环境栈, 执行完毕之后, 栈弹出, 将控制权返回给之前的执行环境. 代码在一个环境中执行的时候, 会创建一个作用域链, 作用域链上面的, 是各个变量对象, 最前端, 始终是当前环境的变量对象. 每个变量对象, 最开始只有 arguments 对象, 所有的形参作为 arguments 对象的一个元素存在着, 在函数执行过程中, 新创建的变量会添加到这个变量对象上作为变量对象的一个属性. 在作用域链上, 下一个变量对象来自于当前环境的包含环境, 在下一个是当前环境的包含环境的包含环境. 依次类推, 直到最外层的全局执行环境的变量对象.

而标识符的解析工作, 就是沿着作用域链进行的, 如果前面一个变量环境上找到了 name 这个变量, 那么name 就是这个环境的那个 name 值, 链条后面的变量对象上的 name 就被隐藏掉了.

所以, 内部环境可以使用外部环境的变量, 而外部环境不可以使用内部环境的. 原因就在于, 内部环境的作用域链长, 可以找到外部环境上面的所有变量, 而外部环境的作用域链不知道内部环境的变量对象是什么.

在 ES6 之前, JS 中没有块作用域, 这里, 作用域的概念应该和环境的概念是一模一样的. var 定义变量的时候, 会将 var 所定义的变量, 添加到最近的函数作用域中, 这个操作引起了很多的 bug. ES6 之后添加了块级作用域, 并且添加了 let 用来声明变量, let 声明的对象, 会添加到最近的块作用域上, 自己实验也表明了, 在一个块级作用域里面定义的函数, 它的[[scopes]], 也就是作用域链里面, 确实是有了包含它的块环境的变量对象了. (只有确实引用到这个环境的变量的时候才会添加进去.)

注意, 对象并不是一个环境

```JS
let globalValue
function Test() {
    let testOutput = 'testOutput'
    let obj = {
        name: 'objName',
        speak: function () {
            console.log('obj sepak function')
        },
        child: {
            nickName: 'niknikni',
            shout: function () {
                console.log(this.nickName)
                console.log(name)
            }
        }
    }
    globalValue = globalValue = function f() {
        console.log(testOutput)
        console.log(obj.name)
        obj.speak()
        obj.child.shout()
    }
}
```

在上面的代码里面, child.shout 最后会报错的, 因为找不到 name. 但是包含着它的不是有 name 属性吗. 从这可以看出, obj 的定义 {} 之内, 其实不是一个块级环境. 在 speak, shout 的作用域链上, 最前面的变量对象, 也是 Test 的变量对象, 并没有所谓的 obj 的变量对象. 这都说明, obj 的定义{}, 并不是一个环境.

### 函数, 函数表达式, 捕获, 和之前提到的作用域关系

函数并不介意传递多少参数过来, 也不在意参数的类型. 因为, 函数的内部始终接受的是一个数组, 这个数组包含所有的参数, 这个数组就是 arguments 对象, 而 arguments 是变量对象的一个属性. 参数是作为一种便利的方式, argumetns 中的值, 和参数的值会保持同步. 他们的内存空间是独立的, 但是 JS 会有同步的机制, 让他们总是一个值.

另一个需要注意的是, 没有重载的概念. 函数的名称, 可以理解为一个变量而已, 这个变量指向的对象, 是真正的函数对象, 这个对象里面铁定有一个指针, 指向了函数的真正实现. 所以, 当出现两个同名的函数的时候, 就算参数个数不同, 也是后面出现的覆盖前面出现的. 也就是函数名所指示的变量的值发生了.

也正因为这样, 所以函数才可以被传递, obj.speak = speak, let speak = obj.speak, 只不过是将函数对象传递出去了. 将函数作为参数传递, 或者返回, 都是传递的是函数对象.

在创建函数的时候, 会有创建一个作用域链, 存放到函数的[[Scope]]的属性中, 当函数真正执行的时候, 会创建一个新的作用域链, 然后复制函数的[[Scope]]里面的作用域链的值到新的作用域链里面. 然后执行环境就依靠这个新的作用域链进行遍历的解析工作. 然后执行完毕之后, 这个新创建的作用域链和执行过程中定义的变量和对象都被销毁. 但是, 函数的[[Scope]]中的值没有被清空.

但是如果函数执行的过程中, 创建了一个新的函数, 情况就有所不同了. 函数的执行过程中, 会创建自己的变量对象, 然后创建了一个新的函数, 新的函数如果引用到了自己的变量对象里面的值得话, 那么整个新的函数在定义的时候, 就会将当前执行环境的变量对象, 保存到自己的[[Scope]]中, 用以自己下次执行的时候, 分析自己的执行代码里面的变量. 这就是我们经常说的捕获, 当定义新函数的函数执行完毕之后, 自己的变量对象被新创建的函数中的[[Scope]]引用到了, 所以自己的变量对象也就不会被释放, 变量对象不释放, 变量对象上面的变量也就继续存活, 所以被定义出的函数在执行的过程中, 就能正确的取到被捕获的值了.

在定义函数的每次运行过程中, 都是创建一个新的变量对象, 定义一个新的函数对象, 这个函数对象捕获这个新的变量对象, 又被叫做一个闭包, 所以每个闭包捕获的值都是相互独立的.

闭包的这个概念, 在其他语言中也有, 不过实现方式不一样, JS 中闭包捕获的是, 当前运行环境的变量对象, 其他语言则是, 捕获用到的值, 也就是捕获什么变量, 就在自己的内存里面复制一份那个变量的值, 这个值有可能是基本数据类型, 也有可能是指针. 这里, oc 和 Cpp 又有不一样. oc 里面捕获一个指针, 那么这就是一个强引用, 这个捕获关系可以使得那个被捕获的对象不会被释放, 这和 JS 里面, 捕获了一个变量对象, 变量对象不会被释放是一个道理. 而 C++, 捕获了一个对象的指针, 是程序员的责任去保证, 这个对象在下一次闭包被调用的时候, 还是存在的. 这也是 C++ 困难的地方, 内存手动管理, 是一个非常复杂的问题.

我们在定义一个对象的时候, 这个对象里面也会有函数. 这个时候, 这个函数就是一个闭包了. 这个函数会有[[Scope]], 里面会捕获所有定义的时候所用到的环境的变量对象. 当我们把这个函数赋值到一个全局对象, 或者将一个全局对象函数, 交给一个对象作为对象内部的方法的时候, 变得只有 this 的指向, [[Scope]]里面的内容, 函数的实现的指向都不会变. 这也就是捕获的好处, 只要捕获了, 无论函数作为谁的属性, 访问的都是函数被定义的时候, 捕获的对象.

### this

首先, OC 和 c++ 中的 this, 是一个真正的值, 它指向了这个类的对象, 类的概念就在于, 函数和数据的封装, 这种封装, 通过 this 指针, 使得函数可以很方便的找到所对应的数据对象.

但是 JS 里面并没有这种绑定关系, JS 中函数就是一个单独的内存空间, 它可以被传递出去, 将函数写在一个对象的定义里面, 也仅仅是这个函数有个属性是个函数而已. JS 需要有一个办法让函数, 可以引用到数据, 来实现封装的效果. 那么, this 就出现了, 当 obj.speak 这种方式调用函数的时候, JS 的解释器就将 speak 的 this , 指向 obj, 使得 speak 可以操作 obj 中的数据. 而在其他的环境下, 调用 speak, this 指向的全局对象. 有很多的可以改变 this 的指向的函数, 例如 bind, foreach 中的第一个参数等等. 正是因为, this 不是一个实际的值, 才能做这种更改. this 是一个关键字. 函数的执行环境不同的时候, 指向不同的值.

In most cases, the value of this is determined by how a function is called. It can't be set by assignment during execution

In the global execution context (outside of any function), this refers to the global object whether in strict mode or not.

Inside a function, the value of this depends on how the function is called.

总是, 在执行函数的过程中, this 的不同指向, 是因为 Js 中对象的函数是一个闭包, 或者说仅仅是一个内存对象, 而不是从属于这个对象的方法导致了. 这也使得函数在不同的使用环境下, this 的指向不同, 而 bind, call 这些将函数的 this 的绑定, 也是因为上面的原因, 才有了可能.

## 面向对象的设计

对象的定义为: 无序属性的集合, 它的属性可以包含基本值, 对象, 函数. 相当于说, 对象就是一组没有特定顺序的值, 对象的每个属性或者方法都有一个名字, 而每个名字, 都映射到一个值. 所以, 对象可以想象为一个散列表. 一组名值对, 值可以是数据和函数.

### 属性

属性特性, 是描述属性的各种特征, 不可以直接访问, Object.getOwnPropertyDescriptor(obj, propertyName) 这个方法可以取得一个对象的某个属性的特性信息.

* Configurable. 是否可以通过 delete 删除某个属性
* Enumerable 是否可以通过 for-in 循环返回. 默认 true
* Writable 是否可以修改属性的值. 默认 true
* Value 数据值. 默认 undefined. 注意, 函数的值都是一个 lambda 表达式.

如果要修改一个属性的特性, Object.defineProperty.

多数情况下, 没有必要对属性的特性做操作.

### 访问器属性

不包括数据值, 可以理解为计算属性. 包含一堆 getter, setter 函数, 访问的时候调用 getter, 写入的时候, 调用 setter.
这个属性不能直接定义, 必须通过 Object.defineProperty 来定义.
计算属性, 一般还是操作对象的某个数据属性, 不过可以通过 getter, setter 对这个属性进行包装. 通过这个可以做出 readonly 的属性操作来.

## 原型模式

构造一个对象, 需要构造方法, JS 里面没有什么方法重载的概念, 所以, 一个类型的所有实例, 都应该是由一个构造方法创建出来. 构造方法里面会有一个 prototype 的指针, 指向一个对象. 当一个构造方法创建完一个对象之后, 会将这个 prototype 设置到新创的对象上.

构造方法里面, 做的是一个对象的属性的初始化的工作, 里面初始化的属性, 应该是这个对象独有的, 类似于成员变量. 而原型的上, 应该保留所有的实例都共享的数据, 典型的就是方法.

每个函数都有一个 prototype 的属性, 指向一个对象, 这个对象包含着可以由特定类型的所有实例共享的属性和方法. prototype 就是通过构造方法创建的对象的原型对象.

默认情况下, prototype 只有一个 constructor 属性, 指向构造函数. 也就是说, constructor 和原型对象是相互指向的. 在实例中, 有一个隐藏的指针, 叫做[[Prototype]], 不可以直接取得, 不过各个浏览器都有自己的取得办法. 这个指针, 是构造方法在构造实例的时候指定的.

可以通过 isPrototypeOf 这个方法, 判断一个对象是不是另外一个对象的原型. 如果, [[Prototype]] 指向的调用了 isPrototypeOf 的方法, 那么这个方法就是返回 true.

* 对象的[[protoType]] 和 function 的 protytype

对象的[[protoType]], 是指对象的原型, 不可以直接通过对象.属性获取, 只能通过 Object.getPrototypeOf 获取, 对象的构造方法里面也有protytype, 是构造方法的属性. 这两者的关系是, 相等.

* 属性的搜索策略

每当代码读取某个对象的某个属性的时候, 就会执行一次搜索. 首先从实例对象本身开始, 如果没有找到, 那么就搜索原型对象, 如果还没有, 就会搜索原型的原型, 知道最后找到 Object 的原型, 如果还没有就会报错了.

hasOwnPropery 可以判断某个属性, 是不是自己本身独有的属性.


### Object.create

Object.create() 可以返回一个新的对象, 这个对象的原型, 会是这个函数传入的第一个参数.

在 ES6 之前, 就是通过这个方法完成的继承关系.

首先, 创建一个构造函数

function A () {
  // INIT CODE
}

然后给 A 的 prototype 增加一些属性, 作为所有 A 的实例的共有属性

A.prototype.type = 'A';
A.prototype.commonMethod = funtion() {}

然后创建一个构造函数 B 
function B () {
   A.call(this) // 这样做就是 调动A 的初始化
  // INIT CODE
 
}

然后
B.prototype = Object.create(A())
B.prototype.constructor = B
然后给 B.prototype 增加一些属性, 作为所有 B 的实例的共有属性

B.prototype.type = 'B'
B.prototype.commonMethod = funtion() {}

这里, B.prototype = Object.create(A.prototype) 做了什么事情.
首先, B 的原型应该接上 A 的原型, 让原型链成型. 这里中间做一个空对象, 这个空对象的 prototype 是 A.prototype. 如果我们能直接 B.prototype.prototype = A.prototype, 我们应该这么写, 但是我们不能这么写, 因为 B.prototype 是一个对象, 而对象prototype 是一个隐藏的属性, 所以用 Object.create 做了中间的工作.

### class

```JS

class Polygon {
  constructor(height, width) {
    this.height = height;
    this.width = width;
  }
}

class Square extends Polygon {
  constructor(sideLength) {
    super(sideLength, sideLength);
  }
  get area() {
    return this.height * this.width;
  }
  set sideLength(newLength) {
    this.height = newLength;
    this.width = newLength;
  }
}

var square = new Square(2);
```