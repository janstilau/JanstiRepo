#ifndef __SGI_STL_INTERNAL_UNINITIALIZED_H
#define __SGI_STL_INTERNAL_UNINITIALIZED_H

__STL_BEGIN_NAMESPACE

#pragma mark - UninitializedFill

// uninitialized_fill, 从 first 指定的空间开始, 将 x 的值填充到迭代器指向的地方.
// 这个只会在 vector, 和 deque 里面使用, 因为别的容器, 都是一个个的进行安插. 链表, 红黑树, 哈希表, 没有都需要一个个进行. 因为那是节点的概念, 没有办法提前获取到 first, end.
// 需要注意的是, 数组的搬移操作, 是不会调用这个函数的. 因为这个函数, 还要考虑构造函数的调用, 而搬移操作, 不应该调用构造函数.

// 这里, 为什么不能是值的直接 bit copy, 非要进行拷贝构造函数和析构呢. 这其实也是后面 move sematic 出现的原因.
// 在 4.9 的版本里面, 应该就是使用了 move sematic 的拷贝构造函数了.

// 分发函数, 总的入口.
template <class ForwardIterator, class T>
inline void uninitialized_fill(ForwardIterator first,
                               ForwardIterator last,
                               const T& x) {
    __uninitialized_fill(first, last, x, value_type(first));
}

// 萃取过程.
template <class ForwardIterator, class T, class T1>
inline void __uninitialized_fill(ForwardIterator first,
                                 ForwardIterator last,
                                 const T& x,
                                 T1*) {
    typedef typename __type_traits<T1>::is_POD_type is_POD;
    // __type_traits 来判断, 是否应该调用构造函数.
    __uninitialized_fill_aux(first, last, x, is_POD());
    
}

// 不需要构造函数的值, fill 函数的内部, 就是简单地 *left = *right 的实现.
template <class ForwardIterator, class T>
inline void
__uninitialized_fill_aux(ForwardIterator first,
                         ForwardIterator last,
                         const T& x,
                         __true_type)
{
    fill(first, last, x);
}

// 类型值, 必须经过构造函数. 调用 construct 函数.
// 为什么 vector 的扩容会调用构造函数的原因就在这里, 会根据类型, 进行不同的搬移策略.
// 如果, 没有实现 move ctor 的类来说, 还是会到拷贝构造函数. 但是只要这个类, 没有管理额外的资源, 和bits copy 也没有太大的区别.
template <class ForwardIterator, class T>
void
__uninitialized_fill_aux(ForwardIterator first,
                         ForwardIterator last,
                         const T& x,
                         __false_type)
{
    ForwardIterator cur = first;
    __STL_TRY {
        for ( ; cur != last; ++cur)
            construct(&*cur, x);
    }
    __STL_UNWIND(destroy(first, cur));
}


// 分发函数.
template <class ForwardIterator, class Size, class T>
inline ForwardIterator uninitialized_fill_n(ForwardIterator first,
                                            Size n,
                                            const T& x) {
    return __uninitialized_fill_n(first, n, x, value_type(first));
}

// 萃取过程.
template <class ForwardIterator, class Size, class T, class T1>
inline ForwardIterator __uninitialized_fill_n(ForwardIterator first,
                                              Size n,
                                              const T& x,
                                              T1*) {
    typedef typename __type_traits<T1>::is_POD_type is_POD;
    return __uninitialized_fill_n_aux(first, n, x, is_POD());
}


// 不需要构造函数的值, 直接 assignment 填充.
// fill_n 的实现, 就是简单地 *left = *right 而已.
template <class ForwardIterator, class Size, class T>
inline ForwardIterator
__uninitialized_fill_n_aux(ForwardIterator first, Size n,
                           const T& x,
                           __true_type) {
    return fill_n(first, n, x);
}

// 类型值, 必须调用构造函数填充.
template <class ForwardIterator, class Size, class T>
ForwardIterator
__uninitialized_fill_n_aux(ForwardIterator first, Size n,
                           const T& x, __false_type) {
    ForwardIterator cur = first;
    __STL_TRY {
        for ( ; n > 0; --n, ++cur)
            construct(&*cur, x);
        return cur;
    }
    __STL_UNWIND(destroy(first, cur));
}






#pragma mark - UninitializedCopy


// 分发函数. 拷贝 first, 到 last 的内容, 到 result 中去.
template <class InputIterator, class ForwardIterator>
inline ForwardIterator
uninitialized_copy(InputIterator first, InputIterator last,
                   ForwardIterator result) {
    return __uninitialized_copy(first, last, result, value_type(result));
}

// 萃取过程.
template <class InputIterator, class ForwardIterator, class T>
inline ForwardIterator
__uninitialized_copy(InputIterator first, InputIterator last,
                     ForwardIterator result, T*) {
    typedef typename __type_traits<T>::is_POD_type is_POD;
    return __uninitialized_copy_aux(first, last, result, is_POD());
}

// 不需要构造函数的类型, 直接调用 copy. 在 copy 函数里面, 又会判断迭代器的类型: 指针, forward, 还是 random.
template <class InputIterator, class ForwardIterator>
inline ForwardIterator
__uninitialized_copy_aux(InputIterator first, InputIterator last,
                         ForwardIterator result,
                         __true_type) {
    return copy(first, last, result);
}

// 如果需要构造函数, 则在指定的位置, 一个个的调用构造函数
// 这是非常重要的一个点. 复制的时候, 那块资源应不应该调用构造函数, 这不是容器决定的, 而是类型决定的.
template <class InputIterator, class ForwardIterator>
ForwardIterator
__uninitialized_copy_aux(InputIterator first, InputIterator last,
                         ForwardIterator result,
                         __false_type) {
    ForwardIterator cur = result;
    __STL_TRY {
        for ( ; first != last; ++first, ++cur)
            construct(&*cur, *first);
        return cur;
    }
    __STL_UNWIND(destroy(result, cur));
}

// 指针类型的迭代器, 直接内存操作
inline char* uninitialized_copy(const char* first, const char* last,
                                char* result) {
    memmove(result, first, last - first);
    return result + (last - first);
}

// 指针类型的迭代器, 直接内存操作
inline wchar_t* uninitialized_copy(const wchar_t* first, const wchar_t* last,
                                   wchar_t* result) {
    memmove(result, first, sizeof(wchar_t) * (last - first));
    return result + (last - first);
}

// uninitialized_copy_n 分发函数, 萃取.
template <class InputIterator, class Size, class ForwardIterator>
inline pair<InputIterator, ForwardIterator>
uninitialized_copy_n(InputIterator first, Size count,
                     ForwardIterator result) {
    return __uninitialized_copy_n(first, count, result,
                                  iterator_category(first));
}

template <class InputIterator, class Size, class ForwardIterator>
pair<InputIterator, ForwardIterator>
__uninitialized_copy_n(InputIterator first, Size count,
                       ForwardIterator result,
                       input_iterator_tag) {
    ForwardIterator cur = result;
    __STL_TRY {
        for ( ; count > 0 ; --count, ++first, ++cur)
            construct(&*cur, *first);
        return pair<InputIterator, ForwardIterator>(first, cur);
    }
    __STL_UNWIND(destroy(result, cur));
}

template <class RandomAccessIterator, class Size, class ForwardIterator>
inline pair<RandomAccessIterator, ForwardIterator>
__uninitialized_copy_n(RandomAccessIterator first, Size count,
                       ForwardIterator result,
                       random_access_iterator_tag) {
    RandomAccessIterator last = first + count;
    return make_pair(last, uninitialized_copy(first, last, result));
}



// Fills [result, mid) with x, and copies [first, last) into
//  [mid, mid + (last - first)).
template <class ForwardIterator, class T, class InputIterator>
inline ForwardIterator
__uninitialized_fill_copy(ForwardIterator result,
                          ForwardIterator mid,
                          const T& x,
                          InputIterator first,
                          InputIterator last) {
    uninitialized_fill(result, mid, x);
    __STL_TRY {
        return uninitialized_copy(first, last, mid);
    }
    __STL_UNWIND(destroy(result, mid));
}

// Copies [first1, last1) into [first2, first2 + (last1 - first1)), and
//  fills [first2 + (last1 - first1), last2) with x.
template <class InputIterator, class ForwardIterator, class T>
inline void
__uninitialized_copy_fill(InputIterator first1, InputIterator last1,
                          ForwardIterator first2, ForwardIterator last2,
                          const T& x) {
    ForwardIterator mid2 = uninitialized_copy(first1, last1, first2);
    __STL_TRY {
        uninitialized_fill(mid2, last2, x);
    }
    __STL_UNWIND(destroy(first2, mid2));
}





__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_UNINITIALIZED_H */
