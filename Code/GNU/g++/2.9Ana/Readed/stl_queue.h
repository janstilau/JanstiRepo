#ifndef __SGI_STL_INTERNAL_QUEUE_H
#define __SGI_STL_INTERNAL_QUEUE_H

__STL_BEGIN_NAMESPACE

/*
 默认是用的 deque 进行的实现. 但是, 如果用其他的 Sequence 可以实现 stack 里面的操作的话, 也是没有问题的.
 */
#ifndef __STL_LIMITED_DEFAULT_TEMPLATES
template <class T, class Sequence = deque<T> >
#else
template <class T, class Sequence>
#endif
class queue {
    friend bool operator== __STL_NULL_TMPL_ARGS (const queue& x, const queue& y);
    friend bool operator< __STL_NULL_TMPL_ARGS (const queue& x, const queue& y);
public:
    typedef typename Sequence::value_type value_type;
    typedef typename Sequence::size_type size_type;
    typedef typename Sequence::reference reference;
    typedef typename Sequence::const_reference const_reference;
protected:
    Sequence c;
public:
    /*
     Queue 的所有的操作, 都是调用 c 中的操作. 所以, queue 是 c 的适配器.
     C 到底是什么不重要, 只要他能实现下面的这些操作可以了
     */
    bool empty() const { return c.empty(); }
    size_type size() const { return c.size(); }
    reference front() { return c.front(); }
    const_reference front() const { return c.front(); }
    reference back() { return c.back(); }
    const_reference back() const { return c.back(); }
    void push(const value_type& x) { c.push_back(x); }
    void pop() { c.pop_front(); }
};

// C++ 里面, 通过编译器, 来进行类型参数的限制. 代码定义的时候, 标明这是同样的类型, 在实现的时候, 也必须是同样的类型.

/*
 所有的操作, 直接交付给 Sequence c 来进行处理. Sequence c 必须完成相应的操作符重载, 这样
 */
template <class T, class Sequence>
bool operator==(const queue<T, Sequence>& x, const queue<T, Sequence>& y) {
    return x.c == y.c;
}

template <class T, class Sequence>
bool operator<(const queue<T, Sequence>& x, const queue<T, Sequence>& y) {
    return x.c < y.c;
}

#ifndef __STL_LIMITED_DEFAULT_TEMPLATES
template <class T, class Sequence = vector<T>, 
class Compare = less<typename Sequence::value_type> >
#else
template <class T, class Sequence, class Compare>
#endif
/*
 也是作为了一个适配器存在的, 他是使用了 算法进行的堆化, 没有把相关的逻辑, 放到自己的类里面.
 */
class  priority_queue {
public:
    typedef typename Sequence::value_type value_type;
    typedef typename Sequence::size_type size_type;
    typedef typename Sequence::reference reference;
    typedef typename Sequence::const_reference const_reference;
protected:
    Sequence c;
    Compare comp;
public:
    priority_queue() : c() {}
    explicit priority_queue(const Compare& x) :  c(), comp(x) {}
#ifdef __STL_MEMBER_TEMPLATES
    template <class InputIterator>
    priority_queue(InputIterator first, InputIterator last, const Compare& x)
    : c(first, last), comp(x) { make_heap(c.begin(), c.end(), comp); }
    
    template <class InputIterator>
    priority_queue(InputIterator first, InputIterator last)
    : c(first, last) { make_heap(c.begin(), c.end(), comp); }
    
#else /* __STL_MEMBER_TEMPLATES */
    priority_queue(const value_type* first, const value_type* last,
                   const Compare& x) : c(first, last), comp(x) {
        make_heap(c.begin(), c.end(), comp);
    }
    
    priority_queue(const value_type* first, const value_type* last)
    : c(first, last) { make_heap(c.begin(), c.end(), comp); }
    
#endif /* __STL_MEMBER_TEMPLATES */
    
    bool empty() const { return c.empty(); }
    size_type size() const { return c.size(); }
    const_reference top() const { return c.front(); }
    void push(const value_type& x) {
        __STL_TRY {
            c.push_back(x);
            /*
             push_heap 里面, 仅仅是做序列的堆化的调整工作. 数据还是 Sequence 来进行同步.
             先加入数据, 然后进行堆化的处理.
             */
            push_heap(c.begin(), c.end(), comp);
        }
        __STL_UNWIND(c.clear());
    }
    void pop() {
        __STL_TRY {
            /*
             pop_heap 里面, 仅仅是做序列的堆化的调整工作. 数据还是 Sequence 来进行同步.
             先堆里面取出, 后进行数据删除.
             */
            pop_heap(c.begin(), c.end(), comp);
            c.pop_back();
        }
        __STL_UNWIND(c.clear());
    }
};

// no equality is provided

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_QUEUE_H */

// Local Variables:
// mode:C++
// End:
