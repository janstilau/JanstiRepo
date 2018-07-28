# 引用计数

* 自己生成的对象, 自己持有.

alloc, new, copy, mutableCopy. OC 里面是按照函数名称作为引用计数管理的, arc 环境更是如此, 所以, 以前面命名的驼峰式函数, 都算是生成对象

* 非自己生成的对象, 也能持有

```oc
id obj = [NSMutableArray array];
[obj retain];
```

* 不需要持有对象的时候, 释放对象

自己生成的, 通过 retain 持有的对象, 都是通过这种方式释放. 一旦自己不需要了, 务必用这种方式释放.

```oc
[obj release]
```

这里, 必须通过名称进行对象的函数书写, [obj allocObject], 这个函数是生成对象的函数, 所以函数体里面应该是, alloc init, 然后直接返回这个生成的对象. 接受者拿到的是一个引用计数为1的对象, 这就是接受者持有了自己生成的对象. 而对于 [NSMutableArray array] 这种方法生成的对象, 其实应该算作谁都没有持有. 那么在 array 的函数里面, 其实是 [NSMutableArray alloc] init, 然后将生成的对象, obj autorelease. autorelease 会在 autorelase 对象生命周期的最后, 对所有加入到自动释放池的对象做一次引用计数减一的操作. 这样, [NSMutableArray array] 返回的对象, 如果接受者没有 retain, 在 autoreleasepool 消失的时候, 进行 release 操作, runloop 自动每次都有一个默认的 autoreleasePool.

* 无法释放非自己持有的对象

如果释放一个不是自己生成, 不是自己持有的对象, 那么程序就会崩溃.

## GNUStep 的代码实现, 苹果实现方法不是这样, 但是效果相同.

* alloc 

首先, 计算 class 的大小, 在计算的大小后 + 一个 int 值大小, 这个 int 值就是引用计数, 然后申请这么一块内存大小, 然后所有的内存清零, 这就是为什么 oc 的对象会有默认值的原因, 然后返回这个内存地址, 不过是 intPointer + 1之后的地址, 为的是把那个引用计数隐藏掉.

这样的计数, 在 retainCount 方法调用的时候, 就是取头部的那个引用计数, 直接返回就可以了.

* retain, release

很简单了, 操作头部引用计数, ++1, --1
在release的时候, 如果判断是0, 就调用 free方法.

* autorelease

和上面的原理一样, obj 的 autorelease 方法, 其实是把自己注册到最近的一个 autoreleasePool 中去, 当这个 autoreleasePool 的生命周期的最后, 会对里面的每个方法, 做 release 操作. 所以, 在大量对象生成的时候, 可以在操作的周围, 生成一个 autorelasePool 对象, 防止内存过高. oc 里面的所有工厂方法返回的对象, 都是在 autorelasePool 里面.

AutorelasePool 可以嵌套, 对象会被添加到自己所在的 Pool 对象上.


## ARC

引用计数管理内存的方案并没有变化, 只不过, 编译器自动做了内存管理的操作, 并且做了优化.

__strong
__weak
__unsafe_unretained
__autoreleasing


* STORNG

默认 oc 里面的所有权修饰符号, 给一个 strong 指针赋值, 就相当于这个对象引用计数加1, 这个 strong 指针失效, 就相当于引用计数 -1, strong 指针指向其他的对象或者赋值为 NULL, 就是引用计数 -1. 这些都是编译器自动做的工作, 其实还是引用计数的操作.

* WEAK

两个类, 里面都有 strong 变量, 互相引用, 那么引用计数永远不能为0. 这个叫做循环引用. 自己引用自己, 也是会循环引用. weak 所有权修饰符表示, 不持有对象实例. 就是说, 给 weak 修饰的指针赋值, 不会调用 retain 方法, 既然都没有持有, 这个 weak 指针值改变的话, 原来的值也不会 release.

weak 的好处在于, 当引用的对象被释放之后, 自己的值会被赋值为 nil.

__unsafe_unretained 的和 weak 是一样的效果, 不过在引用的值释放掉, 不会变为 nil. 好像是历史原因, 一般都用 weak.

* autoreleasing

ARC 有效的时候, 赋值给 __autoreleasing 的指针, 相当于调用了 autorelase 方法
```oc
@autoreleasepool{
    id _autorelasing obj = [NSObject alloc]
}
```

不过没人这么写, 编译器会自动检查, 是不是 alloc, new, copy, mutableCopy 生成并返回的对象, 如果不是, 那么就自动的添加到了 pool 里面.

