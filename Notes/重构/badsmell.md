# BadSmell

## 并没有明确的规则, 告诉你什么时候应该重构, 但是下面的这些, 是代码腐败的一些标志.

* duplicated code 重复代码

提取重复代码. 
1. 提取到新函数
1. 提出到父类
1. 提出到独立类.

* long method 长函数

小函数有着很多的价值.
间接层有着很多的好处-解释能力, 共享能力, 选择能力.

* 过大的类

如果想要利用单个类做太多的事情, 内部就会堆积大量的实例变量. 这个时候可以把相关联的字段提取到新的类中.
类内如果有太多的代码, 很容易代码, 很容易出现重复代码, 提取代码到函数或者新的类中.
GUI 的话, 可以考虑把数据和行为, 封装到一个独立的 GUI 类中, 不过要保持相关数据的同步.

* 过长的参数列表

对象出现的意义, 其中之一就是包裹数据. 这样, 就不必将所有需要的数据通过参数传递给函数了, 因为函数内部可以在宿主类中找到需要的数据.
同时, 对象也是参数的封装体, 过多的参数, 会造成逻辑的复杂, 而将对象传递给函数, 在需要修改的时候, 只需要给对象添加属性, 在函数内增加对于属性的操作就可以了. 而如果是用的参数传递, 那么每一个函数的调用都要修改.
这里, 要考虑函数的作用. 有的时候, 函数只需要对象里面的一两个参数, 那么传递对象就显得太重了. 所以, 函数的参数到底是对象还是仅仅需要是函数需要的那几个参数要根据情况来定.

* divergent Change 一个类的变化点过多

每个类应该只有一个引起变化的点.

针对某一个外界变化的所有应该的修改, 应该只发生在单一类中, 而这个类内的所有内容, 都应该反映该变化.

* shotGun surgery 变化引起的变化的类过多

某种变化, 需要在多个类中进行修改, 那么很容易漏掉内容, 应该把所有需要修改的代码放到一个类中. 这和上面的都是为了, 外界变化和需要修改的类一一对应.

* 数据依赖

一个类的某个函数, 需要用到另外一个类的数据. 当然, 函数同时使用多个类的数据的情况很常见, 这里书中并没有给出明确的解决方案. 只是说, 将函数移植到函数最多依赖的类的内部.

* 多个数据抱团

类中, 函数中充斥了大量重复的字段, 比如两个类中需要同样的两个字段, 函数中, 需要用到同样的两个字段. 这个和上面的参数列表过长讲的是同样一个事情, 就是用需要用对象包裹数据.  不必在意, 在使用这个类的时候, 只用上了对象的一部分字段, 只要用新的对象取代了一两个字段, 就值得. 这个要现实考虑, 要考虑依赖关系. 

这样做的意义在于, 只要用对象包裹数据, 你就可以后续优化, 将数据的位置从零散的字段变成一个封装体, 才会进行下一步, 字段位置的改变.

一个好的评判标准是: 如果删除了众多数据中的一项, 那么其他数据有没有失去了意义? 如果不在有意义, 那么就是一个信号, 应该将这些数据归并到一个新的对象内部.

* 偏爱基本类型数据.

* switch 

swtich 的问题, 在于重复, 同样的 switch 语句散布在不同的地方, 当要为它添加一个新的 case 的时候, 必须找到所有的 switch 并且修改, 这就很容易出现问题. 用多态机制.

* 平行继承

* 冗余类

* 过于设计未来性

企图用各种各样的钩子和特殊情况来处理一些非必要的事情, 往往造成系统更加难以理解和维护.

如果类和函数的唯一用户就是测试用例, 那么就该删除它

* 临时字段

复杂算法, 需要变量, 所以将这个变量放到了类的字段中. 这些字段只有在算法中才有效. 
或者, 有些字段仅仅是定义了但是根本没有使用. 

* 过度耦合的消息链.

请求一个对象, 然后向这个对象请求对象, 再向得到的对象请求对象. 
代码中的表现就是一大串的 get 函数和一长串的临时变量.
这种方式, 就意味着代码和对象的关系紧密联系, 一旦对象关系改变了, 那么客户端就必须做出修改了.

* 过多的委托

某个类的接口, 一般的函数都是委托给其他类.

* 纯粹的数据类

只有字段, 以及访问函数, 其他没有任何内容. 尝试将一些调用后的行为, 放置到数据类中.
数据类应该承担一些自己的责任. 

这点, 现在的摩擦代码做的不是很好.

* 子类不想继承父类所有函数和数据

子类如果只是复用父类的某些函数, 还可以接受.
如果子类复用了父类, 但是又不愿意支持父类的接口, 那么就很有问题.

* 过多的注释.

很多时候, 长长的注释存在的原因在于, 代码的质量很糟糕. 所以, 这个时候, 首先应该优化代码的质量, 这个时候去看注释, 那么注释就显得多余了.

