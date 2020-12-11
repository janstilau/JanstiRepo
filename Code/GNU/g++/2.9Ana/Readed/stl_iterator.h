#ifndef __SGI_STL_INTERNAL_ITERATOR_H
#define __SGI_STL_INTERNAL_ITERATOR_H

__STL_BEGIN_NAMESPACE

/*
 iterator_category 并不是实际业务使用的类型. 它最大的作用, 是通过不同的迭代器, 分发算法的调用.
 不同的 iterator 定义了不同的 iterator_category.
 在算法里面, 首先是获取到 iterator_category 的类型, 整个逻辑, 是放到了 iterator_traits 里面.
 根据 iterator_category 生成不同类型的对象.
 这个对象, 会作为函数的参数, 不同的函数, 根据这个参数的类型进行分发. 这就是 c++ 里面, 进行萃取的机制.
 */

/*
 算法看不到容器, 对容器是一无所知的, 所以, 它所需要的任何信息, 都必须从迭代器中获取.
 而迭代器, 必须能够回到算法的所有提问, 才能够满足算法的所有的操作.
 */

/*
 从这个实例中, 我们可以看到, 各个函数重载,就是根据参数的类型, 调用了最准确的方法.
 迭代器并不直接继承自 category, 迭代器内部, 提供了自己所属的 category 的信息. 从这个意义上来看, typedef, 可以算作是这个迭代器的元信息.
 迭代器的 category 的类型意义就是函数的分发操作.
 */
namespace jj33
{
void _display_category(random_access_iterator_tag)
{   cout << "random_access_iterator" << endl; }
void _display_category(bidirectional_iterator_tag)
{   cout << "bidirectional_iterator" << endl; }
void _display_category(forward_iterator_tag)
{   cout << "forward_iterator" << endl;  }
void _display_category(output_iterator_tag)
{   cout << "output_iterator" << endl;   }
void _display_category(input_iterator_tag)
{   cout << "input_iterator" << endl;    }

template<typename I>
void display_category(I itr)
{
    // 这里, 是通过 iterator_traits<I>::iterator_category 生成一个对象出来, 然后这个对象, 传入到函数中.
    // 通过这个对象的不同, 进行不同的方法的调用.
    typename iterator_traits<I>::iterator_category cagy;
    _display_category(cagy);
    cout << "typeid(itr).name()= " << typeid(itr).name() << endl << endl;
}

void test_iterator_category()
{
    cout << "\ntest_iterator_category().......... \n";
    
    display_category(array<int,10>::iterator());
    display_category(vector<int>::iterator());
    display_category(list<int>::iterator());
    display_category(forward_list<int>::iterator());
    display_category(deque<int>::iterator());
    
    display_category(set<int>::iterator());
    display_category(map<int,int>::iterator());
    display_category(multiset<int>::iterator());
    display_category(multimap<int,int>::iterator());
    display_category(unordered_set<int>::iterator());
    display_category(unordered_map<int,int>::iterator());
    display_category(unordered_multiset<int>::iterator());
    display_category(unordered_multimap<int,int>::iterator());
    
    display_category(istream_iterator<int>());
    display_category(ostream_iterator<int>(cout,""));
}
}

// 五种 category, 不是根据 type 值来进行区分, 而是通过类型.
struct input_iterator_tag {};
struct output_iterator_tag {};
struct forward_iterator_tag : public input_iterator_tag {};
struct bidirectional_iterator_tag : public forward_iterator_tag {};
struct random_access_iterator_tag : public bidirectional_iterator_tag {};

template <class T, class Distance> struct input_iterator {
    typedef input_iterator_tag iterator_category; // 迭代器的类型
    typedef T                  value_type; // 迭代器里面的 value_type
    typedef Distance           difference_type; // 迭代器的距离
    typedef T*                 pointer; // 迭代器里面的 pointer
    typedef T&                 reference; // 迭代器里面的 ref.
};

// 不同的迭代器, 它的 typedef 的不同, 剧烈地影响算法的实现. 而不同的算法调用的选择, 是通过 typedef 生成临时对象分化的.
// C++ 里面的算法, 都是迭代器作为基本的参数. 所以, 这些不同的 tag 的定义, 是影响到整个标准库的.

struct output_iterator {
    typedef output_iterator_tag iterator_category;
    typedef void                value_type;
    typedef void                difference_type;
    typedef void                pointer;
    typedef void                reference;
};

template <class T, class Distance> struct forward_iterator {
    typedef forward_iterator_tag iterator_category;
    typedef T                    value_type;
    typedef Distance             difference_type;
    typedef T*                   pointer;
    typedef T&                   reference;
};


template <class T, class Distance> struct bidirectional_iterator {
    typedef bidirectional_iterator_tag iterator_category; // 双向的
    typedef T                          value_type;
    typedef Distance                   difference_type;
    typedef T*                         pointer;
    typedef T&                         reference;
};

template <class T, class Distance> struct random_access_iterator {
    typedef random_access_iterator_tag iterator_category; // 可以随机存储的.
    typedef T                          value_type;
    typedef Distance                   difference_type;
    typedef T*                         pointer;
    typedef T&                         reference;
};



#ifdef __STL_USE_NAMESPACES
template <class Category, class T, class Distance = ptrdiff_t,
class Pointer = T*, class Reference = T&>
struct iterator {
    typedef Category  iterator_category;
    typedef T         value_type;
    typedef Distance  difference_type;
    typedef Pointer   pointer;
    typedef Reference reference;
};
#endif /* __STL_USE_NAMESPACES */

#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION
// iterator_traits 类的定义.
// 如果, 传递过来的类型是类型的话, 就是使用 类型里面定义的 iterator_category 作为 iterator_category
template <class Iterator>
struct iterator_traits {
    typedef typename Iterator::iterator_category iterator_category;
    typedef typename Iterator::value_type        value_type;
    typedef typename Iterator::difference_type   difference_type;
    typedef typename Iterator::pointer           pointer;
    typedef typename Iterator::reference         reference;
};

// 如果, 传过来的类型是指针的话, 就是使用 random_access_iterator_tag 作为 iterator_category;
template <class T>
struct iterator_traits<T*> {
    typedef random_access_iterator_tag iterator_category;
    typedef T                          value_type;
    typedef ptrdiff_t                  difference_type;
    typedef T*                         pointer;
    typedef T&                         reference;
};

template <class T>
struct iterator_traits<const T*> {
    typedef random_access_iterator_tag iterator_category;
    typedef T                          value_type;
    typedef ptrdiff_t                  difference_type;
    typedef const T*                   pointer;
    typedef const T&                   reference;
};

// std::iterator_category 的定义, 就是根据 iterator_traits 这个类, 来进行萃取.
// 为什么要有这个方法呢. iterator, 定义了五种 typedef, 对于 difference_type, 和 value_type, 都是可以在函数里面直接使用的. 但是, category 的不同, 代表着可以进行的操作不同, 也就函数的实现不同, 需要在函数调用之前, 就得到 category 然后利用它调用不同的函数.
// 调用不同的函数, 就是使用函数重载中的参数类型不同实现的.
// 所以, 必须要有一个机制, 能够获取到, iterator 中各种定义的东西, 那么这个机制, 就是 iterator_traits
template <class Iterator>
inline typename iterator_traits<Iterator>::iterator_category
iterator_category(const Iterator&) {
    typedef typename iterator_traits<Iterator>::iterator_category category;
    return category();
}

// 直接用 iterator_traits 里面的 difference_type 作为类型.
template <class Iterator>
inline typename iterator_traits<Iterator>::difference_type*
distance_type(const Iterator&) {
    return static_cast<typename iterator_traits<Iterator>::difference_type*>(0);
}

template <class Iterator>
inline typename iterator_traits<Iterator>::value_type*
value_type(const Iterator&) {
    return static_cast<typename iterator_traits<Iterator>::value_type*>(0);
}

#else /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class T, class Distance> 
inline input_iterator_tag 
iterator_category(const input_iterator<T, Distance>&) {
    return input_iterator_tag();
}

inline output_iterator_tag iterator_category(const output_iterator&) {
    return output_iterator_tag();
}

template <class T, class Distance> 
inline forward_iterator_tag
iterator_category(const forward_iterator<T, Distance>&) {
    return forward_iterator_tag();
}

template <class T, class Distance> 
inline bidirectional_iterator_tag
iterator_category(const bidirectional_iterator<T, Distance>&) {
    return bidirectional_iterator_tag();
}

template <class T, class Distance> 
inline random_access_iterator_tag
iterator_category(const random_access_iterator<T, Distance>&) {
    return random_access_iterator_tag();
}

template <class T>
inline random_access_iterator_tag iterator_category(const T*) {
    return random_access_iterator_tag();
}

template <class T, class Distance> 
inline T* value_type(const input_iterator<T, Distance>&) {
    return (T*)(0);
}

template <class T, class Distance> 
inline T* value_type(const forward_iterator<T, Distance>&) {
    return (T*)(0);
}

template <class T, class Distance> 
inline T* value_type(const bidirectional_iterator<T, Distance>&) {
    return (T*)(0);
}

template <class T, class Distance> 
inline T* value_type(const random_access_iterator<T, Distance>&) {
    return (T*)(0);
}

template <class T>
inline T* value_type(const T*) { return (T*)(0); }

template <class T, class Distance> 
inline Distance* distance_type(const input_iterator<T, Distance>&) {
    return (Distance*)(0);
}

template <class T, class Distance> 
inline Distance* distance_type(const forward_iterator<T, Distance>&) {
    return (Distance*)(0);
}

template <class T, class Distance> 
inline Distance* 
distance_type(const bidirectional_iterator<T, Distance>&) {
    return (Distance*)(0);
}

template <class T, class Distance> 
inline Distance* 
distance_type(const random_access_iterator<T, Distance>&) {
    return (Distance*)(0);
}

template <class T>
inline ptrdiff_t* distance_type(const T*) { return (ptrdiff_t*)(0); }

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

/*
 以上的, 萃取的过程复杂, 主要看下面对于各个功能的实现.
 */

// 用输出参数, 传递距离.
// 一般的迭代器, 想要确定出距离来, 只能通过迭代的方式.
/*
 这个方法的调用者, 在使用 distance 的时候, 会用 iterator_category 方法, 萃取出 category 的临时变量, 然后调用__distance方法.
 __distance 会调用合适的版本的实现.
 distance 方法的调用者, 只会传入 iterator 对象. 而萃取的过程, 分发的过程, 是在标准库里面已经实现的了.
 */

/*
 总体的分发过程, 结果在传出参数中体现.
 必须保证, fist, last 是同种类型的, 当然, 代码里面没有强制的进行限制.
*/

template <class InputIterator, class Distance>
inline void distance(InputIterator first, InputIterator last, Distance& n) {
    __distance(first, last, n, iterator_category(first));
}

/*
 对于普通的迭代器, 只能是通过遍历的方式, 才能获得序列的长度信息
 */
template <class InputIterator, class Distance>
inline void __distance(InputIterator first, InputIterator last, Distance& n, 
                       input_iterator_tag) {
    while (first != last) { ++first; ++n; }
}
/*
 对于随机访问的迭代器, 计算距离, 可以直接通过迭代器相减. 迭代器内部, 要进行相减工作的处理.
 */
template <class RandomAccessIterator, class Distance>
inline void __distance(RandomAccessIterator first, RandomAccessIterator last, 
                       Distance& n, random_access_iterator_tag) {
    /*
     RandomAccessIterator, 必须重载 +, - 运算符, 这是它是 RandomAccessIterator 这种类型的责任.
     如果在 C++ 里面, 没有实现, 编译的时候会抛出错误.
     */
    n += last - first;
}

#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION

/*
 在源码里面, 经常出现实现逻辑相同的函数, 猜测应该是为了适配不同的数据类型.
 */
template <class InputIterator>
inline iterator_traits<InputIterator>::difference_type
distance(InputIterator first, InputIterator last) {
    typedef typename iterator_traits<InputIterator>::iterator_category category;
    return __distance(first, last, category());
}

template <class InputIterator>
inline iterator_traits<InputIterator>::difference_type
__distance(InputIterator first, InputIterator last, input_iterator_tag) {
    iterator_traits<InputIterator>::difference_type n = 0;
    while (first != last) {
        ++first; ++n;
    }
    return n;
}

template <class RandomAccessIterator>
inline iterator_traits<RandomAccessIterator>::difference_type
__distance(RandomAccessIterator first, RandomAccessIterator last,
           random_access_iterator_tag) {
    return last - first;
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

/*
 advance 是将迭代器进行移动, 直接改变了迭代器的值.
 */

template <class InputIterator, class Distance>
inline void advance(InputIterator& i, Distance n) {
    __advance(i, n, iterator_category(i));
}

// 一般的迭代器, 只能向后迭代, 一个个迭代.
template <class InputIterator, class Distance>
inline void __advance(InputIterator& i, Distance n, input_iterator_tag) {
    while (n--) ++i;
}

// 双向的迭代器, 可以向前进行迭代. 一个个迭代.
// 注意, C++ 里面都是静态编译的, 所以打包的时候有问题就直接编译不过了.
// Swift 里面用协议的方式, 进行了更加显示的控制.
template <class BidirectionalIterator, class Distance>
inline void __advance(BidirectionalIterator& i, Distance n, 
                      bidirectional_iterator_tag) {
    if (n >= 0)
        while (n--) ++i;
    else
        while (n++) --i;
}

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma reset woff 1183
#endif

// 可以随机访问的迭代器, 直接进行迭代器的 += 操作.
template <class RandomAccessIterator, class Distance>
inline void __advance(RandomAccessIterator& i, Distance n, 
                      random_access_iterator_tag) {
    i += n;
}


/*
 reverse_iterator 是 Iterator 的适配器.
 各种操作, 都是操作传入的 srcIterator.
 这种操作, 最能体现, 适配器到底是干什么用的.
 */
template <class Iterator>
class reverse_iterator 
{
protected:
    Iterator current;
public:
    typedef typename iterator_traits<Iterator>::iterator_category
    iterator_category;
    typedef typename iterator_traits<Iterator>::value_type
    value_type;
    typedef typename iterator_traits<Iterator>::difference_type
    difference_type;
    typedef typename iterator_traits<Iterator>::pointer
    pointer;
    typedef typename iterator_traits<Iterator>::reference
    reference;
    
    typedef Iterator iterator_type;
    typedef reverse_iterator<Iterator> self;
    
public:
    reverse_iterator() {}
    explicit reverse_iterator(iterator_type x) : current(x) {}
    
    reverse_iterator(const self& x) : current(x.current) {}
#ifdef __STL_MEMBER_TEMPLATES
    template <class Iter>
    reverse_iterator(const reverse_iterator<Iter>& x) : current(x.current) {}
#endif /* __STL_MEMBER_TEMPLATES */
    
    iterator_type base() const { return current; } // 返回原始值.
    /*
     这里, 也就限制了, base iterator, 必须是双向的, 才能进行 -- 操作.
     */
    reference operator*() const {
        Iterator tmp = current;
        return *--tmp;
    }
    pointer operator->() const { return &(operator*()); }
    
    // reverse 的++ , 就是 current 的--. 如果 current 本身就是 reverse, 那就是双重否定
    // base 本身展示出来的, 就是一个 iterator, 本身也可能是一个 reverse_iterator. 虽然在逻辑上, 双重否定还是肯定, 但是调用的时候, 相关的代码还是运转了, 只不过是因为没有副作用而已.
    self& operator++() {
        --current;
        return *this;
    }
    self operator++(int) {
        self tmp = *this;
        --current;
        return tmp;
    }
    self& operator--() {
        ++current;
        return *this;
    }
    self operator--(int) {
        self tmp = *this;
        ++current;
        return tmp;
    }
    
    self operator+(difference_type n) const {
        return self(current - n);
    }
    self& operator+=(difference_type n) {
        current -= n;
        return *this;
    }
    self operator-(difference_type n) const {
        return self(current + n);
    }
    self& operator-=(difference_type n) {
        current += n;
        return *this;
    }
    reference operator[](difference_type n) const { return *(*this + n); }
}; 

/*
 reverse 仅仅是适配器, 真正的数据来源还是 base.
 类型的比较, 就是比较的数据, 所以这里直接是 base 的比较.
 */
template <class Iterator>
inline bool operator==(const reverse_iterator<Iterator>& x, 
                       const reverse_iterator<Iterator>& y) {
    return x.base() == y.base();
}

template <class Iterator>
inline bool operator<(const reverse_iterator<Iterator>& x, 
                      const reverse_iterator<Iterator>& y) {
    return y.base() < x.base();
}

template <class Iterator>
inline typename reverse_iterator<Iterator>::difference_type
operator-(const reverse_iterator<Iterator>& x, 
          const reverse_iterator<Iterator>& y) {
    return y.base() - x.base();
}

template <class Iterator>
inline reverse_iterator<Iterator> 
operator+(reverse_iterator<Iterator>::difference_type n,
          const reverse_iterator<Iterator>& x) {
    return reverse_iterator<Iterator>(x.base() - n);
}



template <class T, class Distance = ptrdiff_t> 
class istream_iterator {
    friend bool
    operator== __STL_NULL_TMPL_ARGS (const istream_iterator<T, Distance>& x,
                                     const istream_iterator<T, Distance>& y);
protected:
    istream* stream;
    T value;
    bool end_marker;
    void read() {
        end_marker = (*stream) __? true : false;
        if (end_marker) *stream >> value;
        end_marker = (*stream) ? true : false;
    }
public:
    typedef input_iterator_tag iterator_category;
    typedef T                  value_type;
    typedef Distance           difference_type;
    typedef const T*           pointer;
    typedef const T&           reference;
    
    istream_iterator() : stream(&cin), end_marker(false) {}
    istream_iterator(istream& s) : stream(&s) { read(); }
    reference operator*() const { return value; }
#ifndef __SGI_STL_NO_ARROW_OPERATOR
    pointer operator->() const { return &(operator*()); }
#endif /* __SGI_STL_NO_ARROW_OPERATOR */
    istream_iterator<T, Distance>& operator++() {
        read();
        return *this;
    }
    istream_iterator<T, Distance> operator++(int)  {
        istream_iterator<T, Distance> tmp = *this;
        read();
        return tmp;
    }
};

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class T, class Distance>
inline input_iterator_tag 
iterator_category(const istream_iterator<T, Distance>&) {
    return input_iterator_tag();
}

template <class T, class Distance>
inline T* value_type(const istream_iterator<T, Distance>&) { return (T*) 0; }

template <class T, class Distance>
inline Distance* distance_type(const istream_iterator<T, Distance>&) {
    return (Distance*) 0;
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class T, class Distance>
inline bool operator==(const istream_iterator<T, Distance>& x,
                       const istream_iterator<T, Distance>& y) {
    return x.stream == y.stream && x.end_marker == y.end_marker ||
    x.end_marker == false && y.end_marker == false;
}

template <class T>
class ostream_iterator {
protected:
    ostream* stream;
    const char* string;
public:
    typedef output_iterator_tag iterator_category;
    typedef void                value_type;
    typedef void                difference_type;
    typedef void                pointer;
    typedef void                reference;
    
    ostream_iterator(ostream& s) : stream(&s), string(0) {}
    ostream_iterator(ostream& s, const char* c) : stream(&s), string(c)  {}
    /*
     向 ostream_iterator 赋值, 就是向 cout 中, 传递数据.
     */
    ostream_iterator<T>& operator=(const T& value) {
        *stream << value;
        if (string) *stream << string;
        return *this;
    }
    ostream_iterator<T>& operator*() { return *this; } // 代表着, 无作用,
    ostream_iterator<T>& operator++() { return *this; }
    ostream_iterator<T>& operator++(int) { return *this; }
};

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class T>
inline output_iterator_tag 
iterator_category(const ostream_iterator<T>&) {
    return output_iterator_tag();
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_ITERATOR_H */

template <class Container>
class insert_iterator {
protected:
    /*
     要存储原有的容器, 以及原有容器的迭代器.
     */
    Container* container;
    typename Container::iterator iter;
public:
    typedef output_iterator_tag iterator_category;
    typedef void                value_type;
    typedef void                difference_type;
    typedef void                pointer;
    typedef void                reference;
    
    insert_iterator(Container& x, typename Container::iterator i)
    : container(&x), iter(i) {}
    
    // insert 函数, 会调用 container 的 insert 方法, 而在 continaer 中, 会做相关的扩容的处理. 然后迭代器 ++.
    // 重载操作符, 把对于 insert_iterator 的赋值行为, 变为插入行为. 然后让迭代器进行 ++ 操作.
    // 操作符重载, 对于 c++ 来说, 真的是非常重要的事情.
    /*
     在 algo 中, 各种算法已经写完了. 通过重载操作符, 或者成为, 抽象函数的调用, 可以将新的类型适配到各个已有的算法中去.
     */
    insert_iterator<Container>&
    operator=(const typename Container::value_type& value) {
        iter = container->insert(iter, value);
        ++iter;
        return *this;
    }
    insert_iterator<Container>& operator*() { return *this; }
    insert_iterator<Container>& operator++() { return *this; }
    insert_iterator<Container>& operator++(int) { return *this; }
};

template <class Container>
class back_insert_iterator {
protected:
    Container* container;
public:
    typedef output_iterator_tag iterator_category;
    typedef void                value_type;
    typedef void                difference_type;
    typedef void                pointer;
    typedef void                reference;
    
    explicit back_insert_iterator(Container& x) : container(&x) {}
    back_insert_iterator<Container>&
    operator=(const typename Container::value_type& value) {
        container->push_back(value);
        return *this;
    }
    back_insert_iterator<Container>& operator*() { return *this; }
    back_insert_iterator<Container>& operator++() { return *this; }
    back_insert_iterator<Container>& operator++(int) { return *this; }
};

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class Container>
inline output_iterator_tag
iterator_category(const back_insert_iterator<Container>&)
{
    return output_iterator_tag();
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class Container>
inline back_insert_iterator<Container> back_inserter(Container& x) {
    return back_insert_iterator<Container>(x);
}

template <class Container>
class front_insert_iterator {
protected:
    Container* container;
public:
    typedef output_iterator_tag iterator_category;
    typedef void                value_type;
    typedef void                difference_type;
    typedef void                pointer;
    typedef void                reference;
    
    explicit front_insert_iterator(Container& x) : container(&x) {}
    front_insert_iterator<Container>&
    operator=(const typename Container::value_type& value) {
        container->push_front(value);
        return *this;
    }
    front_insert_iterator<Container>& operator*() { return *this; }
    front_insert_iterator<Container>& operator++() { return *this; }
    front_insert_iterator<Container>& operator++(int) { return *this; }
};

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class Container>
inline output_iterator_tag
iterator_category(const front_insert_iterator<Container>&)
{
    return output_iterator_tag();
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class Container>
inline front_insert_iterator<Container> front_inserter(Container& x) {
    return front_insert_iterator<Container>(x);
}

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class Container>
inline output_iterator_tag
iterator_category(const insert_iterator<Container>&)
{
    return output_iterator_tag();
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

/*
 一个辅助函数, 生成合适的 insert_iterator 对象.
 */
template <class Container, class Iterator>
inline insert_iterator<Container> inserter(Container& x, Iterator i) {
    typedef typename Container::iterator iter;
    return insert_iterator<Container>(x, iter(i));
}

#ifndef __STL_LIMITED_DEFAULT_TEMPLATES
template <class BidirectionalIterator, class T, class Reference = T&,
class Distance = ptrdiff_t>
#else
template <class BidirectionalIterator, class T, class Reference,
class Distance>
#endif
class reverse_bidirectional_iterator {
    typedef reverse_bidirectional_iterator<BidirectionalIterator, T, Reference,
    Distance> self;
protected:
    BidirectionalIterator current;
public:
    typedef bidirectional_iterator_tag iterator_category;
    typedef T                          value_type;
    typedef Distance                   difference_type;
    typedef T*                         pointer;
    typedef Reference                  reference;
    
    reverse_bidirectional_iterator() {}
    explicit reverse_bidirectional_iterator(BidirectionalIterator x)
    : current(x) {}
    BidirectionalIterator base() const { return current; }
    Reference operator*() const {
        BidirectionalIterator tmp = current;
        return *--tmp;
    }
    pointer operator->() const { return &(operator*()); }
    self& operator++() {
        --current;
        return *this;
    }
    self operator++(int) {
        self tmp = *this;
        --current;
        return tmp;
    }
    self& operator--() {
        ++current;
        return *this;
    }
    self operator--(int) {
        self tmp = *this;
        ++current;
        return tmp;
    }
};

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class BidirectionalIterator, class T, class Reference,
class Distance>
inline bidirectional_iterator_tag
iterator_category(const reverse_bidirectional_iterator<BidirectionalIterator,
                  T,
                  Reference, Distance>&) {
    return bidirectional_iterator_tag();
}

template <class BidirectionalIterator, class T, class Reference,
class Distance>
inline T*
value_type(const reverse_bidirectional_iterator<BidirectionalIterator, T,
           Reference, Distance>&) {
    return (T*) 0;
}

template <class BidirectionalIterator, class T, class Reference,
class Distance>
inline Distance*
distance_type(const reverse_bidirectional_iterator<BidirectionalIterator, T,
              Reference, Distance>&) {
    return (Distance*) 0;
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class BidirectionalIterator, class T, class Reference,
class Distance>
inline bool operator==(
                       const reverse_bidirectional_iterator<BidirectionalIterator, T, Reference,
                       Distance>& x,
                       const reverse_bidirectional_iterator<BidirectionalIterator, T, Reference,
                       Distance>& y) {
    return x.base() == y.base();
}

#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION



// Local Variables:
// mode:C++
// End:
