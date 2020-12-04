#ifndef __SGI_STL_INTERNAL_VECTOR_H
#define __SGI_STL_INTERNAL_VECTOR_H

__STL_BEGIN_NAMESPACE 

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma set woff 1174
#endif

template <class T, class Alloc = alloc>
class vector {
public:
    typedef T value_type;
    typedef value_type* pointer;
    typedef const value_type* const_pointer;
    typedef value_type* iterator;
    typedef const value_type* const_iterator;
    typedef value_type& reference;
    typedef const value_type& const_reference;
    typedef size_t size_type;
    typedef ptrdiff_t difference_type;
    
#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION
    typedef reverse_iterator<const_iterator> const_reverse_iterator;
    typedef reverse_iterator<iterator> reverse_iterator;
#else /* __STL_CLASS_PARTIAL_SPECIALIZATION */
    typedef reverse_iterator<const_iterator, value_type, const_reference,
    difference_type>  const_reverse_iterator;
    typedef reverse_iterator<iterator, value_type, reference, difference_type>
    reverse_iterator;
#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */
protected:
    typedef simple_alloc<value_type, Alloc> data_allocator;
    /*
     起点, 终点, 容器的终点.
     iterator 就是 valueType 的指针.
     */
    iterator start;
    iterator finish;
    iterator end_of_storage;
    void deallocate() {
        // 利用了分配器的类方法, 进行了资源的回收操作.
        if (start) data_allocator::deallocate(start, end_of_storage - start);
    }
    
    /*
     这种, end 和 finish 是相同的.
     */
    void fill_initialize(size_type n, const T& value) {
        start = allocate_and_fill(n, value);
        finish = start + n;
        end_of_storage = finish;
    }
public:
    iterator begin() { return start; }
    const_iterator begin() const { return start; }
    
    iterator end() { return finish; }
    const_iterator end() const { return finish; }
    
    /*
     直接返回一个迭代器的适配器.
     */
    reverse_iterator rbegin() { return reverse_iterator(end()); }
    const_reverse_iterator rbegin() const {
        return const_reverse_iterator(end());
    }
    reverse_iterator rend() { return reverse_iterator(begin()); }
    const_reverse_iterator rend() const {
        return const_reverse_iterator(begin());
    }
    /*
        vector 就是数组的封装而已, 各种操作, 都是建立在指针的基础上的.
     */
    size_type size() const { return size_type(end() - begin()); }
    size_type capacity() const { return size_type(end_of_storage - begin()); }
    bool empty() const { return begin() == end(); }
    
    reference operator[](size_type n) { return *(begin() + n); }
    const_reference operator[](size_type n) const { return *(begin() + n); }
    
    /*
     fill_initialize 里面, 都是用 value 填充 n 个数据.
     */
    vector() : start(0), finish(0), end_of_storage(0) {}
    vector(size_type n, const T& value) { fill_initialize(n, value); }
    vector(int n, const T& value) { fill_initialize(n, value); }
    vector(long n, const T& value) { fill_initialize(n, value); }
    explicit vector(size_type n) { fill_initialize(n, T()); }
    
    vector(const vector<T, Alloc>& x) {
        start = allocate_and_copy(x.end() - x.begin(), x.begin(), x.end());
        finish = start + (x.end() - x.begin());
        end_of_storage = finish;
    }
#ifdef __STL_MEMBER_TEMPLATES
    template <class InputIterator>
    vector(InputIterator first, InputIterator last) :
    start(0), finish(0), end_of_storage(0)
    {
        range_initialize(first, last, iterator_category(first));
    }
#else /* __STL_MEMBER_TEMPLATES */
    vector(const_iterator first, const_iterator last) {
        size_type n = 0;
        // 需要提前把 N 确定下来. 因为 并不能确定 first, last 是 random iterator, 所以需要用 distance 方法计算出来.
        distance(first, last, n);
        start = allocate_and_copy(n, first, last);
        finish = start + n;
        end_of_storage = finish;
    }
#endif /* __STL_MEMBER_TEMPLATES */
    ~vector() {
        destroy(start, finish);
        deallocate();
    }
    vector<T, Alloc>& operator=(const vector<T, Alloc>& x);
    /*
     reserve 是一个非常通用的行为. OC 里面也是用的 reserve 进行的重新分配内存的资源.
     如果, 要求 reserve 的范围, 比现在的大, 就要进行新的空间的分配操作, 然后把现在的数据拷贝到新的空间里面.
     */
    void reserve(size_type n) {
        if (capacity() < n) {
            const size_type old_size = size();
            iterator tmp = allocate_and_copy(n, start, finish);
            destroy(start, finish);
            deallocate();
            start = tmp;
            finish = tmp + old_size;
            end_of_storage = start + n;
        }
    }
    reference front() { return *begin(); }
    const_reference front() const { return *begin(); }
    reference back() { return *(end() - 1); }
    const_reference back() const { return *(end() - 1); }
    
    /*
     这里, 任何数据, 到达到容器的时候, 都进行了 construct 的操作.
     之所以发生这样的事情, 是因为 C++ 里面, 对象管理资源是一个很常见的事情, 就是栈上的对象, 也有可能在管理者堆上面的资源.
     如果容器里面, 存放的是对象, 那么就是值对象, 每个值对象, 其实都自己管理者资源. 所以, 要利用拷贝构造函数, 进行资源的各自管理的工作.
     */
    void push_back(const T& x) {
        if (finish != end_of_storage) {
            construct(finish, x);
            ++finish;
        } else {
            insert_aux(end(), x);
        }
    }
    
    /*
     因为 vector 里面, 真正的成员变量就是几个指针而已, 所以这里直接交换两个 vector 的指针值就可以了.
     */
    void swap(vector<T, Alloc>& x) {
        __STD::swap(start, x.start);
        __STD::swap(finish, x.finish);
        __STD::swap(end_of_storage, x.end_of_storage);
    }
    
    iterator insert(iterator position, const T& x) {
        size_type n = position - begin();
        if (finish != end_of_storage && position == end()) {
            // 如果插入到末尾, 直接插入就可以了.
            construct(finish, x);
            ++finish;
        } else {
            insert_aux(position, x);
        }
        return begin() + n;
    }
#ifdef __STL_MEMBER_TEMPLATES
    template <class InputIterator>
    void insert(iterator position, InputIterator first, InputIterator last) {
        range_insert(position, first, last, iterator_category(first));
    }
#else /* __STL_MEMBER_TEMPLATES */
    void insert(iterator position,
                const_iterator first, const_iterator last);
#endif /* __STL_MEMBER_TEMPLATES */
    
    void insert (iterator pos, size_type n, const T& x);
    void insert (iterator pos, int n, const T& x) {
        insert(pos, (size_type) n, x);
    }
    void insert (iterator pos, long n, const T& x) {
        insert(pos, (size_type) n, x);
    }
    
    // 这里, 之前都没有考虑, 这里会调用对应类型的析构函数的啊.
    void pop_back() {
        --finish;
        destroy(finish);
    }
    
    iterator erase(iterator position) {
        /*
         直接调用的 copy. 段式的内存拷贝工作. 这就是数组的好处, 直接操作内存资源.
         */
        if (position + 1 != end())
            copy(position + 1, finish, position);
        --finish;
        destroy(finish);
        return position;
    }
    /*
     删除一段空间.
     */
    iterator erase(iterator first, iterator last) {
        iterator i = copy(last, finish, first);
        destroy(i, finish);
        finish = finish - (last - first);
        return first;
    }
    /*
     掺入一段空间.
     */
    void resize(size_type new_size, const T& x) {
        if (new_size < size())
            erase(begin() + new_size, end());
        else
            insert(end(), new_size - size(), x);
    }
    void resize(size_type new_size) { resize(new_size, T()); }
    void clear() { erase(begin(), end()); }
    
protected:
    iterator allocate_and_fill(size_type n, const T& x) {
        // 先分配
        iterator result = data_allocator::allocate(n);
        __STL_TRY {
            // 然后填充
            uninitialized_fill_n(result, n, x);
            return result;
        }
        __STL_UNWIND(data_allocator::deallocate(result, n));
    }
    
#ifdef __STL_MEMBER_TEMPLATES
    /*
     新分配一段空间, 拷贝原始的内容, 到这段新分配的空间上.
     如果是 标量类型, 就是直接内存拷贝. 如果是对象类型, 则调用构造函数.
     */
    template <class ForwardIterator>
    iterator allocate_and_copy(size_type n,
                               ForwardIterator first, ForwardIterator last) {
        iterator result = data_allocator::allocate(n);
        __STL_TRY {
            uninitialized_copy(first, last, result);
            return result;
        }
        __STL_UNWIND(data_allocator::deallocate(result, n));
    }
#else /* __STL_MEMBER_TEMPLATES */
    iterator allocate_and_copy(size_type n,
                               const_iterator first, const_iterator last) {
        iterator result = data_allocator::allocate(n);
        __STL_TRY {
            uninitialized_copy(first, last, result);
            return result;
        }
        __STL_UNWIND(data_allocator::deallocate(result, n));
    }
#endif /* __STL_MEMBER_TEMPLATES */
    
    
#ifdef __STL_MEMBER_TEMPLATES
    template <class InputIterator>
    void range_initialize(InputIterator first, InputIterator last,
                          input_iterator_tag) {
        for ( ; first != last; ++first)
            push_back(*first);
    }
    
    // This function is only called by the constructor.  We have to worry
    //  about resource leaks, but not about maintaining invariants.
    template <class ForwardIterator>
    void range_initialize(ForwardIterator first, ForwardIterator last,
                          forward_iterator_tag) {
        size_type n = 0;
        distance(first, last, n);
        start = allocate_and_copy(n, first, last);
        finish = start + n;
        end_of_storage = finish;
    }
    
    template <class InputIterator>
    void range_insert(iterator pos,
                      InputIterator first, InputIterator last,
                      input_iterator_tag);
    
    template <class ForwardIterator>
    void range_insert(iterator pos,
                      ForwardIterator first, ForwardIterator last,
                      forward_iterator_tag);
    
#endif /* __STL_MEMBER_TEMPLATES */
};

template <class T, class Alloc>
inline bool operator==(const vector<T, Alloc>& x, const vector<T, Alloc>& y) {
    return x.size() == y.size() && equal(x.begin(), x.end(), y.begin());
}

template <class T, class Alloc>
inline bool operator<(const vector<T, Alloc>& x, const vector<T, Alloc>& y) {
    return lexicographical_compare(x.begin(), x.end(), y.begin(), y.end());
}

#ifdef __STL_FUNCTION_TMPL_PARTIAL_ORDER

template <class T, class Alloc>
inline void swap(vector<T, Alloc>& x, vector<T, Alloc>& y) {
    x.swap(y);
}

#endif /* __STL_FUNCTION_TMPL_PARTIAL_ORDER */

/*
 赋值操作符里面, 进行了大量的 copy 操作.
 */
template <class T, class Alloc>
vector<T, Alloc>& vector<T, Alloc>::operator=(const vector<T, Alloc>& x) {
    if (&x != this) {
        if (x.size() > capacity()) {
            iterator tmp = allocate_and_copy(x.end() - x.begin(),
                                             x.begin(), x.end());
            destroy(start, finish);
            deallocate();
            start = tmp;
            end_of_storage = start + (x.end() - x.begin());
        }
        else if (size() >= x.size()) {
            iterator i = copy(x.begin(), x.end(), begin());
            destroy(i, finish);
        }
        else {
            copy(x.begin(), x.begin() + size(), start);
            uninitialized_copy(x.begin() + size(), x.end(), finish);
        }
        finish = start + x.size();
    }
    return *this;
}

template <class T, class Alloc>
void vector<T, Alloc>::insert_aux(iterator position, const T& x) {
    if (finish != end_of_storage) {
        /*
         如果还有空间进行插入操作, 就先挪动, 然后在指定的位置, 进行值的替换.
         */
        construct(finish, *(finish - 1));
        ++finish;
        T x_copy = x;
        copy_backward(position, finish - 2, finish - 1);
        *position = x_copy;
    } else {
        /*
         否则就新分配一块空间.
         拷贝前半部分, 插入值, 拷贝后半部分, 然后进行原有空间的释放.
         然后替换自己的 start, end 为新的空间.
         需要注意的是, 这里面, 会调用大量的构造函数, 析构函数.
         */
        const size_type old_size = size();
        const size_type len = old_size != 0 ? 2 * old_size : 1;
        iterator new_start = data_allocator::allocate(len);
        iterator new_finish = new_start;
        new_finish = uninitialized_copy(start, position, new_start);
        construct(new_finish, x);
        ++new_finish;
        new_finish = uninitialized_copy(position, finish, new_finish);
        destroy(begin(), end());
        deallocate();
        start = new_start;
        finish = new_finish;
        end_of_storage = new_start + len;
    }
}

template <class T, class Alloc>
void vector<T, Alloc>::insert(iterator position, size_type n, const T& x) {
    if (n != 0) {
        if (size_type(end_of_storage - finish) >= n) {
            T x_copy = x;
            const size_type elems_after = finish - position;
            iterator old_finish = finish;
            if (elems_after > n) {
                uninitialized_copy(finish - n, finish, finish);
                finish += n;
                copy_backward(position, old_finish - n, old_finish);
                fill(position, position + n, x_copy);
            }
            else {
                uninitialized_fill_n(finish, n - elems_after, x_copy);
                finish += n - elems_after;
                uninitialized_copy(position, old_finish, finish);
                finish += elems_after;
                fill(position, old_finish, x_copy);
            }
        }
        else {
            const size_type old_size = size();
            const size_type len = old_size + max(old_size, n);
            iterator new_start = data_allocator::allocate(len);
            iterator new_finish = new_start;
            __STL_TRY {
                new_finish = uninitialized_copy(start, position, new_start);
                new_finish = uninitialized_fill_n(new_finish, n, x);
                new_finish = uninitialized_copy(position, finish, new_finish);
            }
#         ifdef  __STL_USE_EXCEPTIONS 
            catch(...) {
                destroy(new_start, new_finish);
                data_allocator::deallocate(new_start, len);
                throw;
            }
#         endif /* __STL_USE_EXCEPTIONS */
            destroy(start, finish);
            deallocate();
            start = new_start;
            finish = new_finish;
            end_of_storage = new_start + len;
        }
    }
}

#ifdef __STL_MEMBER_TEMPLATES

template <class T, class Alloc> template <class InputIterator>
void vector<T, Alloc>::range_insert(iterator pos,
                                    InputIterator first, InputIterator last,
                                    input_iterator_tag) {
    for ( ; first != last; ++first) {
        pos = insert(pos, *first);
        ++pos;
    }
}

template <class T, class Alloc> template <class ForwardIterator>
void vector<T, Alloc>::range_insert(iterator position,
                                    ForwardIterator first,
                                    ForwardIterator last,
                                    forward_iterator_tag) {
    if (first != last) {
        size_type n = 0;
        distance(first, last, n);
        if (size_type(end_of_storage - finish) >= n) {
            const size_type elems_after = finish - position;
            iterator old_finish = finish;
            if (elems_after > n) {
                uninitialized_copy(finish - n, finish, finish);
                finish += n;
                copy_backward(position, old_finish - n, old_finish);
                copy(first, last, position);
            }
            else {
                ForwardIterator mid = first;
                advance(mid, elems_after);
                uninitialized_copy(mid, last, finish);
                finish += n - elems_after;
                uninitialized_copy(position, old_finish, finish);
                finish += elems_after;
                copy(first, mid, position);
            }
        }
        else {
            const size_type old_size = size();
            const size_type len = old_size + max(old_size, n);
            iterator new_start = data_allocator::allocate(len);
            iterator new_finish = new_start;
            __STL_TRY {
                new_finish = uninitialized_copy(start, position, new_start);
                new_finish = uninitialized_copy(first, last, new_finish);
                new_finish = uninitialized_copy(position, finish, new_finish);
            }
#         ifdef __STL_USE_EXCEPTIONS
            catch(...) {
                destroy(new_start, new_finish);
                data_allocator::deallocate(new_start, len);
                throw;
            }
#         endif /* __STL_USE_EXCEPTIONS */
            destroy(start, finish);
            deallocate();
            start = new_start;
            finish = new_finish;
            end_of_storage = new_start + len;
        }
    }
}

#else /* __STL_MEMBER_TEMPLATES */

template <class T, class Alloc>
void vector<T, Alloc>::insert(iterator position, 
                              const_iterator first,
                              const_iterator last) {
    if (first != last) {
        size_type n = 0;
        distance(first, last, n);
        if (size_type(end_of_storage - finish) >= n) {
            const size_type elems_after = finish - position;
            iterator old_finish = finish;
            if (elems_after > n) {
                uninitialized_copy(finish - n, finish, finish);
                finish += n;
                copy_backward(position, old_finish - n, old_finish);
                copy(first, last, position);
            }
            else {
                uninitialized_copy(first + elems_after, last, finish);
                finish += n - elems_after;
                uninitialized_copy(position, old_finish, finish);
                finish += elems_after;
                copy(first, first + elems_after, position);
            }
        }
        else {
            const size_type old_size = size();
            const size_type len = old_size + max(old_size, n);
            iterator new_start = data_allocator::allocate(len);
            iterator new_finish = new_start;
            __STL_TRY {
                new_finish = uninitialized_copy(start, position, new_start);
                new_finish = uninitialized_copy(first, last, new_finish);
                new_finish = uninitialized_copy(position, finish, new_finish);
            }
#         ifdef __STL_USE_EXCEPTIONS
            catch(...) {
                destroy(new_start, new_finish);
                data_allocator::deallocate(new_start, len);
                throw;
            }
#         endif /* __STL_USE_EXCEPTIONS */
            destroy(start, finish);
            deallocate();
            start = new_start;
            finish = new_finish;
            end_of_storage = new_start + len;
        }
    }
}

#endif /* __STL_MEMBER_TEMPLATES */

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma reset woff 1174
#endif

__STL_END_NAMESPACE 

#endif /* __SGI_STL_INTERNAL_VECTOR_H */

// Local Variables:
// mode:C++
// End:
