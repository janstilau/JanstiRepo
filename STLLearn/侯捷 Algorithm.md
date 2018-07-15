# 算法

算法, 是一个 function template. 算法, 是操作容器的. 但是算法又看不到容器里面的内容, 所以需要迭代器.

而迭代器, 是容器提供的. 算法会问迭代器一些问题, 迭代器的内部, 会回答这个问题. 通过这个回答, 算法可以用最有效的方式操作这个容器. 比如, 迭代器移动的方式, 可不可以随机访问等等. 这些其实都是容器的内部体现.

而迭代器回答的这一部分, 在 STL 的讲解中也有涉及, 就是萃取机里面定义的那5个类型.

iterator_category 移动的分类

input_tag
output_tag
forawrd_tag: public input_tag 单向
bidirectional_tag: public forawrd_tag 双向
random_access_tag: public bidirectional_tag 随机访问

在标准库里面, 有5个 struct, 表示上面的不同分配.

为什么不用 enum 表示呢.
首先, 用类型可以用函数重载进行调用的分发, 下面的例子里面可以看到.
再者, 可以利用继承关系. 例如, 很多的分发都是 random 和 input 的不同, 但是都是 input 的子类. 所以, 其实是 random 这个特例和上面四种不同.

算法是怎么通过问答进行不同的操作呢. 算法里面有个 distance, 里面会先通过萃取机拿到 category 类型, 然后传入__ distance 里面, 这个__ distance 的第三个传入这个类型的一个临时对象, 通过这个临时对象的类型不同, 进行函数重载. 如果是 random 的, 就直接相减了, 如果不是, 就用 while(first != end) 一步步计算出这个步数. 如果数值量超级大, 这两种效率差太多了.

例如还有一个 advanece 函数, 用于更改迭代器位置, 根据 input, bidirection, random 的不同, 算法也不同, 步骤也是, 先用萃取机拿category的类型, 然后有三个函数同名, 通过 category 的类型进行重载. 如果是 random 的, 直接 i+= n 就可以了, 如果是 bidirectoin的, 那么可以向前走, 如果是 input 的只能向后走, 不过后面这两种, 只能 while 循环一步步改变 iterator 的位置.

算法的源码里面, typename 的部分的命名有很多的暗示. 但是没有真正的约束. 比如, sort 的typename 叫做 randomAccessIterator.

## 算法示例

### C

qsort
bsearch

### ALGORITHEM C++

find
sort
accumulate 接受头尾两个指针, 一个初值. 第二个版本, 多了一个二元操作.

```cpp
// 泛化版本
template  <typename InputIterator, typename T>
T accumulate(InputIterator first, InputIterator last, T init)
{
    for (; first != last ; ++first) {
        init += *first;
    }

    return init;
};

// BinaryOperation只是一个建议, 说明应该传入一个二元操作仿函数. 但是编写的时候没有强制要求, 如果在这个模板函数的编写的时候, 没有按照二元操作那么用, 就是模板函数编写有问题,
// 如果传入的值不是一个二元操作, 就是调用者有问题. 这是文档的规范作用, 如果不按照规范进行操作, 是使用者的问题. 这就是文档的规范作用, 因为实际上, 并不能靠编译器做所有的规范.
// 其实在这里, iterator 里面的 value_type, 也应该是 T 类型, 才能让这个函数模板正常工作. 如果传错的话, 也是会有编译问题的.
// 传入一个二元操作, 可以进行特殊化的处理.
template <typename InputIterator, typename T, typename  BinaryOperation>
T accumulate(InputIterator first, InputIterator last, T init, BinaryOperation binary_op)
{
    for (; first != last; ++first) {
        init = binary_op(init, *first);
    }

    return init;
};

// 测试上面的代码. 注意, 这里我们看到, nums传入的不是一个类型迭代器, 而是一个指针, 但是, 所谓迭代器就是模拟指针的一个类而已, 在之前的 迭代器
// 萃取机的代码里, 还专门对指针做了处理, 也就是说, 指针其实就是一种迭代器.
// accumulate 里面其实根本不关心是不是迭代器, 只要传入的这个 first, last, 可以有++操作, 可以有*操作, 编译器就认为传入的东西合法. 而这些, 一个 int* 是都符合的.
void test_accumulate()
{
    struct  {
        int operator() (int x, int y) {
            return x + 2 * y;
        }
    } add;
    // callable item, 包括函数对象, 也能传入一个函数.
    // 这里 c++的实现和函数作为第一类型的语言应该有所不同. c++ 复杂的原因在于, 编译器做了很多的 implicit adapter 的工作. 一个函数和一个函数对象, 在内存里面是不同的表现, 但是, 在模板里面, 两种都能用 () call operator 正确的通过编译.
    // 但是在其他的语言里面, 函数, 闭包等等等等, 都是一个对象.
    int nums[] = {10, 20 ,30};
    int init = 100;
    accumulate(nums, nums + 3, init);
    accumulate(nums, nums + 3, init, add);
}

// 这里还是要多说一句, Function 到底是什么, 首先它的处理逻辑, 一定是处理 InputIterator 里面的内容, 如果不是, 编译铁定报错. 而 InpuInteraotr 是什么, 它铁定要有一个 *, ++ 的操作符重载, 如果没有, 铁定报错, 但是这些都不是说模板的 typename 可以限制的. 这只是一个别名而已.
template <class InputIterator, class Function>
Function for_each(InputIterator first, InputIterator last, Function f)
{
    for (; first != last; ++first) {
        f(*first);
    }
    return f;
};
// 所以, 其实我们可以想象一下 ranged for 的实现方式, 和上面有什么区别呢. 这也说明了, 为什么 ranged for 在遍历的时候, 其实是有顺序的.

// 所以, 其实现在 C++ 和 JS 有什么区别. C++ 现在由 lambda 表达式, 它的内存表现, 就像是一个 factor 仿函数, 这样, 我们也可以很容易的写出一个传入 函数调用做参数的 函数式编程的函数出来. 只不过, c++ 有着太多的历史包袱, 要兼容之前的特性, 所以现在显得异常的臃肿.

// replace 操作簇

// 这里还是要多说一句, Function 到底是什么, 首先它的处理逻辑, 一定是处理 InputIterator 里面的内容, 如果不是, 编译铁定报错. 而 InpuInteraotr 是什么, 它铁定要有一个 *, ++ 的操作符重载, 如果没有, 铁定报错, 但是这些都不是说模板的 typename 可以限制的. 这只是一个别名而已.
template <class InputIterator, class Function>
Function for_each(InputIterator first, InputIterator last, Function f)
{
    for (; first != last; ++first) {
        f(*first);
    }
    return f;
};

// 这里 ForwardIterator 里面要完成 ==, *, =, ++ 操作符的重载操作, 用来支持这个算法.
template <class ForwardIterator, class T>
void replace(ForwardIterator first, ForwardIterator last, const T& old_value, const T& new_value)
{
    // 范围内所有等于 old_value 的都要用 new_value 进行替代
    for (; first != last; ++first) {
        if (*first == old_value) {
            *first = new_value;
        }
    }
};

template <class InputIterator, class OutputIterator, class T>
OutputIterator replace_copy( InputIterator first, InputIterator last, OutputIterator result, const T& old_value, const T& new_value)
{
    // 范围内, 所有等于 old_value 的用 new_value 代替, 不等于的放入 result 区间内部
    for (; first != last; ++first, ++result)
    {
        *result = *first == old_value ? new_value: *first;
    }

    return result;
};

template <class ForwardIter, class Predicate, class T>
void replace_if(ForwardIter first, ForwardIter last, Predicate pred, const T& new_value)
{
    for (; first != last; ++first)
    {
        if (pred(*first)) {
            *first = new_value;
        }
    }
};

// count 函数簇
// set, map, unorder map, set 里面有自己的 count 函数, 下面的是线性容器库的 count 函数的实现. 其实, 也可以想象, 这些关联式的容器里面应该会有一个成员变量记录 count 值.
template <class InputIterator, class T>
typename iterator_traits<InputIterator>::difference_type // 这里的 typename 表示, difference_type 是 depend on InputIterrator
count (InputIterator first, InputIterator last, const T&value)
{
    typename iterator_traits<InputIterator>::difference_type n = 0;
    for (; first != last; ++first)
    {
        if (*first == value) {
            ++n;
        }
    }
    return n;
};

template <class InputIterator, class Predicate>
typename iterator_traits<InputIterator>::difference_type
count_if(InputIterator first, InputIterator last, Predicate pred)
{
    typename iterator_traits<InputIterator>::difference_type  n = 0;
    for (; first != last; ++first)
    {
        if (pred(*first)) {
            ++n;
        }
    }
    return n;
};

// find 函数簇
template <class InputIterator, class T>
InputIterator find(InputIterator first, InputIterator last, const T& value)
{
    while (first != last && *first != value) {
        ++first;
    }

    return *first;
};

template <class InputIteraotr, class Predicate>
InputIteraotr find_if(InputIteraotr first, InputIteraotr last, Predicate pred)
{
    while (first != last && pred(*first))
    {
        ++first;
    }

    return first;
};

// sort 函数簇
// sort 的内部实现比较复杂, 没有列出源代码. sort 也分两种形式, 一种只接受 first, last 的 Iterator, 一种还另外的增加一个比较函数. 这个比较函数的默认实现, 就是调用 *first < *first, 就是用< 符号进行比较. 之所以可以接受比较函数, 是为了兼容, 很多自定义的类型, 其实是需要自定义比较函数的.
// 另外, sort 其实是 randomAccessIterator, 所以 list, 和 forward_list 并不能用 sort 函数.
// 对于 associative container, 也没有 sort 函数的定义. 因为, 他们要么本身就有 sort 的功能, 要么就不应该 sort.


template <class ForwardIterator, class T>
ForwardIterator lower_bound(ForwardIterator first, ForwardIterator last, T val) // 在不违反排序的状态下, 安插这个值得最低点, 相对应的是 upper_bound
{
    ForwardIterator it;
    iterator_traits<ForwardIterator>::difference_type  count, step;
    count = std::distance(first, last); // 在之前讲解iterator_traits 讲过, distance 内部, 会根据 iterator 的 category 的不同, 执行不同的代码
    while (count > 0) {
        it = first;
        step = count / 2;
        std::advance(it, step);
        if(*it < val) {
            first = ++it;
            count -= step + 1;
        } else {
            count = step;
        }
    }
    return first;
};

template <class ForwardIterator, class T>
bool binary_search(ForwardIterator first, ForwardIterator last, const T& value)
{
    first = lower_bound(first, last, value);
    return (first != last && !(value < *first));
};

```

## revere Iterator

```cpp
reverse_iterator
rbegin()
{
  return reverse_iterator(end())
}



```