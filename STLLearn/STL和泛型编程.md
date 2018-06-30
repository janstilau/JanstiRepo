# STL 和 泛型编程

## STL 六大部件

* 容器    Container
* 分配器  Allocator
* 算法    Algorithm
* 迭代器  Iterator
* 适配器  Adapter
* 仿函数  Functor

容器, 解决的是内存的问题. 它的背后支持, 是分配器.
对于一些通用的操作, 会被抽取出来成为算法, 支持容器.
而算法为了访问容器的数据, 会用到迭代器, 迭代器可以认为, 是一种泛型化的指针.

仿函数, 作用就像一个函数.
适配器, Adapter, 适配器, 变压器, 可以转化容器, 迭代器, 仿函数.

面向对象的时候, 对象包含了数据和算法, 但是模板编程的时候, 确是把操作抽取出来.

```cpp
int main_1()
{
    int ia[6] = {1, 2, 3, 4, 5, 6};
    vector<int, allocator<int>> vi(ia, ia + 6);
    // <>代表模板, 里面可以指定元素的类型, 第一个只是容器存放元素的类型, 第二个是分配器的类型, 一般容器都是有默认的分配器的,
    // 分配器也是模板, 要指明里面分配什么类型, 如果分配器指定的类型和容器类型不匹配. 会出问题.
    /*
     * static_assert((is_same<typename allocator_type::value_type, value_type>::value),
     * "Allocator::value_type must be same type as value_type");
     */

    count << count_if(vi.begin(), vi.end(), not1(bind2nd(less<int>(), 40)));

    // 对于排序, 我们可以 1. 传入一个函数指针, 2. 传入一个提供了比较接口的接口对象 3. 在函数可以直接传入的语言里面, 传入这个函数, 例如, 兰木达表达式和闭包
    // 4 传入一个仿函数

    // 标准库规定, [), begin, end 是前闭后开, 就是 begin 指向第一个元素, end 指向最后一个元素的后一个位置.
    // ++it, --it, *it.

    // 循环, for 比 while 的好处在于, 弹性.

    auto it = vi.begin();
    return 0;
}

```

## 容器结构和分类

### 序列式 Sequence Container: 按照放进去的顺序来排列

* array 不是语言层面的 数组, 而是在 class 的层面上, c++11添加了 array 的一个容器类, array 是一个定量的容器, 开始设置多少容量, 就是多少, 不可以扩展
* vector, 后面可以自动增长, 当要越界的时候, 分配器会自动扩充. 分配器会用双倍增长的方式扩充空间.
* deque 读音是 deck, 双向可以扩充.
  在 deque 的内部, 其实是有多个 buffer, 然后利用这多个 buffer , 造成可以向前扩充的假象, 在 deque 里面, 有一个 buffer 的指针域, 这个指针域里面的指针是有序的, 当 push_front 的时候, 如果没有空间了, 就可以新创建一个 buffer, 然后将这个 buffer 排在指针域的前面. 需要注意的是, deque 的迭代器, 也是需要处理 buffer 的越界的问题. 一句话, deque 是分段连续. 每次扩充多少, 这个问题是
* list 用指针串起来的链表, list 里面的链表是一个双向链表.
* forward-list 单向链表.

### 关联式 Associative Container : key - value --> 适合做快速的查找

用红黑树实现, 高度平衡二分树, 红黑树.

* set, set 的每一个节点, 只有一个值.
* map, map 的每一个节点, 都有 key 和 value
* multiset
* multimap

Unordered Container( 关联式的一种特殊容器 )

HashTable + separate chianing, 碰撞了之后, 用链表管理相同哈希值的对象.

当元素的个数, 大于等于篮子的个数的时候, 那么篮子的个数会扩充两倍. 这是一个经验之谈.

* hashTable + 链表 达成
