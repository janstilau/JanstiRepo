# STL

容器的大小是固定的, 和里面有多少元素是没有关系的. 因为, 其实他们都是用指针管理所有的元素的, 元素的内容不算到容器的大小里面.

* Sequence containers

ARRAY 就是原来的数组, 只不过编程了类进行管理.
Vector 可以进行单向内容扩充的数组, 和数组一样使用, 在填充满当前的内存之后, 会分配一个更大的内存, 将原来的管理的内存拷贝过去.
Deque 可以进行双向内容扩充的数组, 内部是用一个指针数组构成的, 指针数组每一个项管理一块内存区域, 在向前插的时候, 其实是在扩充指针数组, 例如, deque 里面在自己的数组里面放入一个新的指针, 然后在指针管理的内存里放实际的值. Deque 也可以像数组那样使用, 是因为迭代器和[]操作符都有重载, 会自动跨界.
Stack, queue 都是用 Deuqe 实现的, 可以看成 Dqueue 的一个适配器.

List 链表, 双向链表
Forward -list 单向链表

* Associative Containers

Set, Map, MultiSet, MultiMap 内部有一个红黑树 (rb-tree 高度平衡的二叉树) 进行管理, set 的树节点只有一个值, map 的树节点是 key, value 两个值. 因为是树, 所以其实有排序的过程. 对于 multi, 相同 key 的节点, 铁定是相邻的节点.

Unordered Containers
真正的用哈希表 hash_table 进行管理的, 解决冲突的方式是用 链表.

## 分配器 -- 主要为容器分配内存空间

STL 里面的默认的分配器都是 allocator.
allocate --> operator new --> malloc, 最终会使用 c 的 malloc 分配内存.
deallocate --> operator delete --> free. 最终使用 c 的 free 回收内存.

malloc 分配的内存, 会有额外开销, 会有一些附加的东西, overhead, 这些附加的东西是固定的. 所以, 要求分配的内存大, 有效的内容占用量就大, 如果每次都要一点点东西, 那么这些额外的开销会非常大.

额外开销里面, 有 cookie 用于记录分配空间的整个大小, 由于有这个东西, free 才能正确的回收. 上下都有一个 cookie ,它们的值是一样的. GNU C 下面的有个 alloc 的分配器, 专门用于容器的分配, 它的策略是, 用 malloc 要一块很大的内存, 然后自己分割这块内存, 这样, 分割的内存, 没有 cookie 值. 这样当很大数字的 items 的时候, 几乎没有 cookie 的占用. 这样就很好地节省了空间. 不过4.9 之后, 又变成了直接用 malloc 来分配每一个对象了, GNU C 的那个专门用于容器的分配的分配器叫做了 pool_alloc.

分配器 allocate, deallocate 都需要一个数字, 表示需要多少内存. 所以作为编程人员很难使用, 因为人不会去记忆到底要了多少内存. 所以, 我们直接用容器, 让容器自己去管理这个数字.

## List

GNU 2.9 版本
List 里面, 只有一个头结点, 而这个头结点, 里面只有三个内容, next, prev 和一个 data. 所有一个 list 的大小, 只是一个节点的大小.
List 里面, 定义了自己的迭代器. 迭代器就是模拟数组指针的动作. 所以可以看成一个泛型的指针. 那么一个链表的 iterator 应该怎么设计呢.

iterator 里面, 会有大量的操作符重载, 用来模拟指针的行为.

一个 List 的 iterator 里面, 应该会有一个节点在里面, 在++的时候, 会更新这个节点指向自己的 next ,* 的时候, 会返回节点里面的值, -- 的时候, 会让节点指向 previous.

在 list 的尾巴节点后面, 还有一个空的节点, 专门作为 end 的返回的 iterator 所控制的 node.

iteraotr 一般由两个部分构成

1. typedef, 这是由于 iterator_traits 规定的
1. 操作符重载, 用于模仿指针的操作.

## 迭代器 --> 算法和容器的桥梁, 算法通过 iterator 知道范围和具体的元素值.

算法需要知道 iterator 的一些特性, 才能完成自己的运算步骤. 比如, 这个 iterator 要能够随机访问. 这个东西叫做 iterator 的分类, 有个可以往回走, 有个可以跳着走.

Category 分类
Distance_type 距离
Value_type 值类型
Poitner
Reference

算法会提问5种, 不过后面两种没有被使用过.

