#ifndef __STL_LIMITED_DEFAULT_TEMPLATES
template <class Key, class Compare = less<Key>, class Alloc = alloc>
#else
template <class Key, class Compare, class Alloc = alloc>
#endif
class set {
public:
    // typedefs:
    
    typedef Key key_type;
    typedef Key value_type;
    typedef Compare key_compare;
    typedef Compare value_compare;
private:
    typedef rb_tree<key_type, value_type,
    identity<value_type>, key_compare, Alloc> rep_type;
    /*
     内部是一颗红黑树.
     */
    rep_type t;
public:
    typedef typename rep_type::const_pointer pointer;
    typedef typename rep_type::const_pointer const_pointer;
    typedef typename rep_type::const_reference reference;
    typedef typename rep_type::const_reference const_reference;
    typedef typename rep_type::const_iterator iterator;
    typedef typename rep_type::const_iterator const_iterator;
    typedef typename rep_type::const_reverse_iterator reverse_iterator;
    typedef typename rep_type::const_reverse_iterator const_reverse_iterator;
    typedef typename rep_type::size_type size_type;
    typedef typename rep_type::difference_type difference_type;
    
    // allocation/deallocation
    
    set() : t(Compare()) {}
    explicit set(const Compare& comp) : t(comp) {}
    
#ifdef __STL_MEMBER_TEMPLATES
    /*
     所有的初始化, 都是调用了红黑树的方法
     可以看到, 构造函数里面, 也是可以进行比较耗费资源的方法调用的, 只要是符合你的逻辑.
     t.insert_unique(first, last); 插入一个序列, 是一个耗时比较多的行为.
     */
    template <class InputIterator>
    set(InputIterator first, InputIterator last)
    : t(Compare()) { t.insert_unique(first, last); }
    
    template <class InputIterator>
    set(InputIterator first, InputIterator last, const Compare& comp)
    : t(comp) { t.insert_unique(first, last); }
#else
    set(const value_type* first, const value_type* last)
    : t(Compare()) { t.insert_unique(first, last); }
    set(const value_type* first, const value_type* last, const Compare& comp)
    : t(comp) { t.insert_unique(first, last); }
    
    set(const_iterator first, const_iterator last)
    : t(Compare()) { t.insert_unique(first, last); }
    set(const_iterator first, const_iterator last, const Compare& comp)
    : t(comp) { t.insert_unique(first, last); }
#endif /* __STL_MEMBER_TEMPLATES */
    
    set(const set<Key, Compare, Alloc>& x) : t(x.t) {}
    set<Key, Compare, Alloc>& operator=(const set<Key, Compare, Alloc>& x) {
        /*
         仅仅是红黑树的替代.
         */
        t = x.t;
        return *this;
    }
    
    // accessors:
    /*
     所有的这些操作, 都是转交给了红黑树, set 仅仅是一个适配器.
     */
    key_compare key_comp() const { return t.key_comp(); }
    value_compare value_comp() const { return t.key_comp(); }
    iterator begin() const { return t.begin(); }
    iterator end() const { return t.end(); }
    reverse_iterator rbegin() const { return t.rbegin(); }
    reverse_iterator rend() const { return t.rend(); }
    bool empty() const { return t.empty(); }
    size_type size() const { return t.size(); }
    size_type max_size() const { return t.max_size(); }
    void swap(set<Key, Compare, Alloc>& x) { t.swap(x.t); }
    
    // insert/erase
    typedef  pair<iterator, bool> pair_iterator_bool;
    pair<iterator,bool> insert(const value_type& x) {
        pair<typename rep_type::iterator, bool> p = t.insert_unique(x);
        return pair<iterator, bool>(p.first, p.second);
    }
    iterator insert(iterator position, const value_type& x) {
        typedef typename rep_type::iterator rep_iterator;
        return t.insert_unique((rep_iterator&)position, x);
    }
    template <class InputIterator>
    void insert(InputIterator first, InputIterator last) {
        t.insert_unique(first, last);
    }
    void insert(const_iterator first, const_iterator last) {
        t.insert_unique(first, last);
    }
    void insert(const value_type* first, const value_type* last) {
        t.insert_unique(first, last);
    }
    
    
#endif /* __STL_MEMBER_TEMPLATES */
    void erase(iterator position) {
        typedef typename rep_type::iterator rep_iterator;
        t.erase((rep_iterator&)position);
    }
    size_type erase(const key_type& x) {
        return t.erase(x);
    }
    void erase(iterator first, iterator last) {
        typedef typename rep_type::iterator rep_iterator;
        t.erase((rep_iterator&)first, (rep_iterator&)last);
    }
    void clear() { t.clear(); }
    
    // set operations:
    
    iterator find(const key_type& x) const { return t.find(x); }
    size_type count(const key_type& x) const { return t.count(x); }
    iterator lower_bound(const key_type& x) const {
        return t.lower_bound(x);
    }
    iterator upper_bound(const key_type& x) const {
        return t.upper_bound(x);
    }
    pair<iterator,iterator> equal_range(const key_type& x) const {
        return t.equal_range(x);
    }
    friend bool operator== __STL_NULL_TMPL_ARGS (const set&, const set&);
    friend bool operator< __STL_NULL_TMPL_ARGS (const set&, const set&);
};

template <class Key, class Compare, class Alloc>
inline bool operator==(const set<Key, Compare, Alloc>& x, 
                       const set<Key, Compare, Alloc>& y) {
    return x.t == y.t;
}

template <class Key, class Compare, class Alloc>
inline bool operator<(const set<Key, Compare, Alloc>& x, 
                      const set<Key, Compare, Alloc>& y) {
    return x.t < y.t;
}

#ifdef __STL_FUNCTION_TMPL_PARTIAL_ORDER

template <class Key, class Compare, class Alloc>
inline void swap(set<Key, Compare, Alloc>& x, 
                 set<Key, Compare, Alloc>& y) {
    x.swap(y);
}

#endif /* __STL_FUNCTION_TMPL_PARTIAL_ORDER */

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma reset woff 1174
#endif

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_SET_H */

// Local Variables:
// mode:C++
// End:
