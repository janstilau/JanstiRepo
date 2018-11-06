# Cpp

## Cpp类设计注意点

* 构造函数的初始化列表
* pass by value, pass by reference. return by value, return by reference.
* 成员函数的结尾, 是否用 const 进行修饰.
* by reference 传值进行 const 修饰吗

    C++ 中对于 const 有着严格的定义. cosnt A *aPointer; const A& aRef;  A 中有一个成员变量 value, 那么 aPointer->value, aRef.value 都是不能够修改的. 这其实是符合 const 在原始数据类型的定义的. 而 OC 中, aPointer->value 却能进行修改, 这是 OC 中不好的地方.

    当一个指针, ref 被 const 修饰了之后, 只能调用被 const 修饰的函数, 如果没有 const 修饰的话, 就会报'this' argument to member function 'speak' has type 'const A', but function is not marked const', 这是编译的时候就报的错. 所以, 编译器其实做了限制, const 的函数是不能对于成员变量进行修改的, 在 const 函数的内部也不能调用非 const 修饰的函数, 这样, const pointer, ref 调用 const 函数, 就能够保证说, 内部的状态一定不会被修改. 

    而非 const ref, pointer, 是可以调用 const 函数的. 

    相对应的, OC 里面对于状态保持不变这个事情, 是通过接口实现的, 也只有几个系统的类做了不可更改的操作, NSString, NSArray, 它们不可以修改, 是因为它们就没有修改内部状态的接口. 至于用 OC 的动态性修改内部数据会不会报错, 没有试验过.

    对于 const 函数, const 函数保证的是自己对象的内存空间不会被修改, 如果返回一个指针, 这个指针指向的内容被修改了, 其实和 const 函数是无关的. 对于那种返回了指针, 指针指向的空间不能被修改的情况, 应该返回 const char *, 通过返回值类型予以限制.

* 操作符重载, 模拟基本数据类型的操作符操作.
操作符重载包括类内操作符函数, 以及全局操作符函数.
* 成员变量是否有指针, 这
如果有指针, 那么该类就要负责这个指针指向对象的生命周期的管理. 而为了应对这个责任, 拷贝构造函数, 拷贝赋值函数, 和析构函数, 都要进行实现.
实现的基本思路在于, 判断是不是原有管理的资源, 对于原有资源的释放, 对于新的资源的深拷贝.

这里和 OC 有着很大的区别, 首先 OC 中所有的资源都是在堆中, 在这 OC 中所有的资源都是用的引用计数进行管理的. OC 中没有拷贝构造函数的概念, 要有类似功能的类, 必须实现 COPY 协议. OC 也没有拷贝赋值函数的概念, OC 中的赋值仅仅是指针的赋值而已. 其实在 C++ 的=操作符中, 对于指针也仅仅是指针变量的赋值, 拷贝赋值的操作, 只有在栈上的对象进行赋值的时候才会发生.

OC 的 copy 函数中, 对于指针的成员变量, 要考虑深拷贝和浅拷贝的问题.
C++ 的拷贝构造和拷贝赋值中, 也要考虑这个问题.
对于 C++ 中, 几乎都是深拷贝. 这是因为, 在 C++ 中, 没有默认使用引用计数的概念, 除非明确的使用 sharePointer. 这样, 类就有管理自己成员变量的内存的责任, 类在自己 dealloc 的时候, 就要释放管理的成员变量指向的内存. 而这在 OC 中, 因为所有类的有着引用计数的存储, 所以就算是浅拷贝, 因为引用计数加1, 成员变量指向的资源可以得到很好地管理.

现在 C++ 推荐使用引用计数进行资源的管理.

## 内存.

new -> 1. 系统先分配内存, malloc 2. 调用构造函数初始化
delete -> 1. 调用析构函数 2. free对象占据的空间

构造函数是没有虚函数的, 这也是为什么 C++ 里面, 没有类似 init 这样的一个东西, NSObject 写出来了, 子类直接 init 就可以了. OC 是没有办法避免子类通过 init, 而不是自己写出来的指定的 init 方法进行初始化的. 因为 OC 是个消息机制, init 不过是类的一个方法而已, 实际上, 可以多次调用 init 方法的. 而 C++ 中, 一个类只能通过自己写出来的构造函数进行初始化. 而初始化的继承体系, 是要在各自的初始化方法里面明确的写出调用父类的哪个构造方法在保持的.

OC 中想要保持这个继承体系, 必须重写 init 方法, 在各个方法里面, 写明调用 super 的哪个 init 方法才可以, 不过这个体系我们经常不刻意去维护.

### 内存分配的真正内存分布.

VC 下的内存分布策略
Cookie (debug信息, release 模式没有) 实际的内容 (pad信息, 为了保持各个系统分配内存的策略, 比如VC下必须保持分配的总共空间必须是16bit的倍数) Cookie
在分配数组的情况下,  array new, array delete.
Cookie (debug信息, release 模式没有) 一个数量值,代表数组的长度 实际的内容 (pad信息, 为了保持各个系统分配内存的策略, 比如VC下必须保持分配的总共空间必须是16bit的倍数) Cookie
所以在 array new 的时候, 其中是有一个值是代表着数组长度的, 这样, array delete 的时候, 可以根据中间的数量值, 对实际内容依次调用析构函数. 而在析构函数里面, 可能会有其他的内存释放的操作.
array new, 必须搭配 array delete, 如果只是调用 delete, 那么只会调用一次析构函数.
数组的空间是可以正确的释放的, 因为 cookie 中记录了这段内存空间有多少, 泄露的是, 数组的各个 item 管理的内存空间, 这些内存空间只有在析构函数中才会被释放. 如果各个 item 中, 没有指针成员变量, 也就是没有管理另外一块内存空间, 也就不会发生内存泄露. 但是, 不应该去分辨这个

Cookie 中记录了整个分配出来的大小, 这样, free 的时候, 就可以根据整个 Cookie 值, 回收对应的内存空间.

## static

C++ 的 static 成员变量必须要在类定义体外进行一次定义, 因为这里才是真正分配内存空间的地方.
C++ 的 static 成员函数, 可以用对象.static成员函数的方式进行调用. 这里我觉得设计的不好, 我一般是 A::staticFun() 这样的方式进行调用的, A a, a.staticFun() 这样调用显得很怪. 并且如果有一个成员函数也叫做 staticFun 的话, 会有 ambuguious 的编译错误. 所以, static 最好还是以 A::staticFun 这种方式进行调用.

## 类模板, 函数模板

模板的目的是减少重复代码. 这些重复代码是因为处理不同的类型而重复, 而其中的代码逻辑没有变化.
类模板要明确写出来 T 的类型, 函数模板, 编译器会自己推断. deduction

C++ 的算法里面, 都是函数模板. 函数模板里面, 编写了一些通用的规则, 但是, 应用这套规则, 是需要类型支持的. 比如, 算法里面写出了 a < b 的操作, 但是 < 这个符号, 作为一个操作符, 在 a b 中应该怎么体现呢. 这个时候, 就要求了, 传入到函数模板的这个类型, 必须支持 < 操作符的重载才可以.

## 特化, 偏特化

## 继承, 组合, 委托. --> 当多个类之间有了关系, 就是面向对象.

组合, has-a的关系. 当前对象里面, 拥有另外一个对象. 在代码里表现, 就是有另外一个对象, 而不仅仅是有另外一个对象的指针.

组合应该是最优先考虑的, 组合和委托都算作组合. 不同的是, 委托是组合 by ref.

关于构造顺序和析构顺序, 我觉得应该记住一些原则, 而不是死记硬背.

1. 对于基本数据类型, 不在构造函数里面写出初始值, 那么就是一个随机值, 所以在构造函数的时候, 一定要覆盖所有的成员变量.
1. 对于自定义数据类型, 也就是 struct 和 class. 一定是用构造函数进行初始化的. 在编译器发现, 一个成员变量对象, 没有在构造函数里面写清楚用哪个构造函数进行初始化的时候, 就使用它的默认构造函数. 如果找不到默认构造函数(你定义了其他构造函数), 那么编译就会报错了. 
1. 而析构的时候刚好相反, 显示自己析构, 然后是成员变量析构, 最后是基类的析构.
1. 构造顺序是, 先是基类的构造函数, 然后是成员类的构造函数, 最后是自己的. 注意, 初始化列表不是构造函数. 所以, 可以认为是
1. 以上讲的都没有委托, 也就是 by ref 的形式. 在 by ref 的时候, 一个类, 应该符合管理 ref 所指向的内存空间的生命周期. 所以, 在构造函数里面, 和析构函数里面, 要有对于这个 ref 指向内存空间的处理动作.

```c++
B(): A的构造函数, 成员的构造函数 {B 的构造函数} 这个顺序永远存在的, 你如果不写, 那A 的构造函数, 成员的构造函数 编译器就会都用默认的, 如果找不到就编译报错. 这就是为什么, 不成员初始化列表而在 B 的构造函数里面为成员变量赋值性能会有损失.
```

## 继承和虚函数

继承, 数据可以继承, 继承的是空间, 函数可继承, 继承的是调用权

非虚函数: 父类不希望子类重新定义, override
虚函数: 父类希望子类重新定义, 不过父类有默认实现
纯虚函数: 父类希望子类一定要重新定义

## 委托+继承

委托, 就是指针, 继承, 就是指指针指向一个基类, 实际的对象是子类. 这是设计模式的基础. 例如, 监听者模式, 例如, 策略模式.

## 转换函数

不常用, 不记. 

```cpp
operator double const () { return 对象表达的浮点数.}
```

## no explicit one argument

就是只需要一个形参的构造函数, 如果没有被 explicit 标明, 那么编译器会在可以转换的时候, 调用这个构造函数

例如,A a;a + 4. 如果 a 有着 operation +(const A& value); 所以4可以转换成为 A 对象. 于是, a + 4 就变成了两个 A 对象相加. 

这个和上面的转换函数是刚好相反的.

从这我们看出, C++ 有了太多的编译器特性了. 这些特性, 对于实际的编程, 我觉得是有害的. 并且没有一个通用的规则. 例如, 上面的写法, 如果没有 operation+, 就不会有这种转化. 所以, 经尝试增加一句代码, 引起了编译出错. 而出错的原因, 可能在很远的地方.

为了避免上面那种编译器的隐式转化, 加上 explicit. explicit ont argument ctor

## C++ 的操作符重载非常重要. 下面可以看到.

## pointer like class, 重载了*, -> 操作符

智能指针, 重载了*, -> 操作符, 用法类似指针, 之所以用对象实现, 是为了在原有指针上, 增加一些操作. 比如智能指针, 就增加了引用计数.

```C++
template<class T>
class share_ptr {
    T& operator*() const {
        return *px;
    }
    T* operator->() const {
        return px;
    }
    shared_ptr(T *p): px(p){}
private:
    T *px;
    long *pn;
}
```

迭代器. 重载了++, --, 前++, 前--, *, ->, 模拟指针操作.
迭代器, 作为一个类, 能够记录一些东西. 一般来说, 会记录原有的容器数据的指针, 还有就是当前遍历到的节点的指针.

## function like class
重载了 operator () 操作符.
系统的仿函数, 都继承了一些基类, 这些基类名字是 单操作符, 双操作符, 这些基类里面, 仅仅是一些 typedef.
我们在写自己的仿函数的时候, 也应该继承这些基类, 用来获取这些 typedef. 因为算法的泛型编程里面, 其实是用到了里面的 typedef 定义的类型, 如果我们自己的仿函数, 没有继承这些 typedef, 那么就不能用到那些算法里面.

## namespace
防止冲突. 这个在 tield 里面用的很多, 多去看看.

## 模板相关

当代码中只有类型不一样, 而其他的处理逻辑都一样的时候, 就应该把类型抽离出来, 用一个占位符代替. 这个占位符就代表某个类型. 在编译器编译的时候, 发现了是模板, 会根据当时的环境(类模板必须手动写明占位符类型, 函数模板会根据实参进行自动推导), 按照 T 的类型生成一份对应的源代码, 然后在根据生成的源代码进行编译.

对于代码里面写的操作, 例如, 操作符, T 类型的函数调用, 在编译的时候都进行检查, 如果 T 类型没有对应的操作符重载, 或者函数调用, 编译就会出错.

模板并没有解决重复代码的问题, 然而, 在程序员书写的时候, 重复代码通过模板技术解决了. 而真正的代码, 编译器会生成用到的重复代码, 而这都是编译的时候发生的事情.

所以模板其实是会编译两次, 一次生成类型确定的代码, 一次根据生成的代码进行后续的编译.

### 类模板

### 函数模板

### 成员模板
没看

## 特化, specialization, 偏特化, partial specialization

特化就是, 当 T 变为某种类型的时候, 会有自己特殊的部分, 那么就写出一份单独的关于这个特定类型的代码出来. 偏特化就是, 有多个模板参数的时候, 当其中某些类型能够确定的时候会有不同的操作, 那么就在写出这些类型下的单独的代码过来.

编译器在根据泛化版本生成各个类型的版本的时候, 如果有特化的版本, 自然是以特化的版本为准.

这些特性其实不会经常用, 知道这个概念就好了.

```cpp
// 函数特化
template<typename T> // T 泛化
    static void toObj(const QString &str, T& value, bool *ok = nullptr);
    // 特化
template<> // T 没有了, 变成了具体的类型
QString PrintUtil::toStr(const QStringList &obj)
template<>
void PrintUtil::toObj(const QString &str, QList<int> &value, bool *ok)
{
    QXmlStreamReader xmlReader(str);
    QList<int> list;
    if (str.trimmed().isEmpty()) {
        value = list;
        return;
    }
    bool convertElement = true;
    for (auto tokenType = xmlReader.readNext(); !xmlReader.atEnd(); tokenType = xmlReader.readNext()) {
        switch (tokenType) {
        case QXmlStreamReader::StartElement:
        {
            QString nodeName = xmlReader.name().toString();
            if ( nodeName == QString(QLatin1String("item"))) {
                QXmlStreamAttributes attributes = xmlReader.attributes();
                int intValue;
                QString xmlText = attributes.value(QLatin1String("value")).toString();
                PrintUtil::toObj(xmlText, intValue, &convertElement);
                if (!convertElement) { break; }
                list << intValue;
            }
        }
            break;
        default:
            break;
        }
    }
    if (ok && (xmlReader.hasError() || !convertElement)) {
        *ok = false;
    }
    value = list;
}

```

## 标准库

容器 + 算法 + 迭代器 + 仿函数.

容器 和 算法之间的桥梁是迭代器, 仿函数并用到算法里面.

## auto

自动类型推导. 一定要是编译器可以帮助你推导出类型才行, 直接写 auto a, 编译器根本就不知道 a 的类型到底是什么.

## range-base for

```c++
vector<double> vec;
for(auto elem: vec) {
    cout << elem << endl;
}

for(auto & elem: vec) {
    cout << elem << endl;
}
```

## ref

int a = 100;
in& b = a;
虽然, 我们知道 ref 是通过指针实现的, 但是编译器在处理下面的代码的时候, 会模拟出 ref 就是a 的效果.
sizeof(a) == sizeof(b) 
&a == &b


ref 一般不用在声明变量, 而是用在参数传递和返回值类型上. 尽可能的 pass, return by ref, 除非是临时变量.
pass by pointer的时候, 参数传递之后, 写法不一样, 一个用., 一个用->, 这样不太好.

## vptr, vtbl

只要类里面有一个虚函数, 对象里面就会增加一个 vptr, pointer to vtbl.
编译器发现是虚函数调用的时候, 会通过虚函数表, 找到最终的代码实现进行调用.
所以, 其实 C++ 里面, 也是有着动态性的.

和之前的立即一样, 应该已经是记在脑子里面了.

## 记忆

C++ 有很多的特性, 理解它为什么这么做的规则, 要比记住特性好的多. 因为记住就会有一天记不住. 而原则可以推倒出特性.

比如 const 对象, 调用一般成员函数, const 函数.

当成员函数的 const, 和 non - const 版本同时存在的时候, const obj 只会调用 const 版本, non-const obj 只会调用非常量版本.


