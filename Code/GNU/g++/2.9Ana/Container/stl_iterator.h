#ifndef __SGI_STL_INTERNAL_ITERATOR_H
#define __SGI_STL_INTERNAL_ITERATOR_H

__STL_BEGIN_NAMESPACE

/*
 iterator_category 并不是实际业务使用的类型. 它最大的作用, 用来表示迭代器的类型, 然后分发算法.
 例如, 对于 distance(begin, end) 这个函数来说, 如果是 random 迭代器, 那么能够瞬间得到答案, 但是 forward 的只能是遍历.
 C++ 是通过 typedef 来为每个迭代器, 标识出自己的 category 的.
 所以, 分发算法里面, 可以通过 iterator_category 获取到类型, 然后生成一个临时遍历, 用作分发的参数来使用.
 
 但是, 对于指针这种原始的迭代器来说, 它是没有各种 typedef 的. 所以, 就增加了一个中间层, 这个中间层, 就是 iterator_traits.
 在 iterator_traits 中, 发现如果是T是指针, 就走特化版本, 表明 iterator_category 是 random 这种类型.
 如果不是指针, 就直接返回 iterator 里面定义的各种 typedef.
 这就是 迭代器萃取的机制.
 */

/*
 从这个实例中, 我们可以看到, 各个函数重载,就是根据参数的类型, 调用了最准确的方法. 这个参数, 不会直接暴露给使用者, 使用者定义好合适的 typedef 之后, 就能使用和这个机制.
 迭代器内部, 提供了自己所属的 category 的信息. 从这个意义上来看, typedef, 可以算作是这个迭代器的元信息.
 typedef, 可以算作是这个迭代器的元信息. 非常重要的认识.
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
    // 通过 iterator_traits 萃取出不同的类型, 产生临时对象. 这个临时对象, 来控制同名函数的调用.
    // 各个函数其实, 仅仅是一个分发函数. 真正的函数实现, 要根据迭代器 iterator_category 的不同,采取不同的算法.
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
    
    
    // 下面这两种, 标准库根本没有用到, 但是还是要写出来.
    typedef T*                 pointer; // 迭代器里面的 pointer
    typedef T&                 reference; // 迭代器里面的 ref.
};

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
template <class Category, class T,
class Distance = ptrdiff_t,
class Pointer = T*,
class Reference = T&>
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
// 这个类很怪, 我们平时写的类, 都是生成对象, 然后调用函数. 或者, 已经比较怪的就是, 直接调用类的方法.
// 以上两种形式, 都是固定调用某个函数名, 只要模板最终生成的类, 有对应的方法就可以了. 可谓是, 模板是面向接口编程.
// 但是, iterator_traits 是, 直接操作的类中的 typedef. 这连函数都不是.
// 从这里也就可以看出, 模板的使用方法有很多. 模板仅仅是一个半成品, 这个半成品, 有的时候可以理解为宏定义.

// 如果, 传递过来的类型是类型的话, 那么就使用 Iterator 中的定义.
template <class Iterator>
struct iterator_traits {
    typedef typename Iterator::iterator_category iterator_category;
    typedef typename Iterator::value_type        value_type;
    typedef typename Iterator::difference_type   difference_type;
    typedef typename Iterator::pointer           pointer;
    typedef typename Iterator::reference         reference;
};

// 如果, 传过来的类型是指针的话, 那么就特化, 显式地表明各种 typedef.
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

// 全局方法, 通过萃取机, 获取 iterator_category 的信息.
template <class Iterator>
inline typename iterator_traits<Iterator>::iterator_category
iterator_category(const Iterator&) {
    typedef typename iterator_traits<Iterator>::iterator_category category;
    return category();
}

// 全局方法, 通过萃取机, 获取距离类型的指针.
template <class Iterator>
inline typename iterator_traits<Iterator>::difference_type*
distance_type(const Iterator&) {
    return static_cast<typename iterator_traits<Iterator>::difference_type*>(0);
}

// 全局方法, 通过萃取机, 获取值类型的指针.
template <class Iterator>
inline typename iterator_traits<Iterator>::value_type*
value_type(const Iterator&) {
    return static_cast<typename iterator_traits<Iterator>::value_type*>(0);
}



// distance 入口函数
template <class InputIterator, class Distance>
inline void distance(InputIterator first, InputIterator last, Distance& n) {
    __distance(first, last, n, iterator_category(first));
}

// distance 特化, 如果是普通的迭代器, 只能是一个个数出来.
template <class InputIterator, class Distance>
inline void __distance(InputIterator first, InputIterator last, Distance& n, 
                       input_iterator_tag) {
    while (first != last) { ++first; ++n; }
}

// distance 特化, 如果是随机迭代器, 可以直接使用相减获取距离.
template <class RandomAccessIterator, class Distance>
inline void __distance(RandomAccessIterator first, RandomAccessIterator last, 
                       Distance& n, random_access_iterator_tag) {
    /*
     RandomAccessIterator, 必须重载 +, - 运算符, 这是它是 RandomAccessIterator 这种类型的责任.
     如果在 C++ 里面, 没有实现, 编译的时候会抛出错误.
     */
    n += last - first;
}


// advance 入口函数
template <class InputIterator, class Distance>
inline void advance(InputIterator& i, Distance n) {
    __advance(i, n, iterator_category(i));
}

// advance 特化, 一般的的迭代器, 一步步的改变 iterator 的值.
template <class InputIterator, class Distance>
inline void __advance(InputIterator& i, Distance n, input_iterator_tag) {
    while (n--) ++i;
}

// advance 特化, 双向的迭代器, 可以--. 如果, 编译的时候, 不是双向的迭代器, -- 操作编译器直接报错.
template <class BidirectionalIterator, class Distance>
inline void __advance(BidirectionalIterator& i, Distance n, 
                      bidirectional_iterator_tag) {
    if (n >= 0)
        while (n--) ++i;
    else
        while (n++) --i;
}

// advance 特化, random 迭代器, 直接跨越 N 的变化.
template <class RandomAccessIterator, class Distance>
inline void __advance(RandomAccessIterator& i, Distance n, 
                      random_access_iterator_tag) {
    i += n;
}


/*
 reverse_iterator 是 Iterator 的适配器.
 首先要保存原始的迭代器, 然后, 在各个适配方法里面, 通过操作原始的迭代器, 来实现自己的逻辑.
 */
template <class Iterator>
class reverse_iterator 
{
protected:
    Iterator current;
public:
    // 必须经过 iterator_traits 来获取各种 typedef 的定义, 因为有可能是指针这种迭代器.
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
    // 必须保存原始的迭代器.
    explicit reverse_iterator(iterator_type x) : current(x) {}
    
    reverse_iterator(const self& x) : current(x.current) {}
    
    iterator_type base() const { return current; } // 任何包装器, 应该给外界的使用者一个权力, 拿到原始值.
        
    // 以 end 为例, end 指向有效范围的下一个位置, 所以, 要拿到最后一个数据, 应该是--.
    // 相对应的, 用 -- 这个规则, begin 指向的就是一个非法的位置了.
    // 这里, current 不应该改变, 因为这里是取值操作, current 是不应该改变的. 所以, 利用一个拷贝来做这个事情.
    reference operator*() const {
        Iterator tmp = current;
        return *--tmp;
    }
    pointer operator->() const { return &(operator*()); }
    
    // 这里需要多思考一下. 如果 current 就是一个 reverse_iterator 怎么办.
    // 代码里面, 直接这样写是没有问题的. 但是, 如果保存的 current 本身也是一个适配器, 那么最终就是函数套函数, 数个函数一起触发.
    // 抽象的意义就在于, 不用考虑这么深. 装饰者模式, 会实现原来的接口, 让使用者在只考虑一层调用.
    // 因为, 迭代器的++, -- 多次是没有什么影响的. 多个迭代器修饰嵌套的话, 只是让迭代器里面的值不断地改变而已, 只要最后进行取值的时候, 取到正确的位置就可以了.
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

 // reverse 仅仅是适配器, 真正的数据来源还是 base. 类型的比较, 就是比较的数据, 所以这里直接是 base 的比较.
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





// 下面的暂时先不考虑.

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

// 插入迭代器.
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
    // 这里, 这三个操作符, 不做任何的改变.
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

// 从头部插入的 iterator 适配器.
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
