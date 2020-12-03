#ifndef __SGI_STL_INTERNAL_HASHTABLE_H
#define __SGI_STL_INTERNAL_HASHTABLE_H

/*
 该类是哈希 map, set, mutli哈希 map, set 能够正常运转的基础.
 */

#include <stl_algobase.h>
#include <stl_alloc.h>
#include <stl_construct.h>
#include <stl_tempbuf.h>
#include <stl_algo.h>
#include <stl_uninitialized.h>
#include <stl_function.h>
#include <stl_vector.h>
#include <stl_hash_fun.h>

__STL_BEGIN_NAMESPACE

/*
 一个简单的链表节点.
 */
template <class Value>
struct __hashtable_node
{
    __hashtable_node* next;
    // 需要注意的是, 这里的 Value, 是节点, 也就是 key, value 的组合, 当然, 对于 set 来说, key 就是 value. 但是对于 map 来说, key+value 才是 node.
    Value val;
};  

template <class Value, class Key, class HashFcn,
class ExtractKey, class EqualKey, class Alloc = alloc>
class hashtable;

template <class Value, class Key, class HashFcn,
class ExtractKey, class EqualKey, class Alloc>
struct __hashtable_iterator;

template <class Value, class Key, class HashFcn,
class ExtractKey, class EqualKey, class Alloc>
struct __hashtable_const_iterator;

template <class Value, class Key, class HashFcn,
class ExtractKey, class EqualKey, class Alloc>
struct __hashtable_iterator {
    typedef hashtable<Value, Key, HashFcn, ExtractKey, EqualKey, Alloc>
    hashtable;
    typedef __hashtable_iterator<Value, Key, HashFcn,
    ExtractKey, EqualKey, Alloc>
    iterator;
    typedef __hashtable_const_iterator<Value, Key, HashFcn,
    ExtractKey, EqualKey, Alloc>
    const_iterator;
    typedef __hashtable_node<Value> node;
    
    /*
     hash 表的迭代器, 不能回走.
     */
    typedef forward_iterator_tag iterator_category;
    typedef Value value_type;
    typedef ptrdiff_t difference_type;
    typedef size_t size_type;
    typedef Value& reference;
    typedef Value* pointer;
    
    /*
     Node 是链表里面的 Node, 根据 Node 可以找到下一个节点的位置.
     */
    node* cur;
    /*
     Ht 表示的是哈希表的数组, 这里, 没有表示当前数组位置的地方, 是因为可以通过 bucket 计算公式算出来.
     */
    hashtable* ht;
    
    __hashtable_iterator(node* n, hashtable* tab) : cur(n), ht(tab) {}
    __hashtable_iterator() {}
    /*
     cur 能够结局大部分问题, 但是对于迭代器的移动, 需要用到 hashTable 的东西.
     */
    reference operator*() const { return cur->val; }
    pointer operator->() const { return &(operator*()); }
    iterator& operator++();
    iterator operator++(int);
    bool operator==(const iterator& it) const { return cur == it.cur; }
    bool operator!=(const iterator& it) const { return cur != it.cur; }
};


template <class Value, class Key, class HashFcn,
class ExtractKey, class EqualKey, class Alloc>
struct __hashtable_const_iterator {
    typedef hashtable<Value, Key, HashFcn, ExtractKey, EqualKey, Alloc>
    hashtable;
    typedef __hashtable_iterator<Value, Key, HashFcn,
    ExtractKey, EqualKey, Alloc>
    iterator;
    typedef __hashtable_const_iterator<Value, Key, HashFcn,
    ExtractKey, EqualKey, Alloc>
    const_iterator;
    typedef __hashtable_node<Value> node;
    
    typedef forward_iterator_tag iterator_category;
    typedef Value value_type;
    typedef ptrdiff_t difference_type;
    typedef size_t size_type;
    typedef const Value& reference;
    typedef const Value* pointer;
    
    const node* cur;
    const hashtable* ht;
    
    __hashtable_const_iterator(const node* n, const hashtable* tab)
    : cur(n), ht(tab) {}
    __hashtable_const_iterator() {}
    __hashtable_const_iterator(const iterator& it) : cur(it.cur), ht(it.ht) {}
    reference operator*() const { return cur->val; }
    pointer operator->() const { return &(operator*()); }
    const_iterator& operator++();
    const_iterator operator++(int);
    bool operator==(const const_iterator& it) const { return cur == it.cur; }
    bool operator!=(const const_iterator& it) const { return cur != it.cur; }
};

