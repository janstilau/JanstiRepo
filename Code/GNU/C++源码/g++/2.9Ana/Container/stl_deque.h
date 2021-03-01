#ifndef __SGI_STL_INTERNAL_DEQUE_H
#define __SGI_STL_INTERNAL_DEQUE_H

__STL_BEGIN_NAMESPACE

/*
 __deque_iterator 将 deque 的复杂底层数据进行了包装.
 */

template <class T, class Ref, class Ptr, size_t BufSiz>
struct __deque_iterator {
    typedef __deque_iterator<T, T&, T*, BufSiz>             iterator;
    typedef __deque_iterator<T, const T&, const T*, BufSiz> const_iterator;
    static size_t buffer_size() {return __deque_buf_size(BufSiz, sizeof(T)); }
    
    // deque 对于迭代器的适配.
    typedef random_access_iterator_tag iterator_category; // random 的 iterator
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
    
    __deque_iterator(T* x, map_pointer y): cur(x), first(*y), last(*y + buffer_size()), node(y) {}
    __deque_iterator() : cur(0), first(0), last(0), node(0) {}
    __deque_iterator(const iterator& x) : cur(x.cur), first(x.first), last(x.last), node(x.node) {}
    
    reference operator*() const { return *cur; }
    pointer operator->() const { return &(operator*()); }
    
    difference_type operator-(const self& x) const {
        return
        buffer_size() * (node - x.node - 1) // 控制中心节点之间的距离 * 缓存区大小.
        + (cur - first) // 当前缓存区内,  current 和 fist 之间的距离
        + (x.last - x.cur); // 目标缓存区内, end 和 目标 current 之间的距离.
    }
    
    // ++ 操作符, 有着自动更换节点的功能.
    self& operator++() {
        ++cur;
        if (cur == last) {
            set_node(node + 1);
            cur = first;
        }
        return *this;
    }
    
    // 将逻辑集中到一处, 其他地方, 是那一处逻辑的加工.
    self operator++(int)  {
        self tmp = *this;
        ++*this;
        return tmp;
    }
    self& operator--() {
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
            // 这里, 就是还在 current 所在的那个缓存区里面.
            cur += n;
        } else {
            // 不在一个缓存区里面, 计算出对应的缓存区节点, 以及缓存区内的位置.
            difference_type node_offset =
            offset > 0 ? offset / difference_type(buffer_size())
            : -difference_type((-offset - 1) / buffer_size()) - 1;
            set_node(node + node_offset);
            cur = first + (offset - node_offset * difference_type(buffer_size()));
        }
        return *this;
    }
    // 利用前面的逻辑, 代码集中到一起.
    self operator+(difference_type n) const {
        self tmp = *this;
        return tmp += n;
    }
    // 向前走的逻辑, 直接利用 + 的逻辑.
    self& operator-=(difference_type n) { return *this += -n; }
    self operator-(difference_type n) const {
        self tmp = *this;
        return tmp -= n;
    }
    
    /*
     *(*this + n) , 这不就是指针的定义式.
     因为, 其他的操作符已经完成了, iterator 已经能够模拟出指针的效果了. 所以这里, 直接使用那些操作符就可以了.
     */
    reference operator[](difference_type n) const { return *(*this + n); }
    
    bool operator==(const self& x) const { return cur == x.cur; }
    bool operator!=(const self& x) const { return !(*this == x); }
    bool operator<(const self& x) const {
        return (node == x.node) ? (cur < x.cur) : (node < x.node);
    }
    
    void set_node(map_pointer new_node) {
        node = new_node;
        first = *new_node;
        last = first + difference_type(buffer_size());
    }
};
}


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

// Deuque 对于迭代器萃取全局方法的适配.
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

// Deque 的实现逻辑, 大量的使用了 algorithm 里面的东西.
// 只要, deque 把迭代器里面的逻辑写清楚, 那么这些算法, 就能正常的运行了. deque 的实现逻辑很复杂, 但是都是和他的实现模型相关的东西, 这些都通过了 iterator 进行了封装.
// 容器的复杂性, 算法不用知道, 只要容器的迭代器设计的好, 就能实现算法的通用性.

template <class T, class Alloc = alloc, size_t BufSiz = 0>
class deque {
public:
    static size_type buffer_size() {
        return __deque_buf_size(BufSiz, sizeof(value_type));
    }
    static size_type initial_map_size() { return 8; }
    
public:                         // Basic types
    typedef T value_type;
    typedef value_type* pointer;
    typedef const value_type* const_pointer;
    typedef value_type& reference;
    typedef const value_type& const_reference;
    typedef size_t size_type;
    typedef ptrdiff_t difference_type;
    
public:                         // Iterators
    typedef __deque_iterator<T, T&, T*>                      iterator;
    typedef __deque_iterator<T, const T&, const T*>          const_iterator;
    
    typedef reverse_iterator<const_iterator> const_reverse_iterator;
    typedef reverse_iterator<iterator> reverse_iterator;
    
protected:                      // Internal typedefs
    typedef pointer* map_pointer;
    typedef simple_alloc<value_type, Alloc> data_allocator;
    typedef simple_alloc<pointer, Alloc> map_allocator;

    
protected:                      // Data members
    iterator start; // 起始位置迭代器
    iterator finish; // 结束位置迭代器
    map_pointer map; // 控制中心数组的起始位置.
    size_type map_size; // 控制中心的大小.
    
public:
    iterator begin() { return start; }
    iterator end() { return finish; }
    const_iterator begin() const { return start; }
    const_iterator end() const { return finish; }
    
    reverse_iterator rbegin() { return reverse_iterator(finish); }
    reverse_iterator rend() { return reverse_iterator(start); }
    const_reverse_iterator rbegin() const {
        return const_reverse_iterator(finish);
    }
    const_reverse_iterator rend() const {
        return const_reverse_iterator(start);
    }
    
    /*
     因为, deque 要模拟自己是一个数组, 所以, start 就成为了数组的起始的位置.
     直接利用 iterator 模拟指针的效果. 直接使用了类似于数组的操作.
     */
    reference operator[](size_type n) { return start[difference_type(n)]; }
    const_reference operator[](size_type n) const {
        return start[difference_type(n)];
    }
    
    reference front() { return *start; }
    reference back() { // 因为, finish 是指向了最后一个数据的后面一个位置, 所以要进行--操作.
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
    
    // 直接利用迭代器.
    // deque 模拟的是连续的空间, iterator 模拟的是指针, 所以, deque 里面, 很多操作, 就如同数组里面的指针操作.
    size_type size() const { return finish - start; }
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
            // 使用全局算法进行 copy, 相关逻辑在 stl_uninitialize.h 中.
            uninitialized_copy(x.begin(), x.end(), start);
        }
        __STL_UNWIND(destroy_map_and_nodes());
    }
    
    deque(size_type n, const value_type& value)
    : start(), finish(), map(0), map_size(0)
    {
        fill_initialize(n, value);
    }
    explicit deque(size_type n)
    : start(), finish(), map(0), map_size(0)
    {
        fill_initialize(n, value_type());
    }
    
    template <class InputIterator>
    deque(InputIterator first, InputIterator last)
    : start(), finish(), map(0), map_size(0)
    {
        range_initialize(first, last, iterator_category(first));
    }
    
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
    
    // 指针交换, 非常非常快.
    void swap(deque& x) {
        __STD::swap(start, x.start);
        __STD::swap(finish, x.finish);
        __STD::swap(map, x.map);
        __STD::swap(map_size, x.map_size);
    }
    
public:
    void push_back(const value_type& t) {
        if (finish.cur != finish.last - 1) {
            // 直接在缓存区操作.
            construct(finish.cur, t);
            ++finish.cur;
        } else {
            push_back_aux(t);
        }
    }
    
    void push_front(const value_type& t) {
        if (start.cur != start.first) {
            // 直接在缓存区操作.
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
        } else {
            pop_back_aux();
        }
    }
    
    void pop_front() {
        if (start.cur != start.last - 1) {
            destroy(start.cur);
            ++start.cur;
        } else {
            pop_front_aux();
        }
    }
    
public:
    iterator insert(iterator position, const value_type& x) {
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
    
    void insert(iterator pos, size_type n, const value_type& x);
    
    template <class InputIterator>
    void insert(iterator pos, InputIterator first, InputIterator last) {
        insert(pos, first, last, iterator_category(first));
    }
    void insert(iterator pos, const value_type* first, const value_type* last);
    void insert(iterator pos, const_iterator first, const_iterator last);
    
    void resize(size_type new_size, const value_type& x) {
        const size_type len = size();
        if (new_size < len)
            // 缩小, 删除后面的内容.
            erase(start + new_size, finish);
        else
            // 扩张, 向后面插入新的值.
            insert(finish, new_size - len, x);
    }
    
    void resize(size_type new_size) { resize(new_size, value_type()); }
    
public:
    iterator erase(iterator pos) {
        iterator next = pos;
        ++next;
        difference_type index = pos - start;
        if (index < (size() >> 1)) {
            // 搬移前面
            copy_backward(start, pos, next);
            pop_front();
        } else {
            // 搬移后面.
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
    
protected:
    
    // 先判断, 缓存区里面有没有足够内容. 没有的话, 向控制中心申请. 有可能会有控制中心的扩容处理.
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
    
    // 控制中心需要扩容了.
    void reserve_map_at_back (size_type nodes_to_add = 1) {
        if (nodes_to_add + 1 > map_size - (finish.node - map))
            reallocate_map(nodes_to_add, false);
    }
    
    void reserve_map_at_front (size_type nodes_to_add = 1) {
        if (nodes_to_add > start.node - map)
            reallocate_map(nodes_to_add, true);
    }
    
    void reallocate_map(size_type nodes_to_add, bool add_at_front);
    
    // 通过分配器, 分配一个缓存区的空间
    pointer allocate_node() { return data_allocator::allocate(buffer_size()); }
    // 通过分配器, 回收一个缓存区的空间
    void deallocate_node(pointer n) { data_allocator::deallocate(n, buffer_size()); }
    
public:
    bool operator==(const deque<T, Alloc, 0>& x) const {
        // equal, 全局方法, 比较两个序列.
        return size() == x.size() && equal(begin(), end(), x.begin());
    }
    bool operator!=(const deque<T, Alloc, 0>& x) const {
        return size() != x.size() || !equal(begin(), end(), x.begin());
    }
    bool operator<(const deque<T, Alloc, 0>& x) const {
        return lexicographical_compare(begin(), end(), x.begin(), x.end());
    }
};

template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::insert(iterator pos,
                                      size_type n,
                                      const value_type& x) {
    if (pos.cur == start.cur) {
        // 如果, 在头上插入
        iterator new_start = reserve_elements_at_front(n);
        uninitialized_fill(new_start, start, x);
        start = new_start;
    } else if (pos.cur == finish.cur) {
        // 如果, 在尾巴插入.
        iterator new_finish = reserve_elements_at_back(n);
        uninitialized_fill(finish, new_finish, x);
        finish = new_finish;
    } else {
        insert_aux(pos, n, x);
    }
}

#ifndef __STL_MEMBER_TEMPLATES  

// 插入指针类型范围内的数据.
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
        // 这里,  会判断, 是应该前面坍塌, 还是后面迁移.
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

// 这些复杂的操作, 都是建立在已有的操作的基础上. 所以, 复杂的类, 是通过一点点小的, 可以复用的方法建立起来的.
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

// 通过, num_elements 分配控制中心和对应的缓存区的空间. 这里只有分配, 还没有进行值的填充.
template <class T, class Alloc, size_t BufSize>
void deque<T, Alloc, BufSize>::create_map_and_nodes(size_type num_elements) {
    
    size_type num_nodes = num_elements / buffer_size() + 1;
    map_size = max(initial_map_size(), num_nodes + 2);
    // 这里, 是通过分配器获取的资源.
    map = map_allocator::allocate(map_size);
    // 把起始的 node, 放到了中间位置.
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

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_DEQUE_H */
