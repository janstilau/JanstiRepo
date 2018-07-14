# 算法

算法, 是一个 function template. 算法, 是操作容器的. 但是算法又看不到容器里面的内容, 所以需要迭代器.

而迭代器, 是容器提供的. 算法会问迭代器一些问题, 迭代器的内部, 会回答这个问题. 通过这个回答, 算法可以用最有效的方式操作这个容器. 比如, 迭代器移动的方式, 可不可以随机访问等等. 这些其实都是容器的内部体现.

而迭代器回答的这一部分, 在 STL 的讲解中也有涉及, 就是萃取机里面定义的那5个类型.

iterator_category 移动的分类

input_tag
output_tag
forawrd_tag: public input_tag
bidirectional_tag: public forawrd_tag
random_access_tag: public bidirectional_tag

在标准库里面, 有5个 struct, 表示上面的不同分配.

为什么不用 enum 表示呢. 
首先, 用类型可以用函数重载进行调用的分发, 下面的例子里面可以看到.
再者, 可以利用继承关系. 例如, 很多的分发都是 random 和 input 的不同, 但是都是 input 的子类. 所以, 其实是 random 这个特例和上面四种不同.

算法是怎么通过问答进行不同的操作呢. 算法里面有个 distance, 里面会先通过萃取机拿到 category 类型, 然后传入__ distance 里面, 这个__ distance 的第三个传入这个类型的一个临时对象, 通过这个临时对象的类型不同, 进行函数重载. 如果是 random 的, 就直接相减了, 如果不是, 就用 while(first != end) 一步步计算出这个步数. 如果数值量超级大, 这两种效率差太多了.

例如还有一个 advanece 函数, 用于更改迭代器位置, 根据 input, bidirection, random 的不同, 算法也不同, 步骤也是, 先用萃取机拿category的类型, 然后有三个函数同名, 通过 category 的类型进行重载. 如果是 random 的, 直接 i+= n 就可以了, 如果是 bidirectoin的, 那么可以向前走, 如果是 input 的只能向后走, 不过后面这两种, 只能 while 循环一步步改变 iterator 的位置.

算法的源码里面, typename 的部分的命名有很多的暗示. 但是没有真正的约束. 比如, sort 的typename 叫做 randomAccessIterator.