所以, iterator 里面会有大量的 typedef, 将上面五种类型定义出来. 然后在算法里面直接使用.

比如, 一个算法是这样, 我们可以看到, 他是直接用了 T::value_type 这样的方式进行类型的标明, 也就是说, 你的 iterator 里面如果没有这样的 typedef ,编译一定是过不去的.

```cpp
template <typename T>
void algorithm(T first, T second) {
  T::iterator_category 
  T::Pointer
  T::value_type
}
```

但是, 如果 iterator 不是一个 class, 那么它怎么回答上面的问题. 指针, 本身就是一种 iterator. 所以, 有一个 iterator tarits 用来区分是 class 的 iterator, 还是指针的 iterator. 这是一个中间层. 解决计算机问题, 就是增加一个中间层. silver bullet.

这里太复杂, 用的时候再来一次就可以了. 其实是利用了模板的偏特化解决的这个问题.

## vector

动态增长的数组. 里面有三个指针, start, end, finish. size 是 start 和 finish 的举例, capacity 是 start 和 end 的举例.
任何数组都不能原地扩充的, vector 只不过是在另外一个空间申请更大的内存空间, 然后将原来的内容原封不动的搬过去而已. vector 是用两倍增长的策略.

源码里面有个设计, size 是调用了 end() - begin(), 而这两个方法里面是简单的 return 指针的操作. 为什么不直接用两个指针相减呢. 其实是为了代码的固定, 如果在代码里, 用了很多的成员变量, 那么想要修改实现的时候, 就会牵扯到很多地方. 现在通过函数调用, 只用修改 begin 和 end 的实现就可以了.

vector 扩充的时候, 需要大量的消耗.

vector 的迭代器, 就是用的 T* 作为 iterator. Typedef T* iterator.

在算法里面, 根据萃取机取 iterator 的那几个类型的时候, 会走向 指针的偏特化实现.

## array <typename _Tp, std::size_t _Nm>

就是 C 语言的数组, 为什么要包成容器. 因为它要提供 iterator 迭代器, 迭代器里面, 要提供那5个 type, 然后在算法里面要用到这些. 所以, 为了让算法那可以把数组当成一个容器来用, 用一个类将 array 进行了包装.

array 里面, 没有 ctor, dtor, 直接定义了一个数组. 数组的长度, 就是传入的数值.

array 的 iterator 也是指针, 只要是连续空间, 就可以用指针作为迭代器.

## forward list 和 list 差不多, 只不过没有向前的指针

## deque

分段串接buffer. 在使用者看来, 是连续的. 在内部有一个 vector, vector 里面存放指向各个 buffer 的指针. 如果在尾端扩充, 需要新开辟一个缓存区, 然后将这个缓存区的指针放入 vector 里面. 如果在前面扩充

deque 的迭代器, 里面有四个数据, cur, first , last, node. first, last 指向 buffer 的头尾, cur 指向 buffer 的现在迭代位置. node 指向 vector 里面的一个元素, 当越界的时候, 根据 node 进行越界操作.

一般来说, 容器里面会维护 begin, end 迭代器的值, 因为这两个数值用的太频繁了.

deque.insert 如果位置靠前, 那么就是向前推, 否则就是向后推.

对于一个操作, 它的反操作, 一定是调用 这个操作完成的. 例如, == 操作, 就可以作为!= 的反操作, 这样, 明确的逻辑实现只用写一次就好. 这样是比较规范的编程方式.

debue 里面, 为了模拟连续的概念, 在迭代器里面应用了大量的操作符重载. 例如, size 函数里面, 是简单地 finish - start, 两个都是迭代器. 那么在迭代器里面, - 做了重载, 那么这个重载就是, 计算 finish, start 的 node 之间有多少个 缓存区域, 然后乘以缓存区域的 size, 然后在加上 start 的缓存区域那一小段和 finish 缓存区域的那一小段. 这就是最终的 size 了. 但是作为调用看起来, 迭代器相减得出 size 出来, 这和指针相减是一模一样的. 所以, 我们之前说过很多次了, 迭代器, 就是泛型指针, 在里面做了大量的操作符重载操作, 来完成指针的功能.

在 ++ 的时候, 首先会判断 cur 是不是在 buffer 的 last, 如果是, 就将 node ++, 然后 cur 编程 first. 这样就完成了跨界.
在 -- 的时候, 逻辑和上面一样, 不过是到前一个缓存区而已.
在 += 的时候, 如果增加之后还在一个缓存区里面, 那么直接修改 cur 就好了, 不然的话, 计算 node 的更改之后的位置, 更改 node 的指向, 然后修改 cur 的位置.
在 -=, -, +, [] 的时候, 都是用了 += 的实现.

作为控制中心的 vector, 每次都是从中间开始, 当需要扩充的时候, 也是把原来的值 copy 到新的 vector 的中间, 这样就保证了, 前后都可以进行扩充.

stack 和 queue 可以认为是功能受限的 deque, 在内部实现的时候, 也是 stack 和 queue 里面有一个 deque, 然后接口里面只是调用 deque 的借口而已. 所以, stack, queue 被认为是 deque 的适配器, 而不是真正的容器. 并且不提供 iterator. list 也可以作为 stack, queue 的底层实现, 因为它实现了 stack, queue 所需要那些接口. stack 也可以用 vector 作为底层结构. 所以, 知道了实现, 就有了很多选择的余地. 语言是默认用 deque 作为底层的实现的.

编译器在检查模板的时候, 是不会提前做检查的, 只有用到的地方才会做检查. 作为 queue, 有一个 pop方法, 是需要底层结构 pop_front, 但是 vector 没有 pop_front. 但是, 如果你用 vector 作为queue 的底层实现, 只要没有调用 pop 方法, 编译器还是能够通过的. 这需要警示. 有的时候添加了一个代码就出错了, 很有可能是因为模板的原因.

## 关联式容器

可以认为是一个小型的数据库.

## 红黑树

平衡二叉搜索树, 排列规则有利于 search 和 insert, 并且可以保持适度的平衡, 不会让某个节点过深.

红黑树的根节点, 一定大于左树, 小于右树.

红黑树提供了遍历操作以及 iterator. 按照 ++it 进行遍历的话, 就可以得到排序的状态. 中序遍历的方式.

红黑树 提供了两种 insert, insert_unique, 表示 key 是独一无二的, insert_equal 可以重复. 重复的 key 值, 所在的结点一定是相邻的, 但是为了保持高度平衡, 可能会更改树的结构.

对于红黑树来说, key 和 data 合起来叫做 value. 所以红黑树的模板 <Key, Value, KeyOfValue, Compare, Alloc>

红黑树里面的数据 node_count, headerNode, compareObject;

对于大小为 0 的 class, 它的实例会变成 1 .

红黑树的 header 是一个空结点, 是为了实现的方便特意加上去的.

rb_tree<int, int, identity<int>, less<int>, alloc> myTree;

identity<int>, 仿函数.

Handle and body.

## set 和 multiSet

用 rb_tree 作为底层结构, 所以可以自动排序, 排序的依据就是 key, set 里面的元素, 是 key 和 value 合一, value 就是 key.

begin, ++, ==end 得到的就是一个有序的状态.

无法通过迭代器修改里面的值. 实现是, set 里面的 iterator 是用的红黑树的 const iterator.

set 的所有操作, 都是转调用到自己的红黑树. 所以, set 可以看成是红黑树的适配器.

## map 和 multimap

用 rb_tree 作为底层结构, 所以自动排序

无法通过 iterator 来改变元素的 key, 但是可以改变元素的 data.

map 元素的 key 必须是独一无二的, 但是 multimap 的 key 可以重复. 所以 map 的 insert 调用的是 insert_uniqe, multimap 调用的是 insert_equal.

[] 操作符的实现.

 首先, lower_bound, 这是一个二分查找的变体, 如果找到, 就返回该位置的 data 值, 如果没有找到, 可以返回一个应该插入位置的迭代器, 根据这个迭代器就可以 insert 一个 default 构造函数生成的对象.

## hashtable

如果元素个数, 要比篮子多, 就要重新分配篮子变成原来的两倍附近的素数, 并且重新设计哈希函数.

虽然书本上, 有很多解决冲突的办法, 但是根据科学家的经验来说, 现在用链表进行冲突的解决, 是现在最有效的办法. 虽然 list 是线性的搜索, 但是首先 hash 能够减少绝大部分的搜索量. 并且, 良好的 hash 设计, 可以让链表不会过大, 当过大的时候, 需要重新打散到不同的篮子里面.

unordered_set, unordered_multiset
unordered_map, unordered_multimap