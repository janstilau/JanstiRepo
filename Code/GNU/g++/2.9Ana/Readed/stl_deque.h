#ifndef __SGI_STL_INTERNAL_DEQUE_H
#define __SGI_STL_INTERNAL_DEQUE_H

__STL_BEGIN_NAMESPACE
/*
 __STL_BEGIN_NAMESPACE
 __STL_END_NAMESPACE
 将常用的, 不能函数化的代码, 用宏代替, 其实是一种比较好的方法.
 */

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma set woff 1174
#endif

/*
 __deque_iterator 将 deque 的复杂底层数据进行了包装.
 */

#ifndef __STL_NON_TYPE_TMPL_PARAM_BUG
template <class T, class Ref, class Ptr, size_t BufSiz>
struct __deque_iterator {
    typedef __deque_iterator<T, T&, T*, BufSiz>             iterator;
    typedef __deque_iterator<T, const T&, const T*, BufSiz> const_iterator;
    static size_t buffer_size() {return __deque_buf_size(BufSiz, sizeof(T)); }
#else /* __STL_NON_TYPE_TMPL_PARAM_BUG */
    template <class T, class Ref, class Ptr>
    struct __deque_iterator {
        typedef __deque_iterator<T, T&, T*>             iterator;
        typedef __deque_iterator<T, const T&, const T*> const_iterator;
        static size_t buffer_size() {return __deque_buf_size(0, sizeof(T)); }
#endif
        // 为了实现, random 的效果, deque 的 iterator 的逻辑复杂度超过了其他的迭代器.
        typedef random_access_iterator_tag iterator_category;
        typedef T value_type;
        typedef Ptr pointer;
        typedef Ref reference;
        typedef size_t size_type;
        typedef ptrdiff_t difference_type;
        typedef T** map_pointer;
        
        typedef __deque_iterator self;
        
        T* cur; // 当前缓存区的位置
        T* first; // 当前缓存区的头
        T* last; // 当前缓存区的最后一个元素下一个元素
        map_pointer node; // 控制中心所在的位置.
        
        /*
         buffer_size 控制缓存区的大小. 从函数中进行获取, 代表着这是一个定制.
         */
        __deque_iterator(T* x, map_pointer y)
        : cur(x), first(*y), last(*y + buffer_size()), node(y) {}
        __deque_iterator() : cur(0), first(0), last(0), node(0) {}
        __deque_iterator(const iterator& x)
        : cur(x.cur), first(x.first), last(x.last), node(x.node) {}
        
        /*
         current 指向了真正的数据.
         */
        reference operator*() const { return *cur; }
        pointer operator->() const { return &(operator*()); }
        
        difference_type operator-(const self& x) const {
            /*
             首先计算, 缓存区之间的差距, buffsize 为单位.
             然后是各自和边界的差值.
             */
            return
            buffer_size() * (node - x.node - 1)
            + (cur - first)
            + (x.last - x.cur);
        }
        
        /*
         需要注意的是, 迭代器前进后退的时候, 是没有安全监测的, 那应该是调用迭代器前后操作的代码的责任.
         */
        self& operator++() {
            ++cur;
            /*
             如果到达了边界, 切换 node 的指向.
             */
            if (cur == last) {
                set_node(node + 1);
                cur = first;
            }
            return *this;
        }
        
        self operator++(int)  {
            self tmp = *this;
            /*
             后++, 直接调用前 ++ 的实现.
             */
            ++*this;
            return tmp;
        }
        
        self& operator--() {
            /*
             如果到达了边界, 切换 node 的指向.
             */
            if (cur == first) {
                set_node(node - 1);
                cur = last;
            }
            --cur;
            return *this;
        }
        self operator--(int) {
            self tmp = *this;
            --*this;
            return tmp;
        }
        
        self& operator+=(difference_type n) {
            difference_type offset = n + (cur - first);
            if (offset >= 0 && offset < difference_type(buffer_size())) {
                // 如果, + n 后还在一个缓存区里面.
                cur += n;
            } else {
                // 不在一个缓存区里面, 先进行切换.
                difference_type node_offset =
                offset > 0 ? offset / difference_type(buffer_size())
                : -difference_type((-offset - 1) / buffer_size()) - 1;
                set_node(node + node_offset);
                cur = first + (offset - node_offset * difference_type(buffer_size()));
            }
            return *this;
        }
        
        self operator+(difference_type n) const {
            self tmp = *this;
            return tmp += n;
        }
        
        self& operator-=(difference_type n) { return *this += -n; }
        
        self operator-(difference_type n) const {
            self tmp = *this;
            return tmp -= n;
        }
        
        /*
         *(*this + n) []的含义, 从c 指针上说, 就是这样的, 既然 *, + 等操作符的含义已经正确, 直接用原始指针的操作就可以了.
         */
        reference operator[](difference_type n) const { return *(*this + n); }
        
        bool operator==(const self& x) const { return cur == x.cur; }
        bool operator!=(const self& x) const { return !(*this == x); }
        bool operator<(const self& x) const {
            return (node == x.node) ? (cur < x.cur) : (node < x.node);
        }
        
        /*
         迭代器切换 node.
         */
        void set_node(map_pointer new_node) {
            node = new_node;
            first = *new_node;
            last = first + difference_type(buffer_size());
        }
    };
}
#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

#ifndef __STL_NON_TYPE_TMPL_PARAM_BUG

template <class T, class Ref, class Ptr, size_t BufSiz>
inline random_access_iterator_tag
iterator_category(const __deque_iterator<T, Ref, Ptr, BufSiz>&) {
    return random_access_iterator_tag();
}

template <class T, class Ref, class Ptr, size_t BufSiz>
inline T* value_type(const __deque_iterator<T, Ref, Ptr, BufSiz>&) {
    return 0;
}

template <class T, class Ref, class Ptr, size_t BufSiz>
inline ptrdiff_t* distance_type(const __deque_iterator<T, Ref, Ptr, BufSiz>&) {
    return 0;
}

#else /* __STL_NON_TYPE_TMPL_PARAM_BUG */

template <class T, class Ref, class Ptr>
inline random_access_iterator_tag
iterator_category(const __deque_iterator<T, Ref, Ptr>&) {
    return random_access_iterator_tag();
}

template <class T, class Ref, class Ptr>
inline T* value_type(const __deque_iterator<T, Ref, Ptr>&) { return 0; }

template <class T, class Ref, class Ptr>
inline ptrdiff_t* distance_type(const __deque_iterator<T, Ref, Ptr>&) {
    return 0;
}

#endif /* __STL_NON_TYPE_TMPL_PARAM_BUG */

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class T, class Alloc = alloc, size_t BufSiz = 0>
class deque {
public:                         // Basic types
    typedef T value_type;
    typedef value_type* pointer;
    typedef const value_type* const_pointer;
    typedef value_type& reference;
    typedef const value_type& const_reference;
    typedef size_t size_type;
    typedef ptrdiff_t difference_type;
    
public:                         // Iterators
#ifndef __STL_NON_TYPE_TMPL_PARAM_BUG
    typedef __deque_iterator<T, T&, T*, BufSiz>              iterator;
    typedef __deque_iterator<T, const T&, const T&, BufSiz>  const_iterator;
#else /* __STL_NON_TYPE_TMPL_PARAM_BUG */
    typedef __deque_iterator<T, T&, T*>                      iterator;
    typedef __deque_iterator<T, const T&, const T*>          const_iterator;
#endif /* __STL_NON_TYPE_TMPL_PARAM_BUG */
    
#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION
    typedef reverse_iterator<const_iterator> const_reverse_iterator;
    typedef reverse_iterator<iterator> reverse_iterator;
#else /* __STL_CLASS_PARTIAL_SPECIALIZATION */
    typedef reverse_iterator<const_iterator, value_type, const_reference,
    difference_type>
    const_reverse_iterator;
    typedef reverse_iterator<iterator, value_type, reference, difference_type>
    reverse_iterator;
#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */
    
protected:                      // Internal typedefs
    typedef pointer* map_pointer;
    typedef simple_alloc<value_type, Alloc> data_allocator;
    typedef simple_alloc<pointer, Alloc> map_allocator;
    
    /*
     缓存区的大小, 可以认为是一个定值.
     */
    static size_type buffer_size() {
        return __deque_buf_size(BufSiz, sizeof(value_type));
    }
    static size_type initial_map_size() { return 8; }
    
protected:                      // Data members
    /*
     每个容器的 start, finish 都是一个存储起来的值. 保证 O(1) 时间复杂度可以找到.
     */
    iterator start;
    iterator finish;
    
    map_pointer map; // 的起始位置.
    size_type map_size; // 控制中心的大小.
    
public:                         // Basic accessors
    iterator begin() { return start; }
    iterator end() { return finish; }
    const_iterator begin() const { return start; }
    const_iterator end() const { return finish; }
    
    /*
     reverse_iterator 是适配器, 仅仅是做控制逻辑的变化, 真正的数据访问, 还是依靠原始的 iterator 的功能.
     */
    reverse_iterator rbegin() { return reverse_iterator(finish); }
    reverse_iterator rend() { return reverse_iterator(start); }
    const_reverse_iterator rbegin() const {
        return const_reverse_iterator(finish);
    }
    const_reverse_iterator rend() const {
        return const_reverse_iterator(start);
    }
    
    // 直接使用了 start 迭代器的[]擦偶走符重载.
    reference operator[](size_type n) { return start[difference_type(n)]; }
    const_reference operator[](size_type n) const {
        return start[difference_type(n)];
    }
    
    reference front() { return *start; }
    // finish 作为 end 进行了使用. 下面的写法, 是常规的写法.
    reference back() {
        iterator tmp = finish;
        --tmp;
        return *tmp;
    }
    const_reference front() const { return *start; }
    const_reference back() const {
        const_iterator tmp = finish;
        --tmp;
        return *tmp;
    }
    
    // - 号会自动进行 node 之间的距离的计算.
    size_type size() const { return finish - start; }
    size_type max_size() const { return size_type(-1); }
    bool empty() const { return finish == start; }
    
public:                         // Constructor, destructor.
    deque()
    : start(), finish(), map(0), map_size(0)
    {
        create_map_and_nodes(0);
    }
    
    deque(const deque& x)
    : start(), finish(), map(0), map_size(0)
    {
        create_map_and_nodes(x.size());
        __STL_TRY {
            uninitialized_copy(x.begin(), x.end(), start);
        }
        __STL_UNWIND(destroy_map_and_nodes());
    }
    
    deque(size_type n, const value_type& value)
    : start(), finish(), map(0), map_size(0)
    {
        fill_initialize(n, value);
    }
    
    deque(int n, const value_type& value)
    : start(), finish(), map(0), map_size(0)
    {
        fill_initialize(n, value);
    }
    
    deque(long n, const value_type& value)
    : start(), finish(), map(0), map_size(0)
    {
        fill_initialize(n, value);
    }
    
    explicit deque(size_type n)
    : start(), finish(), map(0), map_size(0)
    {
        fill_initialize(n, value_type());
    }
    
#ifdef __STL_MEMBER_TEMPLATES
    
    template <class InputIterator>
    deque(InputIterator first, InputIterator last)
    : start(), finish(), map(0), map_size(0)
    {
        range_initialize(first, last, iterator_category(first));
    }
    
#else /* __STL_MEMBER_TEMPLATES */
    
    deque(const value_type* first, const value_type* last)
    : start(), finish(), map(0), map_size(0)
    {
        create_map_and_nodes(last - first);
        __STL_TRY {
            uninitialized_copy(first, last, start);
        }
        __STL_UNWIND(destroy_map_and_nodes());
    }
    
    deque(const_iterator first, const_iterator last)
    : start(), finish(), map(0), map_size(0)
    {
        create_map_and_nodes(last - first);
        __STL_TRY {
            uninitialized_copy(first, last, start);
        }
        __STL_UNWIND(destroy_map_and_nodes());
    }
    
#endif /* __STL_MEMBER_TEMPLATES */
    
    ~deque() {
        destroy(start, finish);
        destroy_map_and_nodes();
    }
    
    deque& operator= (const deque& x) {
        const size_type len = size();
        if (&x != this) {
            if (len >= x.size())
                erase(copy(x.begin(), x.end(), start), finish);
            else {
                const_iterator mid = x.begin() + difference_type(len);
                copy(x.begin(), mid, start);
                insert(finish, mid, x.end());
            }
        }
        return *this;
    }
    
    void swap(deque& x) {
        __STD::swap(start, x.start);
        __STD::swap(finish, x.finish);
        __STD::swap(map, x.map);
        __STD::swap(map_size, x.map_size);
    }
    
public:                         // push_* and pop_*
    
    void push_back(const value_type& t) {
        /*
         如果, 还没有到达缓存区的边缘, 进在缓存区里面存储值, 然后更新 finish 的指针
         */
        if (finish.cur != finish.last - 1) {
            construct(finish.cur, t);
            ++finish.cur;
        } else {
            push_back_aux(t);
        }
    }
    
    void push_front(const value_type& t) {
        if (start.cur != start.first) {
            construct(start.cur - 1, t);
            --start.cur;
        }
        else
            push_front_aux(t);
    }
    
    void pop_back() {
        if (finish.cur != finish.first) {
            --finish.cur;
            destroy(finish.cur);
        }
        else
            pop_back_aux();
    }
    
    void pop_front() {
        if (start.cur != start.last - 1) {
            destroy(start.cur);
            ++start.cur;
        }
        else
            pop_front_aux();
    }
    
    /*
     前面的 push, pop 都可以利用 start 和 finish 进行操作. insert 涉及到搬移操作, 更加的复杂.
     */
public:                         // Insert
    
    iterator insert(iterator position, const value_type& x) {
        /*
         前插, 后插比较简单, 直接利用之前的函数定义就可以了.
         */
        if (position.cur == start.cur) {
            push_front(x);
            return start;
        } else if (position.cur == finish.cur) {
            push_back(x);
            iterator tmp = finish;
            --tmp;
            return tmp;
        } else {
            return insert_aux(position, x);
        }
    }
    
    iterator insert(iterator position) { return insert(position, value_type()); }
    
    void insert(iterator pos, size_type n, const value_type& x);
    
    void insert(iterator pos, int n, const value_type& x) {
        insert(pos, (size_type) n, x);
    }
    void insert(iterator pos, long n, const value_type& x) {
        insert(pos, (size_type) n, x);
    }
    
#ifdef __STL_MEMBER_TEMPLATES  
    
    template <class InputIterator>
    void insert(iterator pos, InputIterator first, InputIterator last) {
        insert(pos, first, last, iterator_category(first));
    }
    
#else /* __STL_MEMBER_TEMPLATES */
    
    void insert(iterator pos, const value_type* first, const value_type* last);
    void insert(iterator pos, const_iterator first, const_iterator last);
    
#endif /* __STL_MEMBER_TEMPLATES */
    
    void resize(size_type new_size, const value_type& x) {
        const size_type len = size();
        if (new_size < len)
            erase(start + new_size, finish);
        else
            insert(finish, new_size - len, x);
    }
    
    void resize(size_type new_size) { resize(new_size, value_type()); }
    
public:                         // Erase
    iterator erase(iterator pos) {
        iterator next = pos;
        ++next;
        difference_type index = pos - start;
        if (index < (size() >> 1)) {
            copy_backward(start, pos, next);
            pop_front();
        } else {
            copy(next, finish, pos);
            pop_back();
        }
        return start + index;
    }
    
    iterator erase(iterator first, iterator last);
    void clear();
    
protected:                        // Internal construction/destruction
    
    void create_map_and_nodes(size_type num_elements);
    void destroy_map_and_nodes();
    void fill_initialize(size_type n, const value_type& value);
    
#ifdef __STL_MEMBER_TEMPLATES  
    
    template <class InputIterator>
    void range_initialize(InputIterator first, InputIterator last,
                          input_iterator_tag);
    
    template <class ForwardIterator>
    void range_initialize(ForwardIterator first, ForwardIterator last,
                          forward_iterator_tag);
    
#endif /* __STL_MEMBER_TEMPLATES */
    
protected:                        // Internal push_* and pop_*
    
    void push_back_aux(const value_type& t);
    void push_front_aux(const value_type& t);
    void pop_back_aux();
    void pop_front_aux();
    
protected:                        // Internal insert functions
    
#ifdef __STL_MEMBER_TEMPLATES  
    
    template <class InputIterator>
    void insert(iterator pos, InputIterator first, InputIterator last,
                input_iterator_tag);
    
    template <class ForwardIterator>
    void insert(iterator pos, ForwardIterator first, ForwardIterator last,
                forward_iterator_tag);
    
#endif /* __STL_MEMBER_TEMPLATES */
    
    iterator insert_aux(iterator pos, const value_type& x);
    void insert_aux(iterator pos, size_type n, const value_type& x);
    
#ifdef __STL_MEMBER_TEMPLATES  
    
    template <class ForwardIterator>
    void insert_aux(iterator pos, ForwardIterator first, ForwardIterator last,
                    size_type n);
    
#else /* __STL_MEMBER_TEMPLATES */
    
    void insert_aux(iterator pos,
                    const value_type* first, const value_type* last,
                    size_type n);
    
    void insert_aux(iterator pos, const_iterator first, const_iterator last,
                    size_type n);
    
#endif /* __STL_MEMBER_TEMPLATES */
    
    iterator reserve_elements_at_front(size_type n) {
        size_type vacancies = start.cur - start.first;
        if (n > vacancies)
            new_elements_at_front(n - vacancies);
        return start - difference_type(n);
    }
    
    iterator reserve_elements_at_back(size_type n) {
        size_type vacancies = (finish.last - finish.cur) - 1;
        if (n > vacancies)
            new_elements_at_back(n - vacancies);
        return finish + difference_type(n);
    }
    
    void new_elements_at_front(size_type new_elements);
    void new_elements_at_back(size_type new_elements);
    
    void destroy_nodes_at_front(iterator before_start);
    void destroy_nodes_at_back(iterator after_finish);
    
protected:                      // Allocation of map and nodes
    
    // Makes sure the map has space for new nodes.  Does not actually
    //  add the nodes.  Can invalidate map pointers.  (And consequently,
    //  deque iterators.)
    
    /*
     如果, 没有控制中心没有新的缓存区节点了, 那么就要进行新的分配操作.
     */
    void reserve_map_at_back (size_type nodes_to_add = 1) {
        if (nodes_to_add + 1 > map_size - (finish.node - map))
            reallocate_map(nodes_to_add, false);
    }
    
    void reserve_map_at_front (size_type nodes_to_add = 1) {
        if (nodes_to_add > start.node - map)
            reallocate_map(nodes_to_add, true);
    }
    
    void reallocate_map(size_type nodes_to_add, bool add_at_front);
    
    /*
     生产一个缓存区来.
     */
    pointer allocate_node() { return data_allocator::allocate(buffer_size()); }
    void deallocate_node(pointer n) {
        data_allocator::deallocate(n, buffer_size());
    }
    
#ifdef __STL_NON_TYPE_TMPL_PARAM_BUG
public:
    bool operator==(const deque<T, Alloc, 0>& x) const {
        return size() == x.size() && equal(begin(), end(), x.begin());
    }
    bool operator!=(const deque<T, Alloc, 0>& x) const {
        return size() != x.size() || !equal(begin(), end(), x.begin());
    }
    bool operator<(const deque<T, Alloc, 0>& x) const {
        return lexicographical_compare(begin(), end(), x.begin(), x.end());
    }
#endif /* __STL_NON_TYPE_TMPL_PARAM_BUG */
};

// Non-inline member functions

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::insert(iterator pos,
                                      size_type n, const value_type& x) {
    if (pos.cur == start.cur) {
        iterator new_start = reserve_elements_at_front(n);
        uninitialized_fill(new_start, start, x);
        start = new_start;
    } else if (pos.cur == finish.cur) {
        iterator new_finish = reserve_elements_at_back(n);
        uninitialized_fill(finish, new_finish, x);
        finish = new_finish;
    } else {
        insert_aux(pos, n, x);
    }
}

#ifndef __STL_MEMBER_TEMPLATES  

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::insert(iterator pos,
                                      const value_type* first,
                                      const value_type* last) {
    size_type n = last - first;
    if (pos.cur == start.cur) {
        iterator new_start = reserve_elements_at_front(n);
        __STL_TRY {
            uninitialized_copy(first, last, new_start);
            start = new_start;
        }
        __STL_UNWIND(destroy_nodes_at_front(new_start));
    }
    else if (pos.cur == finish.cur) {
        iterator new_finish = reserve_elements_at_back(n);
        __STL_TRY {
            uninitialized_copy(first, last, finish);
            finish = new_finish;
        }
        __STL_UNWIND(destroy_nodes_at_back(new_finish));
    }
    else
        insert_aux(pos, first, last, n);
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::insert(iterator pos,
                                      const_iterator first,
                                      const_iterator last)
{
    size_type n = last - first;
    if (pos.cur == start.cur) {
        iterator new_start = reserve_elements_at_front(n);
        __STL_TRY {
            uninitialized_copy(first, last, new_start);
            start = new_start;
        }
        __STL_UNWIND(destroy_nodes_at_front(new_start));
    }
    else if (pos.cur == finish.cur) {
        iterator new_finish = reserve_elements_at_back(n);
        __STL_TRY {
            uninitialized_copy(first, last, finish);
            finish = new_finish;
        }
        __STL_UNWIND(destroy_nodes_at_back(new_finish));
    }
    else
        insert_aux(pos, first, last, n);
}

#endif /* __STL_MEMBER_TEMPLATES */

template <class T, class Alloc, size_t BufSize>
deque<T, Alloc, BufSize>::iterator
deque<T, Alloc, BufSize>::erase(iterator first, iterator last) {
    if (first == start && last == finish) {
        clear();
        return finish;
    }
    else {
        difference_type n = last - first;
        difference_type elems_before = first - start;
        if (elems_before < (size() - n) / 2) {
            copy_backward(start, first, last);
            iterator new_start = start + n;
            destroy(start, new_start);
            for (map_pointer cur = start.node; cur < new_start.node; ++cur)
                data_allocator::deallocate(*cur, buffer_size());
            start = new_start;
        }
        else {
            copy(last, finish, first);
            iterator new_finish = finish - n;
            destroy(new_finish, finish);
            for (map_pointer cur = new_finish.node + 1; cur <= finish.node; ++cur)
                data_allocator::deallocate(*cur, buffer_size());
            finish = new_finish;
        }
        return start + elems_before;
    }
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::clear() {
    for (map_pointer node = start.node + 1; node < finish.node; ++node) {
        destroy(*node, *node + buffer_size());
        data_allocator::deallocate(*node, buffer_size());
    }
    
    if (start.node != finish.node) {
        destroy(start.cur, start.last);
        destroy(finish.first, finish.cur);
        data_allocator::deallocate(finish.first, buffer_size());
    }
    else
        destroy(start.cur, finish.cur);
    
    finish = start;
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::create_map_and_nodes(size_type num_elements) {
    size_type num_nodes = num_elements / buffer_size() + 1;
    
    map_size = max(initial_map_size(), num_nodes + 2);
    map = map_allocator::allocate(map_size);
    
    /*
     在这里, 把起始操作的 node 的位置, 放到了控制中心的中间部位.
     */
    map_pointer nstart = map + (map_size - num_nodes) / 2;
    map_pointer nfinish = nstart + num_nodes - 1;
    
    map_pointer cur;
    __STL_TRY {
        for (cur = nstart; cur <= nfinish; ++cur)
            *cur = allocate_node();
    }
    
    start.set_node(nstart);
    finish.set_node(nfinish);
    start.cur = start.first;
    finish.cur = finish.first + num_elements % buffer_size();
}

// This is only used as a cleanup function in catch clauses.
template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::destroy_map_and_nodes() {
    for (map_pointer cur = start.node; cur <= finish.node; ++cur)
        deallocate_node(*cur);
    map_allocator::deallocate(map, map_size);
}


template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::fill_initialize(size_type n,
                                               const value_type& value) {
    create_map_and_nodes(n);
    map_pointer cur;
    __STL_TRY {
        for (cur = start.node; cur < finish.node; ++cur)
            uninitialized_fill(*cur, *cur + buffer_size(), value);
        uninitialized_fill(finish.first, finish.cur, value);
    }
#       ifdef __STL_USE_EXCEPTIONS
    catch(...) {
        for (map_pointer n = start.node; n < cur; ++n)
            destroy(*n, *n + buffer_size());
        destroy_map_and_nodes();
        throw;
    }
#       endif /* __STL_USE_EXCEPTIONS */
}

#ifdef __STL_MEMBER_TEMPLATES  

template <class T, class Alloc, size_t BufSize>
template <class InputIterator>
void deque<T, Alloc, BufSize>::range_initialize(InputIterator first,
                                                InputIterator last,
                                                input_iterator_tag) {
    create_map_and_nodes(0);
    for ( ; first != last; ++first)
        push_back(*first);
}

template <class T, class Alloc, size_t BufSize>
template <class ForwardIterator>
void deque<T, Alloc, BufSize>::range_initialize(ForwardIterator first,
                                                ForwardIterator last,
                                                forward_iterator_tag) {
    size_type n = 0;
    distance(first, last, n);
    create_map_and_nodes(n);
    __STL_TRY {
        uninitialized_copy(first, last, start);
    }
    __STL_UNWIND(destroy_map_and_nodes());
}

#endif /* __STL_MEMBER_TEMPLATES */

// Called only if finish.cur == finish.last - 1.
template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::push_back_aux(const value_type& t) {
    value_type t_copy = t;
    reserve_map_at_back();
    *(finish.node + 1) = allocate_node();
    __STL_TRY {
        construct(finish.cur, t_copy);
        finish.set_node(finish.node + 1);
        finish.cur = finish.first;
    }
    __STL_UNWIND(deallocate_node(*(finish.node + 1)));
}

// Called only if start.cur == start.first.
template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::push_front_aux(const value_type& t) {
    value_type t_copy = t;
    reserve_map_at_front();
    *(start.node - 1) = allocate_node();
    __STL_TRY {
        start.set_node(start.node - 1);
        start.cur = start.last - 1;
        construct(start.cur, t_copy);
    }
#     ifdef __STL_USE_EXCEPTIONS
    catch(...) {
        start.set_node(start.node + 1);
        start.cur = start.first;
        deallocate_node(*(start.node - 1));
        throw;
    }
#     endif /* __STL_USE_EXCEPTIONS */
}

// Called only if finish.cur == finish.first.
template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>:: pop_back_aux() {
    deallocate_node(finish.first);
    finish.set_node(finish.node - 1);
    finish.cur = finish.last - 1;
    destroy(finish.cur);
}

// Called only if start.cur == start.last - 1.  Note that if the deque
//  has at least one element (a necessary precondition for this member
//  function), and if start.cur == start.last, then the deque must have
//  at least two nodes.
template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::pop_front_aux() {
    destroy(start.cur);
    deallocate_node(start.first);
    start.set_node(start.node + 1);
    start.cur = start.first;
}

#ifdef __STL_MEMBER_TEMPLATES  

template <class T, class Alloc, size_t BufSize>
template <class InputIterator>
void deque<T, Alloc, BufSize>::insert(iterator pos,
                                      InputIterator first, InputIterator last,
                                      input_iterator_tag) {
    copy(first, last, inserter(*this, pos));
}

template <class T, class Alloc, size_t BufSize>
template <class ForwardIterator>
void deque<T, Alloc, BufSize>::insert(iterator pos,
                                      ForwardIterator first,
                                      ForwardIterator last,
                                      forward_iterator_tag) {
    size_type n = 0;
    distance(first, last, n);
    if (pos.cur == start.cur) {
        iterator new_start = reserve_elements_at_front(n);
        __STL_TRY {
            uninitialized_copy(first, last, new_start);
            start = new_start;
        }
        __STL_UNWIND(destroy_nodes_at_front(new_start));
    }
    else if (pos.cur == finish.cur) {
        iterator new_finish = reserve_elements_at_back(n);
        __STL_TRY {
            uninitialized_copy(first, last, finish);
            finish = new_finish;
        }
        __STL_UNWIND(destroy_nodes_at_back(new_finish));
    }
    else
        insert_aux(pos, first, last, n);
}

#endif /* __STL_MEMBER_TEMPLATES */

template <class T, class Alloc, size_t BufSize>
typename deque<T, Alloc, BufSize>::iterator
deque<T, Alloc, BufSize>::insert_aux(iterator pos, const value_type& x) {
    difference_type index = pos - start;
    value_type x_copy = x;
    /*
     根据 pos 离得哪边比较近, 决定向前搬移, 还是向后搬移. 然后 pos 进行赋值操作.
     */
    if (index < size() / 2) {
        push_front(front());
        iterator front1 = start;
        ++front1;
        iterator front2 = front1;
        ++front2;
        pos = start + index;
        iterator pos1 = pos;
        ++pos1;
        copy(front2, pos1, front1);
    }
    else {
        push_back(back());
        iterator back1 = finish;
        --back1;
        iterator back2 = back1;
        --back2;
        pos = start + index;
        copy_backward(pos, back2, back1);
    }
    *pos = x_copy;
    return pos;
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::insert_aux(iterator pos,
                                          size_type n, const value_type& x) {
    const difference_type elems_before = pos - start;
    size_type length = size();
    value_type x_copy = x;
    if (elems_before < length / 2) {
        iterator new_start = reserve_elements_at_front(n);
        iterator old_start = start;
        pos = start + elems_before;
        __STL_TRY {
            if (elems_before >= difference_type(n)) {
                iterator start_n = start + difference_type(n);
                uninitialized_copy(start, start_n, new_start);
                start = new_start;
                copy(start_n, pos, old_start);
                fill(pos - difference_type(n), pos, x_copy);
            }
            else {
                __uninitialized_copy_fill(start, pos, new_start, start, x_copy);
                start = new_start;
                fill(old_start, pos, x_copy);
            }
        }
        __STL_UNWIND(destroy_nodes_at_front(new_start));
    }
    else {
        iterator new_finish = reserve_elements_at_back(n);
        iterator old_finish = finish;
        const difference_type elems_after = difference_type(length) - elems_before;
        pos = finish - elems_after;
        __STL_TRY {
            if (elems_after > difference_type(n)) {
                iterator finish_n = finish - difference_type(n);
                uninitialized_copy(finish_n, finish, finish);
                finish = new_finish;
                copy_backward(pos, finish_n, old_finish);
                fill(pos, pos + difference_type(n), x_copy);
            }
            else {
                __uninitialized_fill_copy(finish, pos + difference_type(n),
                                          x_copy,
                                          pos, finish);
                finish = new_finish;
                fill(pos, old_finish, x_copy);
            }
        }
        __STL_UNWIND(destroy_nodes_at_back(new_finish));
    }
}

#ifdef __STL_MEMBER_TEMPLATES  

template <class T, class Alloc, size_t BufSize>
template <class ForwardIterator>
void deque<T, Alloc, BufSize>::insert_aux(iterator pos,
                                          ForwardIterator first,
                                          ForwardIterator last,
                                          size_type n)
{
    const difference_type elems_before = pos - start;
    size_type length = size();
    if (elems_before < length / 2) {
        iterator new_start = reserve_elements_at_front(n);
        iterator old_start = start;
        pos = start + elems_before;
        __STL_TRY {
            if (elems_before >= difference_type(n)) {
                iterator start_n = start + difference_type(n);
                uninitialized_copy(start, start_n, new_start);
                start = new_start;
                copy(start_n, pos, old_start);
                copy(first, last, pos - difference_type(n));
            }
            else {
                ForwardIterator mid = first;
                advance(mid, difference_type(n) - elems_before);
                __uninitialized_copy_copy(start, pos, first, mid, new_start);
                start = new_start;
                copy(mid, last, old_start);
            }
        }
        __STL_UNWIND(destroy_nodes_at_front(new_start));
    }
    else {
        iterator new_finish = reserve_elements_at_back(n);
        iterator old_finish = finish;
        const difference_type elems_after = difference_type(length) - elems_before;
        pos = finish - elems_after;
        __STL_TRY {
            if (elems_after > difference_type(n)) {
                iterator finish_n = finish - difference_type(n);
                uninitialized_copy(finish_n, finish, finish);
                finish = new_finish;
                copy_backward(pos, finish_n, old_finish);
                copy(first, last, pos);
            }
            else {
                ForwardIterator mid = first;
                advance(mid, elems_after);
                __uninitialized_copy_copy(mid, last, pos, finish, finish);
                finish = new_finish;
                copy(first, mid, pos);
            }
        }
        __STL_UNWIND(destroy_nodes_at_back(new_finish));
    }
}

#else /* __STL_MEMBER_TEMPLATES */

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::insert_aux(iterator pos,
                                          const value_type* first,
                                          const value_type* last,
                                          size_type n)
{
    const difference_type elems_before = pos - start;
    size_type length = size();
    if (elems_before < length / 2) {
        iterator new_start = reserve_elements_at_front(n);
        iterator old_start = start;
        pos = start + elems_before;
        __STL_TRY {
            if (elems_before >= difference_type(n)) {
                iterator start_n = start + difference_type(n);
                uninitialized_copy(start, start_n, new_start);
                start = new_start;
                copy(start_n, pos, old_start);
                copy(first, last, pos - difference_type(n));
            }
            else {
                const value_type* mid = first + (difference_type(n) - elems_before);
                __uninitialized_copy_copy(start, pos, first, mid, new_start);
                start = new_start;
                copy(mid, last, old_start);
            }
        }
        __STL_UNWIND(destroy_nodes_at_front(new_start));
    }
    else {
        iterator new_finish = reserve_elements_at_back(n);
        iterator old_finish = finish;
        const difference_type elems_after = difference_type(length) - elems_before;
        pos = finish - elems_after;
        __STL_TRY {
            if (elems_after > difference_type(n)) {
                iterator finish_n = finish - difference_type(n);
                uninitialized_copy(finish_n, finish, finish);
                finish = new_finish;
                copy_backward(pos, finish_n, old_finish);
                copy(first, last, pos);
            }
            else {
                const value_type* mid = first + elems_after;
                __uninitialized_copy_copy(mid, last, pos, finish, finish);
                finish = new_finish;
                copy(first, mid, pos);
            }
        }
        __STL_UNWIND(destroy_nodes_at_back(new_finish));
    }
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::insert_aux(iterator pos,
                                          const_iterator first,
                                          const_iterator last,
                                          size_type n)
{
    const difference_type elems_before = pos - start;
    size_type length = size();
    if (elems_before < length / 2) {
        iterator new_start = reserve_elements_at_front(n);
        iterator old_start = start;
        pos = start + elems_before;
        __STL_TRY {
            if (elems_before >= n) {
                iterator start_n = start + n;
                uninitialized_copy(start, start_n, new_start);
                start = new_start;
                copy(start_n, pos, old_start);
                copy(first, last, pos - difference_type(n));
            }
            else {
                const_iterator mid = first + (n - elems_before);
                __uninitialized_copy_copy(start, pos, first, mid, new_start);
                start = new_start;
                copy(mid, last, old_start);
            }
        }
        __STL_UNWIND(destroy_nodes_at_front(new_start));
    }
    else {
        iterator new_finish = reserve_elements_at_back(n);
        iterator old_finish = finish;
        const difference_type elems_after = length - elems_before;
        pos = finish - elems_after;
        __STL_TRY {
            if (elems_after > n) {
                iterator finish_n = finish - difference_type(n);
                uninitialized_copy(finish_n, finish, finish);
                finish = new_finish;
                copy_backward(pos, finish_n, old_finish);
                copy(first, last, pos);
            }
            else {
                const_iterator mid = first + elems_after;
                __uninitialized_copy_copy(mid, last, pos, finish, finish);
                finish = new_finish;
                copy(first, mid, pos);
            }
        }
        __STL_UNWIND(destroy_nodes_at_back(new_finish));
    }
}

#endif /* __STL_MEMBER_TEMPLATES */

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::new_elements_at_front(size_type new_elements) {
    size_type new_nodes = (new_elements + buffer_size() - 1) / buffer_size();
    reserve_map_at_front(new_nodes);
    size_type i;
    __STL_TRY {
        for (i = 1; i <= new_nodes; ++i)
            *(start.node - i) = allocate_node();
    }
#       ifdef __STL_USE_EXCEPTIONS
    catch(...) {
        for (size_type j = 1; j < i; ++j)
            deallocate_node(*(start.node - j));
        throw;
    }
#       endif /* __STL_USE_EXCEPTIONS */
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::new_elements_at_back(size_type new_elements) {
    size_type new_nodes = (new_elements + buffer_size() - 1) / buffer_size();
    reserve_map_at_back(new_nodes);
    size_type i;
    __STL_TRY {
        for (i = 1; i <= new_nodes; ++i)
            *(finish.node + i) = allocate_node();
    }
#       ifdef __STL_USE_EXCEPTIONS
    catch(...) {
        for (size_type j = 1; j < i; ++j)
            deallocate_node(*(finish.node + j));
        throw;
    }
#       endif /* __STL_USE_EXCEPTIONS */
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::destroy_nodes_at_front(iterator before_start) {
    for (map_pointer n = before_start.node; n < start.node; ++n)
        deallocate_node(*n);
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::destroy_nodes_at_back(iterator after_finish) {
    for (map_pointer n = after_finish.node; n > finish.node; --n)
        deallocate_node(*n);
}

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::reallocate_map(size_type nodes_to_add,
                                              bool add_at_front) {
    size_type old_num_nodes = finish.node - start.node + 1;
    size_type new_num_nodes = old_num_nodes + nodes_to_add;
    
    map_pointer new_nstart;
    if (map_size > 2 * new_num_nodes) {
        /*
         在这种情况下, 不需要重新分配内存, 仅仅是在控制中心里面, 做一次 Node 指针的搬移操作.
         */
        new_nstart = map + (map_size - new_num_nodes) / 2
        + (add_at_front ? nodes_to_add : 0);
        if (new_nstart < start.node)
            copy(start.node, finish.node + 1, new_nstart);
        else
            copy_backward(start.node, finish.node + 1, new_nstart + old_num_nodes);
    } else {
        size_type new_map_size = map_size + max(map_size, nodes_to_add) + 2;
        // 控制中心, 指向新的更大的空间, 并且进行数据的搬移操作.
        map_pointer new_map = map_allocator::allocate(new_map_size);
        new_nstart = new_map + (new_map_size - new_num_nodes) / 2
        + (add_at_front ? nodes_to_add : 0);
        copy(start.node, finish.node + 1, new_nstart);
        map_allocator::deallocate(map, map_size); // 销毁原来的空间
        map = new_map;
        map_size = new_map_size; // 更新到新的空间.
    }
    
    start.set_node(new_nstart);
    finish.set_node(new_nstart + old_num_nodes - 1);
}


// Nonmember functions.

#ifndef __STL_NON_TYPE_TMPL_PARAM_BUG

/*
 相等判断, 首先是 size 判断, 然后调用通用 equal 算法, 在其中, 会根据进行迭代每一个元素的判断.
 */
template <class T, class Alloc, size_t BufSiz>
bool operator==(const deque<T, Alloc, BufSiz>& x,
                const deque<T, Alloc, BufSiz>& y) {
    return x.size() == y.size() && equal(x.begin(), x.end(), y.begin());
}

template <class T, class Alloc, size_t BufSiz>
bool operator<(const deque<T, Alloc, BufSiz>& x,
               const deque<T, Alloc, BufSiz>& y) {
    return lexicographical_compare(x.begin(), x.end(), y.begin(), y.end());
}

#endif /* __STL_NON_TYPE_TMPL_PARAM_BUG */

#if defined(__STL_FUNCTION_TMPL_PARTIAL_ORDER) && \
!defined(__STL_NON_TYPE_TMPL_PARAM_BUG)

template <class T, class Alloc, size_t BufSiz>
inline void swap(deque<T, Alloc, BufSiz>& x, deque<T, Alloc, BufSiz>& y) {
    x.swap(y);
}

#endif

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma reset woff 1174
#endif

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_DEQUE_H */
