#ifndef __SGI_STL_INTERNAL_VECTOR_H
#define __SGI_STL_INTERNAL_VECTOR_H

__STL_BEGIN_NAMESPACE 

template <class T, class Alloc = alloc>
class vector {
public:
    typedef T value_type;
    
    // 对于 Vector 来说, 直接使用的指针, 当做迭代器,
    // 迭代器, 就是漂亮的 pointer, 模拟的就是指针的功能. 最原始的指针, 当然会有着指针的功能了.
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
    //
    
    typedef simple_alloc<value_type, Alloc> data_allocator;
    
    /*
     数据就只有这里.
     */
    iterator start;
    iterator finish;
    iterator end_of_storage;
    
    void deallocate() {
        if (start) data_allocator::deallocate(start, end_of_storage - start);
    }
    
    void fill_initialize(size_type n, const T& value) {
        start = allocate_and_fill(n, value);
        finish = start + n;
        end_of_storage = finish;
    }
    
public:
    /*
     const 是语言, 或者语言和编译器一起合作进行的操作限定. 从内存的角度来说, 没有什么是不能改的. 但是从语法的角度, 用 const 修饰的变量, 就是不应该有写操作.
     就好像, OC 里面, 不可变对象, 没有暴露可变接口一样.
     所以, 实际上, 底层的数据是同一份, 但是表明的类型修饰不一样, 能够达成的操作也就不一样的了.
     */
    iterator begin() { return start; }
    const_iterator begin() const { return start; }
    
    iterator end() { return finish; }
    const_iterator end() const { return finish; }
    
    /*
     直接返回一个迭代器的适配器.
     迭代器, 是一个具有固定接口的数据类型了. 如果一个类, 仅仅使用这些固定接口来实现自己的逻辑, 那么就可以将相关的逻辑移到这个类中.
     适配器就是这样的一个类. 使用存储的原始数据类型, 达成自己的接口目的.
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
     其中增加了对于自动扩容的处理而已.
     */
    size_type size() const { return size_type(end() - begin()); }
    size_type capacity() const { return size_type(end_of_storage - begin()); }
    bool empty() const { return begin() == end(); }
    
    /*
     ref 的好处就在于, 传值和转引用, 写法是一致的. 函数的设计者, 可以选择参数是值, 或者是引用, 来避免赋值, 或者来避免修改.
     函数的接受者, 也可以选择用引用接, 或者用值接.
     所有的这种选择, 代码的写法都一样, 这就是漂亮的 pointer 的体现.
     */
    reference operator[](size_type n) { return *(begin() + n); }
    const_reference operator[](size_type n) const { return *(begin() + n); }
    
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
    
    vector(const_iterator first,
           const_iterator last) {
        size_type n = 0;
        // 使用 distance 算法来确定长度. 因为 vector 是对长度敏感的, 算出长度来, 才能进行分配工作.
        distance(first, last, n);
        start = allocate_and_copy(n, first, last);
        finish = start + n;
        end_of_storage = finish;
    }
    
    ~vector() {
        destroy(start, finish); // 回收各元素所管理的资源.
        deallocate(); // 回收所占用空间.
    }
    vector<T, Alloc>& operator=(const vector<T, Alloc>& x);
    // 如果现在容量更大, 什么都不做
    // 如果现在容量小, 则分配更大的, 进行拷贝. 然后销毁原来的.
    void reserve(size_type n) {
        if (capacity() < n) {
            const size_type old_size = size();
            
            // 这里, 会有大量的构造和析构的发生.
            // 在 swift 里面, struct 没有了这么复杂的设计. 拷贝, 就是 bit 位的拷贝, 不会掺杂着容器内各个元素的资源管理了.
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
    
    void push_back(const T& x) {
        if (finish != end_of_storage) {
            construct(finish, x); // 主动在相应的位置, 调用构造函数.
            // 之前就一直在想, 是不是先在某个地方调用构造函数之后, 然后 bit 位的拷贝到数组管理的空间里.
            // 现在看来, 是直接在数组管理的空间上, 调用构造函数.
            ++finish;
        } else {
            insert_aux(end(), x);
        }
    }
    
    void swap(vector<T, Alloc>& x) {
        __STD::swap(start, x.start);
        __STD::swap(finish, x.finish);
        __STD::swap(end_of_storage, x.end_of_storage);
    }
    
    iterator insert(iterator position, const T& x) {
        size_type n = position - begin();
        if (finish != end_of_storage && position == end()) {
            construct(finish, x); // 主动在相应的位置, 调用构造函数.
            ++finish;
        } else {
            insert_aux(position, x);
        }
        return begin() + n;
    }
    template <class InputIterator>
    void insert(iterator position, InputIterator first, InputIterator last) {
        range_insert(position, first, last, iterator_category(first));
    }
    
    void insert (iterator pos, size_type n, const T& x);
    void insert (iterator pos, int n, const T& x) {
        insert(pos, (size_type) n, x);
    }
    void insert (iterator pos, long n, const T& x) {
        insert(pos, (size_type) n, x);
    }
    
    void pop_back() {
        --finish;
        destroy(finish); // 主动在相应的位置, 调用析构函数.
    }
    
    // copy 不会触发构造函数的调用.
    // 只有 uninitialized_copy 才会触发.
    iterator erase(iterator position) {
        if (position + 1 != end()) {
            copy(position + 1, finish, position);
        }
        --finish;
        destroy(finish);
        return position;
    }
    /*
     删除一段空间. 后面的数据没有清除, 仅仅是标志位改变了.
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
    void resize(size_type new_size,
                const T& x) {
        if (new_size < size())
            erase(begin() + new_size, end());
        else
            insert(end(), new_size - size(), x);
    }
    void resize(size_type new_size) { resize(new_size, T()); }
    void clear() { erase(begin(), end()); }
    
protected:
    // 新分配一段空间, 然后把 x 填充到这个空间上.
    iterator allocate_and_fill(size_type n, const T& x) {
        // 分配数据, 是分配器的工作.
        iterator result = data_allocator::allocate(n);
        __STL_TRY {
            // 填充数据, 这是泛型算法的工作.
            uninitialized_fill_n(result, n, x);
            return result;
        }
        __STL_UNWIND(data_allocator::deallocate(result, n));
    }
    
    // 新分配一段空间, 然后把 first 到 last 的内容, 填充到这个空间上.
    template <class ForwardIterator>
    iterator allocate_and_copy(size_type n,
                               ForwardIterator first,
                               ForwardIterator last) {
        // 首先, 申请空间.
        iterator result = data_allocator::allocate(n);
        __STL_TRY {
            // 然后, 把原有内容, 填充到这个空间上.
            uninitialized_copy(first, last, result);
            return result;
        }
        __STL_UNWIND(data_allocator::deallocate(result, n));
    }
    
    
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
        const size_type len = old_size != 0 ? 2 * old_size : 1; // 计算出新的大小.
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

#else /* __STL_MEMBER_TEMPLATES */

// 插入一段数据到 position 这个位置.
template <class T, class Alloc>
void vector<T, Alloc>::insert(iterator position, 
                              const_iterator first,
                              const_iterator last) {
    if (first == last) { return; }
        
    size_type n = 0;
    distance(first, last, n);
    if (size_type(end_of_storage - finish) >= n) {
        // 还有足够的空间.
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
        // 如果空间不够了, 就新分配, 然后三段式的复制.
        const size_type old_size = size();
        const size_type len = old_size + max(old_size, n);
        iterator new_start = data_allocator::allocate(len);
        iterator new_finish = new_start;
        new_finish = uninitialized_copy(start, position, new_start);
        new_finish = uninitialized_copy(first, last, new_finish);
        new_finish = uninitialized_copy(position, finish, new_finish);
        // 然后把原有的控件资源回收, 内存回收.
        destroy(start, finish);
        deallocate();
        start = new_start;
        finish = new_finish;
        end_of_storage = new_start + len;
    }
}

#endif /* __STL_MEMBER_TEMPLATES */

#if defined(__sgi) && !defined(__GNUC__) && (_MIPS_SIM != _MIPS_SIM_ABI32)
#pragma reset woff 1174
#endif

__STL_END_NAMESPACE 

#endif /* __SGI_STL_INTERNAL_VECTOR_H */