/*
 在类的定义外, 定义函数, 要把所有的东西都写全.
 */
template <class V, class K, class HF, class ExK, class EqK, class A>
__hashtable_iterator<V, K, HF, ExK, EqK, A>&
__hashtable_iterator<V, K, HF, ExK, EqK, A>::operator++()
{
    /*
     显示在当前的 bucket 所在的链表里面找. 如果当前链表没有了, 就从哈希表中查找.
     在 iterator 内部, 没有存储哈希表的当前 bucket 位置, 而是根据 hashCode 找到的.
     */
    const node* old = cur;
    cur = cur->next;
    if (!cur) {
        // 从当前的 node, 查找到 bucket 的位置, 然后不断迭代判断下一个拥有 node 链表的 bucket 在哪里.
        size_type bucket = ht->bkt_num(old->val);
        while (!cur && ++bucket < ht->bucketsVector.size())
            cur = ht->bucketsVector[bucket];
    }
    return *this;
}

/*
 后++, 一定是调用前++ 的实现.
 */
template <class V, class K, class HF, class ExK, class EqK, class A>
inline __hashtable_iterator<V, K, HF, ExK, EqK, A>
__hashtable_iterator<V, K, HF, ExK, EqK, A>::operator++(int)
{
    iterator tmp = *this;
    ++*this;
    return tmp;
}

template <class V, class K, class HF, class ExK, class EqK, class A>
__hashtable_const_iterator<V, K, HF, ExK, EqK, A>&
__hashtable_const_iterator<V, K, HF, ExK, EqK, A>::operator++()
{
    const node* old = cur;
    cur = cur->next;
    if (!cur) {
        size_type bucket = ht->bkt_num(old->val);
        while (!cur && ++bucket < ht->bucketsVector.size())
            cur = ht->bucketsVector[bucket];
    }
    return *this;
}

template <class V, class K, class HF, class ExK, class EqK, class A>
inline __hashtable_const_iterator<V, K, HF, ExK, EqK, A>
__hashtable_const_iterator<V, K, HF, ExK, EqK, A>::operator++(int)
{
    const_iterator tmp = *this;
    ++*this;
    return tmp;
}


// Note: assumes long is at least 32 bits.
/*
 哈希表的大小, 是固定的, 每次进行扩容的时候, 都是表中最接近2倍当前值的地方.
 这个表是经验所得, 相比较数组的两倍增长, 哈希表的大小有了固定的设置.
 原因在于, 这种素数长度的 bucket 数组, 产生冲突的几率要小于其他的数值.
 */
static const int __stl_num_primes = 28;
static const unsigned long __stl_prime_list[__stl_num_primes] =
{
    53,         97,           193,         389,       769,
    1543,       3079,         6151,        12289,     24593,
    49157,      98317,        196613,      393241,    786433,
    1572869,    3145739,      6291469,     12582917,  25165843,
    50331653,   100663319,    201326611,   402653189, 805306457,
    1610612741, 3221225473ul, 4294967291ul
};

/*
 lower_bound, 二分查找, 当前应该插入的位置. 也就是说, 3080, 应该就是 6151 的位置.
 */
inline unsigned long __stl_next_prime(unsigned long n)
{
    const unsigned long* first = __stl_prime_list;
    const unsigned long* last = __stl_prime_list + __stl_num_primes;
    const unsigned long* pos = lower_bound(first, last, n);
    return pos == last ? *(last - 1) : *pos;
}

/*
 hashTable 的实现.
 */

template <class Value, class Key, class HashFcn,
class ExtractKey, class EqualKey,
class Alloc>
class hashtable {
public:
    typedef Key key_type;
    typedef Value value_type;
    typedef HashFcn hasher;
    typedef EqualKey key_equal;
    
    typedef size_t            size_type;
    typedef ptrdiff_t         difference_type;
    typedef value_type*       pointer;
    typedef const value_type* const_pointer;
    typedef value_type&       reference;
    typedef const value_type& const_reference;
    
    hasher hash_funct() const { return hash; }
    key_equal key_eq() const { return equals; }
    
private:
    hasher hash; // 哈希算法, 是保存在哈希表里面的. 这是一个函数对象.
    key_equal equals; // key 的相等判断算法, 是保存在哈希表里面的. 这是一个函数对象.
    ExtractKey get_key; // 如何从 value 中, 找到 key , 是保存在哈希表里面的. 这是一个函数对象.
    
    typedef __hashtable_node<Value> node;
    typedef simple_alloc<node, Alloc> node_allocator;
    
    vector<node*,Alloc> bucketsVector; // bucket 数组.
    size_type num_elements; // 当前个数, 一般来说, 作为容器, 它是有责任记录当前容器的数量的.
    
public:
    typedef __hashtable_iterator<Value, Key, HashFcn, ExtractKey, EqualKey, Alloc> iterator;
    typedef __hashtable_const_iterator<Value, Key, HashFcn, ExtractKey, EqualKey, Alloc> const_iterator;
    
    friend struct
    __hashtable_iterator<Value, Key, HashFcn, ExtractKey, EqualKey, Alloc>;
    friend struct
    __hashtable_const_iterator<Value, Key, HashFcn, ExtractKey, EqualKey, Alloc>;
    
public:
    // 当年要创建一个哈希表的时候, 其实是要传递一个 hash 方法进去的, 用来计算 hash 值. 但是, 不会用户去使用 hash 表, set 会使用, 在那里, 会把默认的 hash 函数传递过来.
    hashtable(size_type n,
              const HashFcn&    hf,
              const EqualKey&   eql,
              const ExtractKey& ext)
    : hash(hf), equals(eql), get_key(ext), num_elements(0)
    {
        initialize_buckets(n);
    }
    
    hashtable(size_type n,
              const HashFcn&    hf,
              const EqualKey&   eql)
    : hash(hf), equals(eql), get_key(ExtractKey()), num_elements(0)
    {
        initialize_buckets(n);
    }
    
    hashtable(const hashtable& ht)
    : hash(ht.hash), equals(ht.equals), get_key(ht.get_key), num_elements(0)
    {
        copy_from(ht);
    }
    
    hashtable& operator= (const hashtable& ht)
    {
        /*
         先清空.
         然后记录各个闭包信息.
         然后完全复制.
         */
        if (&ht != this) {
            clear();
            hash = ht.hash;
            equals = ht.equals;
            get_key = ht.get_key;
            copy_from(ht);
        }
        return *this;
    }
    
    ~hashtable() { clear(); }
    
    size_type size() const { return num_elements; }
    size_type max_size() const { return size_type(-1); }
    bool empty() const { return size() == 0; }
    
    void swap(hashtable& ht)
    {
        /*
         swap, 仅仅是成员变量的值的交换.
         bucketsVector 的 swap 也是很快的, 里面仅仅做几个指针的交换而已
         */
        __STD::swap(hash, ht.hash);
        __STD::swap(equals, ht.equals);
        __STD::swap(get_key, ht.get_key);
        bucketsVector.swap(ht.bucketsVector);
        __STD::swap(num_elements, ht.num_elements);
    }
    
    /*
     取第一个 bucket 里面的存储了数据的值.
     */
    iterator begin()
    {
        for (size_type n = 0; n < bucketsVector.size(); ++n) {
            if (bucketsVector[n]) {
                // bucketsVector[n] 里面, 就是链表的头结点.
                return iterator(bucketsVector[n], this);
            }
        }
        return end();
    }
    
    /*
     因为iterator 迭代到最后, 也就是 cur 为 nil 的状态.
     */
    iterator end() { return iterator(0, this); }
    
    /*
     const 和 非 const 是一样的, 只不过返回值的适配器类型的.
     */
    const_iterator begin() const
    {
        for (size_type n = 0; n < bucketsVector.size(); ++n)
            if (bucketsVector[n])
                return const_iterator(bucketsVector[n], this);
        return end();
    }
    
    const_iterator end() const { return const_iterator(0, this); }
    
    friend bool
    operator== __STL_NULL_TMPL_ARGS (const hashtable&, const hashtable&);
    
public:
    
    size_type bucket_count() const { return bucketsVector.size(); }
    
    size_type max_bucket_count() const
    { return __stl_prime_list[__stl_num_primes - 1]; }
    
    size_type elems_in_bucket(size_type bucket) const
    {
        size_type result = 0;
        for (node* cur = bucketsVector[bucket]; cur; cur = cur->next)
            result += 1;
        return result;
    }
    
    pair<iterator, bool> insert_unique(const value_type& obj)
    {
        // 先进行容量的扩展. insert 函数里面, 就不用考虑这些事了.
        resize(num_elements + 1);
        return insert_unique_noresize(obj);
    }
    
    iterator insert_equal(const value_type& obj)
    {
        resize(num_elements + 1);
        return insert_equal_noresize(obj);
    }
    
    pair<iterator, bool> insert_unique_noresize(const value_type& obj);
    iterator insert_equal_noresize(const value_type& obj);
    
#ifdef __STL_MEMBER_TEMPLATES
    template <class InputIterator>
    void insert_unique(InputIterator f, InputIterator l)
    {
        insert_unique(f, l, iterator_category(f));
    }
    
    template <class InputIterator>
    void insert_equal(InputIterator f, InputIterator l)
    {
        insert_equal(f, l, iterator_category(f));
    }
    
    /*
     插入一个序列, 也就是不但的在序列上进行取值, 插入的过程.
     注意, 这里并没有很好地高效的办法. 因为哈希表在每次插入过程中, 是要做 bucket 位置查找, 链表的维护, 扩容处理的.
     如果用简单的内存搬移, 哈希表里面的状态就会变得混乱了.
     */
    template <class InputIterator>
    void insert_unique(InputIterator f, InputIterator l,
                       input_iterator_tag)
    {
        for ( ; f != l; ++f)
            insert_unique(*f);
    }
    
    template <class InputIterator>
    void insert_equal(InputIterator f, InputIterator l,
                      input_iterator_tag)
    {
        for ( ; f != l; ++f)
            insert_equal(*f);
    }
    
    template <class ForwardIterator>
    void insert_unique(ForwardIterator f, ForwardIterator l,
                       forward_iterator_tag)
    {
        size_type n = 0;
        distance(f, l, n);
        resize(num_elements + n);
        for ( ; n > 0; --n, ++f)
            insert_unique_noresize(*f);
    }
    
    template <class ForwardIterator>
    void insert_equal(ForwardIterator f, ForwardIterator l,
                      forward_iterator_tag)
    {
        size_type n = 0;
        distance(f, l, n);
        resize(num_elements + n);
        for ( ; n > 0; --n, ++f)
            insert_equal_noresize(*f);
    }
    
#else /* __STL_MEMBER_TEMPLATES */
    /*
     iterator 为指针的情况下的插入序列的实现.
     可以看到, 能够确定 size 的情况下, 优先使用 size 判断. 相比迭代器的比较, 这样的操作要快一点.
     */
    void insert_unique(const value_type* f, const value_type* l)
    {
        size_type n = l - f;
        resize(num_elements + n);
        for ( ; n > 0; --n, ++f)
            insert_unique_noresize(*f);
    }
    
    void insert_equal(const value_type* f, const value_type* l)
    {
        size_type n = l - f;
        resize(num_elements + n);
        for ( ; n > 0; --n, ++f)
            insert_equal_noresize(*f);
    }
    
    void insert_unique(const_iterator f, const_iterator l)
    {
        size_type n = 0;
        distance(f, l, n);
        resize(num_elements + n);
        for ( ; n > 0; --n, ++f)
            insert_unique_noresize(*f);
    }
    
    void insert_equal(const_iterator f, const_iterator l)
    {
        size_type n = 0;
        distance(f, l, n);
        resize(num_elements + n);
        for ( ; n > 0; --n, ++f)
            insert_equal_noresize(*f);
    }
#endif /*__STL_MEMBER_TEMPLATES */
    
    reference find_or_insert(const value_type& obj);
    
    /*
     对于 hashTable 来说, find 就是 key 的相等性判断.
     equals, get_key 都是哈希表里面应该存储的功能.
     可以看到, 其实这种, 存储相关闭包的做法, 已经在 C++ 时代, 就十分普遍了.
     */
    iterator find(const key_type& key)
    {
        size_type n = bkt_num_key(key);
        node* first;
        for ( first = bucketsVector[n];
             first && !equals(get_key(first->val), key);
             first = first->next)
        {}
        return iterator(first, this);
    }
    // const , 仅仅是返回的迭代器的类型不同.
    const_iterator find(const key_type& key) const
    {
        size_type n = bkt_num_key(key);
        const node* first;
        for ( first = bucketsVector[n];
             first && !equals(get_key(first->val), key);
             first = first->next)
        {}
        return const_iterator(first, this);
    }
    
    /*
     因为这里面是会有相等性的元素的, 所以这里找到 bucket 之后, 是一次链表的遍历操作.
     */
    size_type count(const key_type& key) const
    {
        const size_type n = bkt_num_key(key);
        size_type result = 0;
        
        for (const node* cur = bucketsVector[n]; cur; cur = cur->next)
            if (equals(get_key(cur->val), key)) {
                ++result;
            }
        return result;
    }
    
    pair<iterator, iterator> equal_range(const key_type& key);
    pair<const_iterator, const_iterator> equal_range(const key_type& key) const;
    
    size_type erase(const key_type& key);
    void erase(const iterator& it);
    void erase(iterator first, iterator last);
    
    void erase(const const_iterator& it);
    void erase(const_iterator first, const_iterator last);
    
    void resize(size_type num_elements_hint);
    void clear();
    
private:
    /*
     直接从容量表中取得长度.
     */
    size_type next_size(size_type n) const { return __stl_next_prime(n); }
    
    void initialize_buckets(size_type n)
    {
        const size_type n_buckets = next_size(n);
        bucketsVector.reserve(n_buckets);
        /*
         Vector 进行一次初始化的操作. 全部进行置空处理.
         */
        bucketsVector.insert(bucketsVector.end(), n_buckets, (node*) 0);
        num_elements = 0;
    }
    
    size_type bkt_num_key(const key_type& key) const
    {
        return bkt_num_key(key, bucketsVector.size());
    }
    
    /*
     从 obj 中, 通过 get_key 获取到 key 值, 然后根据 hash 获取到 hash 值, 然后进行取余操作, 获取到 bucket 所在的位置.
     */
    size_type bkt_num(const value_type& obj) const
    {
        return bkt_num_key(get_key(obj));
    }
    
    size_type bkt_num_key(const key_type& key, size_t n) const
    {
        // 寻找 bucket, 就是取余操作.
        return hash(key) % n;
    }
    
    size_type bkt_num(const value_type& obj, size_t n) const
    {
        return bkt_num_key(get_key(obj), n);
    }
    
    /*
     Construct 就是, 在相应的位置, 进行拷贝构造函数的初始化.
     */
    node* new_node(const value_type& obj)
    {
        node* n = node_allocator::allocate();
        n->next = 0;
        __STL_TRY {
            construct(&n->val, obj);
            return n;
        }
        __STL_UNWIND(node_allocator::deallocate(n));
    }
    
    /*
     destroy 就是调用对应类型的析构函数.
     */
    void delete_node(node* n)
    {
        destroy(&n->val);
        node_allocator::deallocate(n);
    }
    
    void erase_bucket(const size_type n, node* first, node* last);
    void erase_bucket(const size_type n, node* last);
    
    void copy_from(const hashtable& ht);
};

#ifndef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class V, class K, class HF, class ExK, class EqK, class All>
inline forward_iterator_tag
iterator_category(const __hashtable_iterator<V, K, HF, ExK, EqK, All>&)
{
    return forward_iterator_tag();
}

template <class V, class K, class HF, class ExK, class EqK, class All>
inline V* value_type(const __hashtable_iterator<V, K, HF, ExK, EqK, All>&)
{
    return (V*) 0;
}

template <class V, class K, class HF, class ExK, class EqK, class All>
inline hashtable<V, K, HF, ExK, EqK, All>::difference_type*
distance_type(const __hashtable_iterator<V, K, HF, ExK, EqK, All>&)
{
    return (hashtable<V, K, HF, ExK, EqK, All>::difference_type*) 0;
}

template <class V, class K, class HF, class ExK, class EqK, class All>
inline forward_iterator_tag
iterator_category(const __hashtable_const_iterator<V, K, HF, ExK, EqK, All>&)
{
    return forward_iterator_tag();
}

template <class V, class K, class HF, class ExK, class EqK, class All>
inline V* 
value_type(const __hashtable_const_iterator<V, K, HF, ExK, EqK, All>&)
{
    return (V*) 0;
}

template <class V, class K, class HF, class ExK, class EqK, class All>
inline hashtable<V, K, HF, ExK, EqK, All>::difference_type*
distance_type(const __hashtable_const_iterator<V, K, HF, ExK, EqK, All>&)
{
    return (hashtable<V, K, HF, ExK, EqK, All>::difference_type*) 0;
}

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

/*
 可以看到, 对于哈希表的相等判断, 就是一个个的判断.
 1. size 不相等, 直接不相等.
 2. 每个值进行相等性判断.
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
bool operator==(const hashtable<V, K, HF, Ex, Eq, A>& ht1,
                const hashtable<V, K, HF, Ex, Eq, A>& ht2)
{
    typedef typename hashtable<V, K, HF, Ex, Eq, A>::node node;
    if (ht1.bucketsVector.size() != ht2.bucketsVector.size())
        return false;
    for (int n = 0; n < ht1.bucketsVector.size(); ++n) {
        node* cur1 = ht1.bucketsVector[n];
        node* cur2 = ht2.bucketsVector[n];
        for ( ; cur1 && cur2 && cur1->val == cur2->val;
             cur1 = cur1->next, cur2 = cur2->next)
        {}
        if (cur1 || cur2)
            return false;
    }
    return true;
}  

#ifdef __STL_FUNCTION_TMPL_PARTIAL_ORDER
/*
 一个简便的函数, 里面其实就是调用了 哈希表的 swap 方法.
 */
template <class Val, class Key, class HF, class Extract, class EqKey, class A>
inline void swap(hashtable<Val, Key, HF, Extract, EqKey, A>& ht1,
                 hashtable<Val, Key, HF, Extract, EqKey, A>& ht2) {
    ht1.swap(ht2);
}

#endif /* __STL_FUNCTION_TMPL_PARTIAL_ORDER */

/*
 哈希表里面, 如果需要扩容, 都会在一个专门的函数中处理.
 所以, 在进行实际的 insert 的时候, 都不需要考虑内存扩容的问题了.
 这里, 方法明确的标明了, noresize.
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
pair<typename hashtable<V, K, HF, Ex, Eq, A>::iterator, bool> 
hashtable<V, K, HF, Ex, Eq, A>::insert_unique_noresize(const value_type& obj) {
    /*
     直接找到 bucket, 取出里面存储的链表.
     */
    const size_type n = bkt_num(obj);
    node* first = bucketsVector[n];
    /*
     在链表里面查找, 是否已经存在了该值.
     这里, 判断是否存在的条件是, 根据 get_key 获取到 key 值, 然后判断 key 值是否相等.
     虽然, 我们认为, 哈希表里面, 用来存储 value 值. 但是在哈希表的内部, key 值其实是最重要的.
     */
    for (node* cur = first; cur; cur = cur->next) {
        if (equals(get_key(cur->val), get_key(obj))) {
            return pair<iterator, bool>(iterator(cur, this), false);
        }
    }
    
    /*
     如果没有, 就把 obj 前插到 bucket 的链表中.
     */
    node* tmp = new_node(obj);
    tmp->next = first;
    bucketsVector[n] = tmp;
    ++num_elements;
    return pair<iterator, bool>(iterator(tmp, this), true);
}

template <class V, class K, class HF, class Ex, class Eq, class A>
typename hashtable<V, K, HF, Ex, Eq, A>::iterator 
hashtable<V, K, HF, Ex, Eq, A>::insert_equal_noresize(const value_type& obj)
{
    const size_type n = bkt_num(obj);
    node* first = bucketsVector[n];
    
    /*
     在 bucket 所在链表中寻找, 如果找到了, 放到临近的位置上.
     所以, 这其实就是 insert_equal 和 insert_unique 的区别.
     insert_equal 会在已经存在的基础上, 插入到相应的位置.
     在哈希表中, 相同的元素, 会在临近的位置上.
     */
    for (node* cur = first; cur; cur = cur->next)
        if (equals(get_key(cur->val), get_key(obj))) {
            node* tmp = new_node(obj);
            tmp->next = cur->next;
            cur->next = tmp;
            ++num_elements;
            return iterator(tmp, this);
        }
    
    /*
     如果没有, 前插法, 插入到 bucket 所拥有链表中.
     */
    node* tmp = new_node(obj);
    tmp->next = first;
    bucketsVector[n] = tmp;
    ++num_elements;
    return iterator(tmp, this);
}

