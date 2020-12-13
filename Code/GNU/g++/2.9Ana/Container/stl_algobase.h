__STL_BEGIN_NAMESPACE

#prgma mark - Swap

template <class ForwardIterator1, class ForwardIterator2, class T>
inline void __iter_swap(ForwardIterator1 a, ForwardIterator2 b, T*) {
    T tmp = *a;
    *a = *b;
    *b = tmp;
}

/*
 暴露给用户的, 是不带 __ 的操作. 用 __ 表示私有的函数, 是各种语言通用的做法.
 这个方法, 也是主要用于分发操作. 最后的 value_type, 就是分发的标志位.
 */
template <class ForwardIterator1, class ForwardIterator2>
inline void iter_swap(ForwardIterator1 a, ForwardIterator2 b) {
    __iter_swap(a, b, value_type(a));
}

template <class T>
inline void swap(T& a, T& b) {
    T tmp = a;
    a = b;
    b = tmp;
}

/*
 这都是最简单的算法, 但是是泛型的.
 C++ 的操作符, 和 Swift 的 protocol 相比. 缺少类型限制.
 */
template <class T>
inline const T& min(const T& a, const T& b) {
    return b < a ? b : a;
}

template <class T>
inline const T& max(const T& a, const T& b) {
    return  a < b ? b : a;
}

/*
 增加了比较函数版本的方法.
 */
template <class T, class Compare>
inline const T& min(const T& a, const T& b, Compare comp) {
    return comp(b, a) ? b : a;
}

template <class T, class Compare>
inline const T& max(const T& a, const T& b, Compare comp) {
    return comp(a, b) ? b : a;
}



#prgma mark -  Copy


// copy 入口函数.
template <class InputIterator, class OutputIterator>
inline OutputIterator copy(InputIterator first, InputIterator last,
                           OutputIterator result)
{
    // 分发器生成一个对象, 然后 operation ()调用, 何必如此呢.
    return __copy_dispatch<InputIterator,OutputIterator>()(first, last, result);
}

// 函数重载, 如果是指针, 直接内存操作.
inline char* copy(const char* first, const char* last, char* result) {
    memmove(result, first, last - first);
    return result + (last - first);
}
// 函数重载, 如果是指针, 直接内存操作.
inline wchar_t* copy(const wchar_t* first, const wchar_t* last,
                     wchar_t* result) {
    memmove(result, first, sizeof(wchar_t) * (last - first));
    return result + (last - first);
}

// copy 函数的分发器
template <class InputIterator, class OutputIterator>
struct __copy_dispatch
{
    OutputIterator operator()(InputIterator first, InputIterator last,
                              OutputIterator result) {
        return __copy(first, last, result, iterator_category(first));
    }
};

// 如果是迭代器, 通过迭代器的 * 取值, = 赋值, 通过 == 判断结束条件, 这样比拿到次数判断要慢一点.
template <class InputIterator, class OutputIterator>
inline OutputIterator __copy(InputIterator first, InputIterator last,
                             OutputIterator result,
                             input_iterator_tag)
{
    for ( ; first != last; ++result, ++first)
        *result = *first;
    return result;
}

// 如果是 random 迭代器, 可以通过 distance 事先拿到次数. 通过次数来做赋值, 这样比较快.
template <class RandomAccessIterator, class OutputIterator>
inline OutputIterator
__copy(RandomAccessIterator first, RandomAccessIterator last,
       OutputIterator result,
       random_access_iterator_tag)
{
    return __copy_d(first, last, result, distance_type(first));
}

template <class RandomAccessIterator, class OutputIterator, class Distance>
inline OutputIterator
__copy_d(RandomAccessIterator first,
         RandomAccessIterator last,
         OutputIterator result,
         Distance*)
{
    for (Distance n = last - first; n > 0; --n, ++result, ++first)
        *result = *first;
    return result;
}


#prama mark - CopyBackward

// copy_backward 入口函数
template <class BidirectionalIterator1, class BidirectionalIterator2>
inline BidirectionalIterator2 copy_backward(BidirectionalIterator1 first, 
                                            BidirectionalIterator1 last,
                                            BidirectionalIterator2 result) {
    return __copy_backward_dispatch<BidirectionalIterator1, BidirectionalIterator2>()(first,
                                                                                       last,
                                                                                       result);
}

// copy_backward 的分发器, 指针类型
template <class T>
struct __copy_backward_dispatch<T*, T*>
{
    T* operator()(T* first, T* last, T* result) {
        typedef typename __type_traits<T>::has_trivial_assignment_operator t;
        return __copy_backward_t(first, last, result, t());
    }
};

// copy_backward 的分发器, 指针类型
template <class T>
struct __copy_backward_dispatch<const T*, T*>
{
    T* operator()(const T* first, const T* last, T* result) {
        typedef typename __type_traits<T>::has_trivial_assignment_operator t;
        return __copy_backward_t(first, last, result, t());
    }
};

// 可以直接内存拷贝.
template <class T>
inline T* __copy_backward_t(const T* first, const T* last, T* result,
                            __true_type) {
    const ptrdiff_t N = last - first;
    memmove(result - N, first, sizeof(T) * N);
    return result - N;
}
// 不可以直接内存拷贝.
template <class T>
inline T* __copy_backward_t(const T* first, const T* last, T* result,
                            __false_type) {
    return __copy_backward(first, last, result);
}

// copy_backward 的分发器
template <class BidirectionalIterator1, class BidirectionalIterator2>
struct __copy_backward_dispatch
{
    BidirectionalIterator2 operator()(BidirectionalIterator1 first,
                                      BidirectionalIterator1 last,
                                      BidirectionalIterator2 result) {
        return __copy_backward(first, last, result);
    }
};

// 通过迭代器的 * 运算符取值, 然后进行赋值操作.
template <class BidirectionalIterator1, class BidirectionalIterator2>
inline BidirectionalIterator2 __copy_backward(BidirectionalIterator1 first,
                                              BidirectionalIterator1 last,
                                              BidirectionalIterator2 result) {
    while (first != last) *--result = *--last;
    return result;
}



#prama mark - CopyN

// CopyN 函数的入口, 分发.
template <class InputIterator, class Size, class OutputIterator>
inline pair<InputIterator, OutputIterator>
copy_n(InputIterator first, Size count,
       OutputIterator result) {
    return __copy_n(first, count, result, iterator_category(first));
}

// 普通
template <class InputIterator, class Size, class OutputIterator>
pair<InputIterator, OutputIterator> __copy_n(InputIterator first,
                                             Size count,
                                             OutputIterator result,
                                             input_iterator_tag) {
    for ( ; count > 0; --count, ++first, ++result)
        *result = *first;
    return pair<InputIterator, OutputIterator>(first, result);
}

// random
template <class RandomAccessIterator, class Size, class OutputIterator>
inline pair<RandomAccessIterator, OutputIterator>
__copy_n(RandomAccessIterator first,
         Size count,
         OutputIterator result,
         random_access_iterator_tag) {
    RandomAccessIterator last = first + count;
    return pair<RandomAccessIterator, OutputIterator>(last,
                                                      copy(first, last, result));
}



#prgma mark - Fill

template <class ForwardIterator, class T>
void fill(ForwardIterator first, ForwardIterator last, const T& value) {
    for ( ; first != last; ++first)
        *first = value;
}

template <class OutputIterator, class Size, class T>
OutputIterator fill_n(OutputIterator first, Size n, const T& value) {
    for ( ; n > 0; --n, ++first)
        *first = value;
    return first;
}

// MisMatch

/*
 Returns the first mismatching pair of elements from two ranges: one defined by [first1, last1) and another defined by [first2,last2). If last2 is not provided (overloads (1-4)), it denotes first2 + (last1 - first1).
 
 */
// 返回第一个不相等的两个序列的迭代器.
template <class InputIterator1, class InputIterator2>
pair<InputIterator1, InputIterator2> mismatch(InputIterator1 first1,
                                              InputIterator1 last1,
                                              InputIterator2 first2) {
    while (first1 != last1 && *first1 == *first2) {
        ++first1;
        ++first2;
    }
    return pair<InputIterator1, InputIterator2>(first1, first2);
}
// 增加了比较的函数闭包.
template <class InputIterator1, class InputIterator2, class BinaryPredicate>
pair<InputIterator1, InputIterator2> mismatch(InputIterator1 first1,
                                              InputIterator1 last1,
                                              InputIterator2 first2,
                                              BinaryPredicate binary_pred) {
    while (first1 != last1 && binary_pred(*first1, *first2)) {
        ++first1;
        ++first2;
    }
    return pair<InputIterator1, InputIterator2>(first1, first2);
}

// 比较两个序列
template <class InputIterator1, class InputIterator2>
inline bool equal(InputIterator1 first1, InputIterator1 last1,
                  InputIterator2 first2) {
    for ( ; first1 != last1; ++first1, ++first2)
        if (*first1 != *first2)
            return false;
    return true;
}

template <class InputIterator1, class InputIterator2, class BinaryPredicate>
inline bool equal(InputIterator1 first1, InputIterator1 last1,
                  InputIterator2 first2, BinaryPredicate binary_pred) {
    for ( ; first1 != last1; ++first1, ++first2)
        if (!binary_pred(*first1, *first2))
            return false;
    return true;
}
// lexicographical 这个概念, 就是不同的元素, 从前往后比, 前面的能判断大小, 后面的就不比了.
template <class InputIterator1, class InputIterator2>
bool lexicographical_compare(InputIterator1 first1, InputIterator1 last1,
                             InputIterator2 first2, InputIterator2 last2) {
    for ( ; first1 != last1 && first2 != last2; ++first1, ++first2) {
        if (*first1 < *first2)
            return true;
        if (*first2 < *first1)
            return false;
    }
    return first1 == last1 && first2 != last2;
}
// 增加了比较闭包的自定义.
template <class InputIterator1, class InputIterator2, class Compare>
bool lexicographical_compare(InputIterator1 first1, InputIterator1 last1,
                             InputIterator2 first2, InputIterator2 last2,
                             Compare comp) {
    for ( ; first1 != last1 && first2 != last2; ++first1, ++first2) {
        if (comp(*first1, *first2))
            return true;
        if (comp(*first2, *first1))
            return false;
    }
    return first1 == last1 && first2 != last2;
}


/*
 这种纯内存的, 反而简单了.
 */
inline bool 
lexicographical_compare(const unsigned char* first1,
                        const unsigned char* last1,
                        const unsigned char* first2,
                        const unsigned char* last2)
{
    const size_t len1 = last1 - first1;
    const size_t len2 = last2 - first2;
    const int result = memcmp(first1, first2, min(len1, len2));
    return result != 0 ? result < 0 : len1 < len2;
}

inline bool lexicographical_compare(const char* first1, const char* last1,
                                    const char* first2, const char* last2)
{
    return lexicographical_compare((const signed char*) first1,
                                   (const signed char*) last1,
                                   (const signed char*) first2,
                                   (const signed char*) last2);
}

template <class InputIterator1, class InputIterator2>
int lexicographical_compare_3way(InputIterator1 first1, InputIterator1 last1,
                                 InputIterator2 first2, InputIterator2 last2)
{
    while (first1 != last1 && first2 != last2) {
        if (*first1 < *first2) return -1;
        if (*first2 < *first1) return 1;
        ++first1; ++first2;
    }
    if (first2 == last2) {
        return !(first1 == last1);
    } else {
        return -1;
    }
}

inline int
lexicographical_compare_3way(const unsigned char* first1,
                             const unsigned char* last1,
                             const unsigned char* first2,
                             const unsigned char* last2)
{
    const ptrdiff_t len1 = last1 - first1;
    const ptrdiff_t len2 = last2 - first2;
    const int result = memcmp(first1, first2, min(len1, len2));
    return result != 0 ? result : (len1 == len2 ? 0 : (len1 < len2 ? -1 : 1));
}

inline int lexicographical_compare_3way(const char* first1, const char* last1,
                                        const char* first2, const char* last2)
{
#if CHAR_MAX == SCHAR_MAX
    return lexicographical_compare_3way(
                                        (const signed char*) first1,
                                        (const signed char*) last1,
                                        (const signed char*) first2,
                                        (const signed char*) last2);
#else
    return lexicographical_compare_3way((const unsigned char*) first1,
                                        (const unsigned char*) last1,
                                        (const unsigned char*) first2,
                                        (const unsigned char*) last2);
#endif
}

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_ALGOBASE_H */

// Local Variables:
// mode:C++
// End:
