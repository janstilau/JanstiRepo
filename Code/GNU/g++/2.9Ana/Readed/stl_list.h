#ifndef __SGI_STL_INTERNAL_LIST_H
#define __SGI_STL_INTERNAL_LIST_H

__STL_BEGIN_NAMESPACE

/*
 一个双向链表的 Node, 在向分配器申请资源的时候, 除了 T 的大小, 还要增加两个指针的大小.
 */
template <class T>
struct __list_node {
    void* next;
    void* prev;
    T data;
};

template<class T, class Ref, class Ptr>
struct __list_iterator {
    typedef __list_iterator<T, T&, T*>             iterator;
    typedef __list_iterator<T, const T&, const T*> const_iterator;
    typedef __list_iterator<T, Ref, Ptr>           self;
    
    // 迭代器的元信息的适配工作.
    typedef bidirectional_iterator_tag iterator_category;
    typedef ptrdiff_t difference_type;
    typedef T value_type;
    typedef c pointer;
    typedef Ref reference;
    typedef size_t size_type;
    
    typedef __list_node<T>* link_type;
    
    // 迭代器里面, 真正的数据.
    // list 里面, 仅仅有一个节点的指针, 迭代器里面, 也仅仅有一个节点的指针.
    link_type node;
    
    // 初始化操作, 初始化 node
    __list_iterator(link_type x) : node(x) {}
    __list_iterator(const iterator& x) : node(x.node) {}
    
    // 所有的操作, 都是建立在对于这个 node 节点的基础之上.
    // 所有的这些操作, 都是让迭代器, 看起来像是一个 pointer.
    bool operator==(const self& x) const { return node == x.node; }
    bool operator!=(const self& x) const { return node != x.node; }
    reference operator*() const { return (*node).data; }
    pointer operator->() const { return &(operator*()); }
    
    // 前++, node 先指向后一个节点, 然后返回自身.
    self& operator++() {
        node = (link_type)((*node).next);
        return *this;
    }
    // 后++, 先记录自身现在的状态, node 再指向后一个节点, 然后返回记录
    self operator++(int) {
        self tmp = *this;
        ++*this;
        return tmp;
    }
    self& operator--() {
        node = (link_type)((*node).prev);
        return *this;
    }
    self operator--(int) {
        self tmp = *this;
        --*this;
        return tmp;
    }
};

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

// 以下是一些模板方法, __list_iterator 对它们的特化实现.
template <class T, class Ref, class Ptr>
inline bidirectional_iterator_tag
iterator_category(const __list_iterator<T, Ref, Ptr>&) {
    return bidirectional_iterator_tag();
}

template <class T, class Ref, class Ptr>
inline T*
value_type(const __list_iterator<T, Ref, Ptr>&) {
    return 0;
}

template <class T, class Ref, class Ptr>
inline ptrdiff_t*
distance_type(const __list_iterator<T, Ref, Ptr>&) {
    return 0;
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */





template <class T, class Alloc = alloc>
class list {
protected:
    typedef void* void_pointer;
    typedef __list_node<T> list_node;
    typedef simple_alloc<list_node, Alloc> list_node_allocator;
    
public:      
    typedef T value_type;
    typedef value_type* pointer;
    typedef const value_type* const_pointer;
    typedef value_type& reference;
    typedef const value_type& const_reference;
    typedef list_node* link_type;
    typedef size_t size_type;
    typedef ptrdiff_t difference_type;
    
public:
    typedef __list_iterator<T, T&, T*>             iterator;
    typedef __list_iterator<T, const T&, const T*> const_iterator;
    
    typedef reverse_iterator<const_iterator> const_reverse_iterator;
    typedef reverse_iterator<iterator> reverse_iterator;
    
    /*
     construct 在对应的指针上, 调用构造函数.
     destroy 在对应的指针上, 调用析构函数.
     之所以用到这两个方法, 是因为在容器内的内存, 是被分配器管理的. 所以, 调用到这两个方法的时候, 地址已经获取到了.
     new 是分配空间 + 构造函数调用. 分配器接管了分配空间的职责.
     */
protected:
    /*
     真正的数据, 作为 sentinal Node 存在.
     */
    link_type node;
    
protected:
    /*
     GetNode, putNode 并不是对于 list 来说, 而是对于分配器来说的.
     因为分配器管理者内存资源, 所以 list 里面, 各个节点都是要通过这两个函数进行资源的管理工作.
     这里, 是使用了 static 类方法进行 allocate 和 deallocate. 没有分配器对象这个东西存在.
     也就是说, 分配器的设计者, 定义这两个 static 方法的实现的时候, 就应该清楚, 这是一个全局资源管理的事情.
     */
    link_type get_node() { return list_node_allocator::allocate(); }
    void put_node(link_type p) { list_node_allocator::deallocate(p); }
    
    
    /*
     construct(address, value)
     destroy(address)
     这两个方法, 是在对应的地址上, 是在对应的地址上, 调用构造函数和析构函数.
     但是, 地址的获取, 是通过 get_node 得到的, 地址的释放, 是 put_node 归还的. 这两个函数, 都经过了分配器.
     */
    link_type create_node(const T& x) {
        link_type p = get_node(); // 通过分配器获取空间.
        __STL_TRY {
            /*
             Constructs an object of type T in allocated uninitialized storage pointed to by p, using placement-new
             Calls new((void *)p) T(val)
             */
            construct(&p->data, x); // 调用构造函数.
        }
        __STL_UNWIND(put_node(p)); // 如果失败了, 就把资源放回到分配器管理的空间.
        return p;
    }
    void destroy_node(link_type p) {
        destroy(&p->data); // 调用析构函数.
        put_node(p); // 通过分配器归还空间.
    }
    
private:
    /*
     primitive method. 最最最重要的一个方法. 就是链表的插入操作.
     */
    iterator insert(iterator position, const T& x) {
        // 创建一个临时节点.
        link_type tmp = create_node(x);
        // 然后就是链表的插入操作, 由于是双向链表, 所以是四个操作.
        tmp->next = position.node;
        tmp->prev = position.node->prev;
        (link_type(position.node->prev))->next = tmp;
        position.node->prev = tmp;
        return tmp;
    }
    
    
protected:
    
    /*
     这个哨兵节点, 不应该看做是头节点, 应该是看做尾节点.
    */
    void empty_initialize() {
        node = get_node();
        node->next = node;
        node->prev = node;
    }
    
    // 头插法, 不断地插入 value.
    void fill_initialize(size_type n, const T& value) {
        empty_initialize();
        __STL_TRY {
            insert(begin(), n, value);
        }
        __STL_UNWIND(clear(); put_node(node));
    }
    
    // 根据一个范围, 初始化链表
    template <class InputIterator>
    void range_initialize(InputIterator first, InputIterator last) {
        empty_initialize();
        __STL_TRY {
            insert(begin(), first, last);
        }
        __STL_UNWIND(clear(); put_node(node));
    }
    void range_initialize(const T* first, const T* last) {
        empty_initialize();
        __STL_TRY {
            insert(begin(), first, last);
        }
        __STL_UNWIND(clear(); put_node(node));
    }
    void range_initialize(const_iterator first, const_iterator last) {
        empty_initialize();
        __STL_TRY {
            insert(begin(), first, last);
        }
        __STL_UNWIND(clear(); put_node(node));
    }
#endif /* __STL_MEMBER_TEMPLATES */
    
    
public:
    list() { empty_initialize(); }
    
    /*
     由于哨兵节点的存在, begin, end 的实现, 都很简单了.
     */
    iterator begin() { return (link_type)((*node).next); } // 哨兵节点的下一个节点, 空的时候, 就是哨兵节点.
    const_iterator begin() const { return (link_type)((*node).next); }
    
    iterator end() { return node; } // 哨兵节点, 作为 end 节点.
    const_iterator end() const { return node; }
    
    reverse_iterator rbegin() { return reverse_iterator(end()); } // 通过 adapter, 包装自己的 end 节点.
    const_reverse_iterator rbegin() const {
        return const_reverse_iterator(end());
    }
    reverse_iterator rend() { return reverse_iterator(begin()); } // 通过 adapter, 包装自己的 begin 节点.
    const_reverse_iterator rend() const {
        return const_reverse_iterator(begin());
    }
    
    /*
     empty 的判断标准, 就是哨兵节点, 指向自己.
     */
    bool empty() const { return node->next == node; }
    /*
     该算法, 在 list 内部, 是 O(n) 复杂度.
     */
    size_type size() const {
        size_type result = 0;
        // 这个函数的定义, 在 iterator.h 里面, 因为 begin 是普通的迭代器, 所以是从头到尾遍历的方式获取到 length.
        distance(begin(), end(), result);
        return result;
    }
    
    reference front() { return *begin(); }
    const_reference front() const { return *begin(); }
    
    reference back() { return *(--end()); } // end 是最后一个元素的下一个元素.
    const_reference back() const { return *(--end()); }
    void swap(list<T, Alloc>& x) { __STD::swap(node, x.node); }
    
    iterator insert(iterator position) { return insert(position, T()); }
    /*
     以下的 insert, 都是利用上面的 insert, 进行的范围性的操作.
     */
    template <class InputIterator>
    void insert(iterator position, InputIterator first, InputIterator last);
    void insert(iterator position, const T* first, const T* last);
    void insert(iterator position,
                const_iterator first, const_iterator last);
    void insert(iterator pos, size_type n, const T& x);
    void insert(iterator pos, int n, const T& x) {
        insert(pos, (size_type)n, x);
    }
    void insert(iterator pos, long n, const T& x) {
        insert(pos, (size_type)n, x);
    }
    
    /*
     头插, 尾插, 不过是 insert 的特殊位置而已.
     */
    void push_front(const T& x) { insert(begin(), x); }
    void push_back(const T& x) { insert(end(), x); }
    
    /*
     链表的删除操作, 不过要进行节点的数据维护.
     各个容器都有着 erase 的操作, 各个容器, 都应该维护自己数据的有效性
     */
    iterator erase(iterator position) {
        link_type next_node = link_type(position.node->next);
        link_type prev_node = link_type(position.node->prev);
        prev_node->next = next_node;
        next_node->prev = prev_node;
        destroy_node(position.node);
        return iterator(next_node);
    }
    iterator erase(iterator first, iterator last);
    
    void resize(size_type new_size, const T& x);
    void resize(size_type new_size) { resize(new_size, T()); }
    void clear();
    
    void pop_front() { erase(begin()); }
    void pop_back() {
        iterator tmp = end();
        erase(--tmp);
    }
    
    list(size_type n, const T& value) { fill_initialize(n, value); }
    list(int n, const T& value) { fill_initialize(n, value); }
    list(long n, const T& value) { fill_initialize(n, value); }
    explicit list(size_type n) { fill_initialize(n, T()); }
    
#ifdef __STL_MEMBER_TEMPLATES
    template <class InputIterator>
    list(InputIterator first, InputIterator last) {
        range_initialize(first, last);
    }
    
#else /* __STL_MEMBER_TEMPLATES */
    list(const T* first, const T* last) { range_initialize(first, last); }
    list(const_iterator first, const_iterator last) {
        range_initialize(first, last);
    }
#endif /* __STL_MEMBER_TEMPLATES */
    list(const list<T, Alloc>& x) {
        range_initialize(x.begin(), x.end());
    }
    ~list() {
        clear(); // 清空
        put_node(node); // 回收哨兵节点.
    }
    list<T, Alloc>& operator=(const list<T, Alloc>& x);
    
protected:
    void transfer(iterator position, iterator first, iterator last) {
        if (position != last) {
            (*(link_type((*last.node).prev))).next = position.node;
            (*(link_type((*first.node).prev))).next = last.node;
            (*(link_type((*position.node).prev))).next = first.node;
            link_type tmp = link_type((*position.node).prev);
            (*position.node).prev = (*last.node).prev;
            (*last.node).prev = (*first.node).prev;
            (*first.node).prev = tmp;
        }
    }
    
public:
    void splice(iterator position, list& x) {
        if (!x.empty())
            transfer(position, x.begin(), x.end());
    }
    void splice(iterator position, list&, iterator i) {
        iterator j = i;
        ++j;
        if (position == i || position == j) return;
        transfer(position, i, j);
    }
    void splice(iterator position, list&, iterator first, iterator last) {
        if (first != last)
            transfer(position, first, last);
    }
    void remove(const T& value);
    void unique();
    void merge(list& x);
    void reverse();
    void sort();
    
#ifdef __STL_MEMBER_TEMPLATES
    template <class Predicate> void remove_if(Predicate);
    template <class BinaryPredicate> void unique(BinaryPredicate);
    template <class StrictWeakOrdering> void merge(list&, StrictWeakOrdering);
    template <class StrictWeakOrdering> void sort(StrictWeakOrdering);
#endif /* __STL_MEMBER_TEMPLATES */
    
    friend bool operator== __STL_NULL_TMPL_ARGS (const list& x, const list& y);
};

/*
 链表的相等判断你, 就是一个个的比较每个节点的 data, 以及长度.
 */
template <class T, class Alloc>
inline bool operator==(const list<T,Alloc>& x, const list<T,Alloc>& y) {
    typedef typename list<T,Alloc>::link_type link_type;
    link_type e1 = x.node;
    link_type e2 = y.node;
    link_type n1 = (link_type) e1->next;
    link_type n2 = (link_type) e2->next;
    for ( ; n1 != e1 && n2 != e2 ;
         n1 = (link_type) n1->next, n2 = (link_type) n2->next)
        if (n1->data != n2->data)
            return false;
    return n1 == e1 && n2 == e2;
}

template <class T, class Alloc>
inline bool operator<(const list<T, Alloc>& x, const list<T, Alloc>& y) {
    return lexicographical_compare(x.begin(), x.end(), y.begin(), y.end());
}

#ifdef __STL_FUNCTION_TMPL_PARTIAL_ORDER

template <class T, class Alloc>
inline void swap(list<T, Alloc>& x, list<T, Alloc>& y) {
    x.swap(y);
}

#endif /* __STL_FUNCTION_TMPL_PARTIAL_ORDER */

/*
 范围性的插入, 就是 begin 到 end 的迭代, 不断地进行 insert 的操作.
 */
template <class T, class Alloc> template <class InputIterator>
void list<T, Alloc>::insert(iterator position,
                            InputIterator first, InputIterator last) {
    for ( ; first != last; ++first)
        insert(position, *first);
}

#else /* __STL_MEMBER_TEMPLATES */

/*
 范围性的插入
 */
template <class T, class Alloc>
void list<T, Alloc>::insert(iterator position, const T* first, const T* last) {
    for ( ; first != last; ++first)
        insert(position, *first);
}

/*
 范围性的插入
 */
template <class T, class Alloc>
void list<T, Alloc>::insert(iterator position,
                            const_iterator first, const_iterator last) {
    for ( ; first != last; ++first)
        insert(position, *first);
}

#endif /* __STL_MEMBER_TEMPLATES */

/*
  范围性的插入
 */
template <class T, class Alloc>
void list<T, Alloc>::insert(iterator position, size_type n, const T& x) {
    for ( ; n > 0; --n)
        insert(position, x);
}

/*
 范围性的删除.
 */
template <class T, class Alloc>
list<T,Alloc>::iterator list<T, Alloc>::erase(iterator first, iterator last) {
    while (first != last) erase(first++);
    return last;
}

template <class T, class Alloc>
void list<T, Alloc>::resize(size_type new_size, const T& x)
{
    iterator i = begin();
    size_type len = 0;
    for ( ; i != end() && len < new_size; ++i, ++len) {;}
    /*
     如果, 原有的列表过大, 就删除后面的数据.
     */
    if (len == new_size){
        erase(i, end());
    }
    /*
     否则, 就插入新的数据, 用 x 当做默认值.
     这里, 由于链表是没有 capacity 的概念的, 所以, resize 之后, 容器有多大, list 既有多大. 里面的值, 都应该是有效值.
     */
    else  {
        insert(end(), new_size - len, x);
    }
}

/*
不断地删除节点, 不断地调用 destroy_node 进行内存的处理工作.
 O(n) 复杂度.
 */
template <class T, class Alloc> 
void list<T, Alloc>::clear()
{
    link_type cur = (link_type) node->next;
    while (cur != node) {
        link_type tmp = cur;
        cur = (link_type) cur->next;
        destroy_node(tmp);
    }
    node->next = node;
    node->prev = node;
}

/*
 每一个节点, 都进行重新的赋值操作. 然后原来多个进行删除, 原来少的, 进行添加.
 */
template <class T, class Alloc>
list<T, Alloc>& list<T, Alloc>::operator=(const list<T, Alloc>& x) {
    if (this != &x) {
        iterator first1 = begin();
        iterator last1 = end();
        const_iterator first2 = x.begin();
        const_iterator last2 = x.end();
        while (first1 != last1 && first2 != last2) *first1++ = *first2++;
        if (first2 == last2)
            erase(first1, last1);
        else
            insert(last1, first2, last2);
    }
    return *this;
}

/*
 删除链表里面的所有值相等的元素.
 */
template <class T, class Alloc>
void list<T, Alloc>::remove(const T& value) {
    iterator first = begin();
    iterator last = end();
    while (first != last) {
        iterator next = first;
        ++next;
        if (*first == value) erase(first);
        first = next;
    }
}

/*
 删除所有临近的值相等的元素.
 */
template <class T, class Alloc>
void list<T, Alloc>::unique() {
    iterator first = begin();
    iterator last = end();
    if (first == last) return;
    iterator next = first;
    while (++next != last) {
        if (*first == *next)
            erase(next);
        else
            first = next;
        next = first;
    }
}

/*
 这些高质量的代码, 也会有 1, 2 这种命名的方式.
 */
template <class T, class Alloc>
void list<T, Alloc>::merge(list<T, Alloc>& x) {
    iterator first1 = begin();
    iterator last1 = end();
    iterator first2 = x.begin();
    iterator last2 = x.end();
    while (first1 != last1 && first2 != last2)
        if (*first2 < *first1) {
            iterator next = first2;
            transfer(first1, first2, ++next);
            first2 = next;
        }
        else
            ++first1;
    if (first2 != last2) transfer(last1, first2, last2);
}

template <class T, class Alloc>
void list<T, Alloc>::reverse() {
    if (node->next == node || link_type(node->next)->next == node) return;
    iterator first = begin();
    ++first;
    while (first != end()) {
        iterator old = first;
        ++first;
        transfer(begin(), old, first);
    }
}    

/*
 太复杂没看.
 */
template <class T, class Alloc>
void list<T, Alloc>::sort() {
    if (node->next == node || link_type(node->next)->next == node) return;
    list<T, Alloc> carry;
    list<T, Alloc> counter[64];
    int fill = 0;
    while (!empty()) {
        carry.splice(carry.begin(), *this, begin());
        int i = 0;
        while(i < fill && !counter[i].empty()) {
            counter[i].merge(carry);
            carry.swap(counter[i++]);
        }
        carry.swap(counter[i]);
        if (i == fill) ++fill;
    }
    
    for (int i = 1; i < fill; ++i) counter[i].merge(counter[i-1]);
    swap(counter[fill-1]);
}

#ifdef __STL_MEMBER_TEMPLATES

template <class T, class Alloc> template <class Predicate>
void list<T, Alloc>::remove_if(Predicate pred) {
    iterator first = begin();
    iterator last = end();
    /*
     删除, 还是用的 erase. 这样, 这个函数里面的逻辑, 就变得只是 遍历, remove 了.
     所有的删除操作, 还是在 erase 里面.
     */
    while (first != last) {
        iterator next = first;
        ++next;
        if (pred(*first)) erase(first);
        first = next;
    }
}

template <class T, class Alloc> template <class BinaryPredicate>
void list<T, Alloc>::unique(BinaryPredicate binary_pred) {
    iterator first = begin();
    iterator last = end();
    if (first == last) return;
    iterator next = first;
    while (++next != last) {
        if (binary_pred(*first, *next))
            erase(next);
        else
            first = next;
        next = first;
    }
}

template <class T, class Alloc> template <class StrictWeakOrdering>
void list<T, Alloc>::merge(list<T, Alloc>& x, StrictWeakOrdering comp) {
    iterator first1 = begin();
    iterator last1 = end();
    iterator first2 = x.begin();
    iterator last2 = x.end();
    while (first1 != last1 && first2 != last2)
        if (comp(*first2, *first1)) {
            iterator next = first2;
            transfer(first1, first2, ++next);
            first2 = next;
        }
        else
            ++first1;
    if (first2 != last2) transfer(last1, first2, last2);
}

template <class T, class Alloc> template <class StrictWeakOrdering>
void list<T, Alloc>::sort(StrictWeakOrdering comp) {
    if (node->next == node || link_type(node->next)->next == node) return;
    list<T, Alloc> carry;
    list<T, Alloc> counter[64];
    int fill = 0;
    while (!empty()) {
        carry.splice(carry.begin(), *this, begin());
        int i = 0;
        while(i < fill && !counter[i].empty()) {
            counter[i].merge(carry, comp);
            carry.swap(counter[i++]);
        }
        carry.swap(counter[i]);
        if (i == fill) ++fill;
    }
    
    for (int i = 1; i < fill; ++i) counter[i].merge(counter[i-1], comp);
    swap(counter[fill-1]);
}

#endif /* __STL_MEMBER_TEMPLATES */

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_LIST_H */

// Local Variables:
// mode:C++
// End:
