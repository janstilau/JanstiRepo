__STL_BEGIN_NAMESPACE

#prgma mark - Swap

template <class T>
inline void swap(T& a, T& b) {
    T tmp = a;
    a = b;
    b = tmp;
}

// 不太明白, 这里为什么会有一个萃取的过程.
template <class ForwardIterator1, class ForwardIterator2>
inline void iter_swap(ForwardIterator1 a, ForwardIterator2 b) {
    __iter_swap(a, b, value_type(a));
}

// 就算是传递过来的是迭代器, 使用解引用操作符, 也是可以完成下面的效果的. 因为, 迭代器一定会完成 * 操作符的重载.
template <class ForwardIterator1, class ForwardIterator2, class T>
inline void __iter_swap(ForwardIterator1 a, ForwardIterator2 b, T*) {
    T tmp = *a;
    *a = *b;
    *b = tmp;
}

// 在最新的 STL 里面, 已经增加了接受一个 initialist 参数的版本了.
template <class T>
inline const T& min(const T& a, const T& b) {
    return b < a ? b : a;
}

template <class T>
inline const T& max(const T& a, const T& b) {
    return  a < b ? b : a;
}

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
// 这里的 copy, 是没有拷贝构造函数的调用的. 拷贝构造函数, 只有在 uninitialize_copy 里面, 主动地调用 construct.
template <class InputIterator, class OutputIterator>
inline OutputIterator copy(InputIterator first, InputIterator last,
                           OutputIterator result)
{
    return __copy(first, last, result, iterator_category(first);
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

// 如果是迭代器, 通过迭代器的 * 取值, = 赋值, 到底会不会有 assign 操作符函数的调用, 要看 T 的类型.
template <class InputIterator, class OutputIterator>
inline OutputIterator __copy(InputIterator first, InputIterator last,
                             OutputIterator result,
                             input_iterator_tag)
{
    // 通过 == 操作符来判断, 是否相等
    for ( ; first != last; ++result, ++first)
        *result = *first;
    return result;
}

// 如果是 random 迭代器, 可以通过 distance 事先拿到次数
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
    // 通过次数, 判断是否退出循环.
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

// 不一定指针类型就直接内存操作的, 还是要经过 __type_traits 判断, 是否需要调用赋值操作符的函数.
// copy_backward 的分发器, 指针类型
template <class T>
struct __copy_backward_dispatch<T*, T*>
{
    T* operator()(T* first, T* last, T* result) {
        // 指针类型也需要进行萃取, 到底可不可以直接内存操作, 要看 T 的类型, 而不是指针就可以了.
        // 迭代器就是泛化的指针, 一定要记得这个事情.
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

// copy_backward 的分发器, 迭代器类型.
template <class BidirectionalIterator1, class BidirectionalIterator2>
struct __copy_backward_dispatch
{
    BidirectionalIterator2 operator()(BidirectionalIterator1 first,
                                      BidirectionalIterator1 last,
                                      BidirectionalIterator2 result) {
        return __copy_backward(first, last, result);
    }
};

// 赋值操作符函数不需要调用.
template <class T>
inline T* __copy_backward_t(const T* first, const T* last,
                            T* result,
                            __true_type) {
    const ptrdiff_t N = last - first;
    memmove(result - N, first, sizeof(T) * N);
    return result - N;
}

// 需要调用赋值操作函数的
template <class T>
inline T* __copy_backward_t(const T* first, const T* last,
                            T* result,
                            __false_type) {
    return __copy_backward(first, last, result);
}

// 通过迭代器的 * 运算符取值, 然后进行赋值操作, 这里, 会调用到赋值操作符操作.
// 由于 assign 操作符里面, 经常是会和 CopyCtor 一样的操作, 这里, 搬移会导致巨量的操作.
template <class BidirectionalIterator1, class BidirectionalIterator2>
inline BidirectionalIterator2 __copy_backward(BidirectionalIterator1 first,
                                              BidirectionalIterator1 last,
                                              BidirectionalIterator2 result) {
    while (first != last) *--result = *--last;
    return result;
}

// 只要使用了 *iterator = *iterator. 这种形式, 那么 assign 操作符函数如果定义了, 就一定会被触发.
// 内存 momorymove 这种方式, 只有在 has_trivial_assignment_operator 为 false 的时候才会发生.



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
        *result = *first; // 这里会触发 assign operator 函数.
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
    // 直接计算出 last 的位置, 然后调用 copy 函数
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

#prgma mark - Compare

// 返回第一个不相等的两个序列的迭代器.
template <class InputIterator1, class InputIterator2>
pair<InputIterator1, InputIterator2> mismatch(InputIterator1 first1, InputIterator1 last1,
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

// 就是一个个的比较.
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

// 这里是函数重载, 直接内存比较了.
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