/*
 如果找到, 就返回, 如果没有找到, 就插入. 一般[]操纵符, 会产生该行为.
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
typename hashtable<V, K, HF, Ex, Eq, A>::reference 
hashtable<V, K, HF, Ex, Eq, A>::find_or_insert(const value_type& obj)
{
    resize(num_elements + 1);
    
    size_type n = bkt_num(obj);
    node* first = bucketsVector[n];
    
    for (node* cur = first; cur; cur = cur->next)
        if (equals(get_key(cur->val), get_key(obj)))
            return cur->val;
    
    node* tmp = new_node(obj);
    tmp->next = first;
    bucketsVector[n] = tmp;
    ++num_elements;
    return tmp->val;
}

template <class V, class K, class HF, class Ex, class Eq, class A>
pair<typename hashtable<V, K, HF, Ex, Eq, A>::iterator,
typename hashtable<V, K, HF, Ex, Eq, A>::iterator>
hashtable<V, K, HF, Ex, Eq, A>::equal_range(const key_type& key)
{
    typedef pair<iterator, iterator> pii;
    const size_type n = bkt_num_key(key);
    
    for (node* first = bucketsVector[n]; first; first = first->next) {
        if (equals(get_key(first->val), key)) {
            for (node* cur = first->next; cur; cur = cur->next)
                if (!equals(get_key(cur->val), key))
                    return pii(iterator(first, this), iterator(cur, this));
            for (size_type m = n + 1; m < bucketsVector.size(); ++m)
                if (bucketsVector[m])
                    return pii(iterator(first, this),
                               iterator(bucketsVector[m], this));
            return pii(iterator(first, this), end());
        }
    }
    return pii(end(), end());
}

template <class V, class K, class HF, class Ex, class Eq, class A>
pair<typename hashtable<V, K, HF, Ex, Eq, A>::const_iterator, 
typename hashtable<V, K, HF, Ex, Eq, A>::const_iterator>
hashtable<V, K, HF, Ex, Eq, A>::equal_range(const key_type& key) const
{
    typedef pair<const_iterator, const_iterator> pii;
    const size_type n = bkt_num_key(key);
    
    for (const node* first = bucketsVector[n] ; first; first = first->next) {
        if (equals(get_key(first->val), key)) {
            for (const node* cur = first->next; cur; cur = cur->next)
                if (!equals(get_key(cur->val), key))
                    return pii(const_iterator(first, this),
                               const_iterator(cur, this));
            for (size_type m = n + 1; m < bucketsVector.size(); ++m)
                if (bucketsVector[m])
                    return pii(const_iterator(first, this),
                               const_iterator(bucketsVector[m], this));
            return pii(const_iterator(first, this), end());
        }
    }
    return pii(end(), end());
}

/*
 erase 的操作, 也就是找到节点, 然后在链表中删除了.
 注意, 这里是将所有的 key 节点都进行删除.
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
typename hashtable<V, K, HF, Ex, Eq, A>::size_type 
hashtable<V, K, HF, Ex, Eq, A>::erase(const key_type& key)
{
    const size_type n = bkt_num_key(key);
    node* first = bucketsVector[n];
    size_type erased = 0;
    
    if (first) {
        node* cur = first;
        node* next = cur->next;
        while (next) {
            if (equals(get_key(next->val), key)) {
                cur->next = next->next;
                delete_node(next);
                next = cur->next;
                ++erased;
                --num_elements;
            }
            else {
                cur = next;
                next = cur->next;
            }
        }
        if (equals(get_key(first->val), key)) {
            bucketsVector[n] = first->next;
            delete_node(first);
            ++erased;
            --num_elements;
        }
    }
    return erased;
}

/*
 这里就是单链表的坏处, 要想进行删除, 要从头到尾遍历一遍.
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
void hashtable<V, K, HF, Ex, Eq, A>::erase(const iterator& it)
{
    if (node* const p = it.cur) {
        const size_type n = bkt_num(p->val);
        node* cur = bucketsVector[n];
        
        if (cur == p) {
            bucketsVector[n] = cur->next;
            delete_node(cur);
            --num_elements;
        }
        else {
            node* next = cur->next;
            while (next) {
                if (next == p) {
                    cur->next = next->next;
                    delete_node(next);
                    --num_elements;
                    break;
                }
                else {
                    cur = next;
                    next = cur->next;
                }
            }
        }
    }
}

/*
 擦除一个范围.
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
void hashtable<V, K, HF, Ex, Eq, A>::erase(iterator first, iterator last)
{
    size_type f_bucket = first.cur ? bkt_num(first.cur->val) : bucketsVector.size();
    size_type l_bucket = last.cur ? bkt_num(last.cur->val) : bucketsVector.size();
    
    if (first.cur == last.cur)
        return;
    else if (f_bucket == l_bucket)
        erase_bucket(f_bucket, first.cur, last.cur); // 删除bucket 里面的内容, 如果 last 为 0, 则是整个都删.
    else {
        /*
         删除头 bucket 链表的后半部分, 头尾之间的所有 bucket, 尾 bucket 链表的头半部分
         */
        erase_bucket(f_bucket, first.cur, 0);
        for (size_type n = f_bucket + 1; n < l_bucket; ++n)
            erase_bucket(n, 0);
        if (l_bucket != bucketsVector.size())
            erase_bucket(l_bucket, last.cur);
    }
}

template <class V, class K, class HF, class Ex, class Eq, class A>
inline void
hashtable<V, K, HF, Ex, Eq, A>::erase(const_iterator first,
                                      const_iterator last)
{
    erase(iterator(const_cast<node*>(first.cur),
                   const_cast<hashtable*>(first.ht)),
          iterator(const_cast<node*>(last.cur),
                   const_cast<hashtable*>(last.ht)));
}

template <class V, class K, class HF, class Ex, class Eq, class A>
inline void
hashtable<V, K, HF, Ex, Eq, A>::erase(const const_iterator& it)
{
    erase(iterator(const_cast<node*>(it.cur),
                   const_cast<hashtable*>(it.ht)));
}

template <class V, class K, class HF, class Ex, class Eq, class A>
void hashtable<V, K, HF, Ex, Eq, A>::resize(size_type num_elements_hint)
{
    /*
     如果, resize 之后的值, 大于了 bucketsVector 数组的长度, 就新分配一个新的 bucket 数组.
     然后一个个的插入到这个新的数组中.
     注意, 这里利用了 vector 的特性. vector 的成员变量, 仅仅是堆中指针.
     */
    const size_type old_n = bucketsVector.size();
    if (num_elements_hint > old_n) {
        const size_type n = next_size(num_elements_hint);
        if (n > old_n) {
            vector<node*, A> tmp(n, (node*) 0);
            __STL_TRY {
                for (size_type bucket = 0; bucket < old_n; ++bucket) {
                    node* first = bucketsVector[bucket];
                    while (first) {
                        size_type new_bucket = bkt_num(first->val, n);
                        bucketsVector[bucket] = first->next;
                        first->next = tmp[new_bucket];
                        tmp[new_bucket] = first;
                        first = bucketsVector[bucket];
                    }
                }
                bucketsVector.swap(tmp);
            }
        }
    }
}

template <class V, class K, class HF, class Ex, class Eq, class A>
void hashtable<V, K, HF, Ex, Eq, A>::erase_bucket(const size_type n, 
                                                  node* first, node* last)
{
    node* cur = bucketsVector[n];
    if (cur == first)
        erase_bucket(n, last);
    else {
        node* next;
        for (next = cur->next; next != first; cur = next, next = cur->next)
            ;
        while (next) {
            cur->next = next->next;
            delete_node(next);
            next = cur->next;
            --num_elements;
        }
    }
}

template <class V, class K, class HF, class Ex, class Eq, class A>
void 
hashtable<V, K, HF, Ex, Eq, A>::erase_bucket(const size_type n, node* last)
{
    node* cur = bucketsVector[n];
    while (cur != last) {
        node* next = cur->next;
        delete_node(cur);
        cur = next;
        bucketsVector[n] = cur;
        --num_elements;
    }
}

/*
 递归 bucketsVector, 删除链表中所有元素.
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
void hashtable<V, K, HF, Ex, Eq, A>::clear()
{
    for (size_type i = 0; i < bucketsVector.size(); ++i) {
        node* cur = bucketsVector[i];
        while (cur != 0) {
            node* next = cur->next;
            delete_node(cur);
            cur = next;
        }
        bucketsVector[i] = 0;
    }
    num_elements = 0;
}

/*
 深拷贝. 
 */
template <class V, class K, class HF, class Ex, class Eq, class A>
void hashtable<V, K, HF, Ex, Eq, A>::copy_from(const hashtable& ht)
{
    bucketsVector.clear();
    bucketsVector.reserve(ht.bucketsVector.size());
    bucketsVector.insert(bucketsVector.end(), ht.bucketsVector.size(), (node*) 0);
    __STL_TRY {
        for (size_type i = 0; i < ht.bucketsVector.size(); ++i) {
            if (const node* cur = ht.bucketsVector[i]) {
                node* copy = new_node(cur->val);
                bucketsVector[i] = copy;
                
                for (node* next = cur->next; next; cur = next, next = cur->next) {
                    copy->next = new_node(next->val);
                    copy = copy->next;
                }
            }
        }
        num_elements = ht.num_elements;
    }
    __STL_UNWIND(clear());
}

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_HASHTABLE_H */

// Local Variables:
// mode:C++
// End:
