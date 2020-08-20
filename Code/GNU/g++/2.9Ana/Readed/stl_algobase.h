__STL_BEGIN_NAMESPACE

/*
 迭代器的交换.
 因为迭代器其实就是指针, 所以, 直接就和指针交换一样了.
 迭代器要负起最终的 * 的取值操作, 要返回相对应的引用.
 这里要引起注意, 这里会有拷贝构造函数, 以及赋值构造函数的调用.
 */
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

#ifndef __BORLANDC__

#undef min
#undef max


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

#endif /* __BORLANDC__ */

//Copy

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

/*
 一般的迭代器, 就是遍历赋值操作.
 这里, OutputIterator result 是需要调用者保证有效性的.
 这其实是一个不太好的设计. 这个函数, 应该返回被被复制的位置, 将开辟空间, 已经填充数据的事情, 在函数内部完成.
 还需要在外界进行操作, 这对函数的使用者来说, 有了太多的负担.
 */
template <class InputIterator, class OutputIterator>
inline OutputIterator __copy(InputIterator first, InputIterator last,
                             OutputIterator result, input_iterator_tag)
{
    for ( ; first != last; ++result, ++first)
        *result = *first;
    return result;
}

/*
 随机访问的迭代器, 可以根据距离的类型进行操作.
 */
template <class RandomAccessIterator, class OutputIterator>
inline OutputIterator
__copy(RandomAccessIterator first, RandomAccessIterator last,
       OutputIterator result, random_access_iterator_tag)
{
    return __copy_d(first, last, result, distance_type(first));
}

/*
 对于指针这种距离类型, 可以直接算出次数来.
 次数这种方式, 要比迭代器的判断要快一点.
 */
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

/*
 copy 的 first, last 是一个迭代器, 就利用 category 进行分化.
 */
template <class InputIterator, class OutputIterator>
struct __copy_dispatch
{
    OutputIterator operator()(InputIterator first, InputIterator last,
                              OutputIterator result) {
        return __copy(first, last, result, iterator_category(first));
    }
};

#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION 

/*
 如果, has_trivial_assignment_operator 为 true, 也就是拷贝赋值操作没有特殊设计, 那就直接内存拷贝就可以了.
 */
template <class T>
inline T* __copy_t(const T* first, const T* last, T* result, __true_type) {
    memmove(result, first, sizeof(T) * (last - first));
    return result + (last - first);
}

/*
 如果, has_trivial_assignment_operator 为 false, 也就是拷贝赋值操作有着特殊设计,
 那么就调用迭代器的赋值操作, 会调用到对应类型的拷贝赋值操作.
 */
template <class T>
inline T* __copy_t(const T* first, const T* last, T* result, __false_type) {
    return __copy_d(first, last, result, (ptrdiff_t*) 0);
}

template <class T>
struct __copy_dispatch<T*, T*>
{
    T* operator()(T* first, T* last, T* result) {
        /*
         typeTraits 在这里起了作用.
         */
        typedef typename __type_traits<T>::has_trivial_assignment_operator t;
        return __copy_t(first, last, result, t());
    }
};

template <class T>
struct __copy_dispatch<const T*, T*>
{
    T* operator()(const T* first, const T* last, T* result) {
        typedef typename __type_traits<T>::has_trivial_assignment_operator t;
        return __copy_t(first, last, result, t());
    }
};

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class InputIterator, class OutputIterator>
inline OutputIterator copy(InputIterator first, InputIterator last,
                           OutputIterator result)
{
    // __copy_dispatch 是一个函数对象, 生成这个函数对象之后, 调用这个闭包.
    return __copy_dispatch<InputIterator,OutputIterator>()(first, last, result);
}

/*
 如果迭代器是指针类型的, 就直接内存的拷贝.
 算是做类型的偏特化
 */
inline char* copy(const char* first, const char* last, char* result) {
    memmove(result, first, last - first);
    return result + (last - first);
}
/*
 如果迭代器是指针类型的, 就直接内存的拷贝.
 算是做类型的偏特化
 */
inline wchar_t* copy(const wchar_t* first, const wchar_t* last,
                     wchar_t* result) {
    memmove(result, first, sizeof(wchar_t) * (last - first));
    return result + (last - first);
}

template <class BidirectionalIterator1, class BidirectionalIterator2>
inline BidirectionalIterator2 __copy_backward(BidirectionalIterator1 first, 
                                              BidirectionalIterator1 last,
                                              BidirectionalIterator2 result) {
    while (first != last) *--result = *--last;
    return result;
}


template <class BidirectionalIterator1, class BidirectionalIterator2>
struct __copy_backward_dispatch
{
    BidirectionalIterator2 operator()(BidirectionalIterator1 first,
                                      BidirectionalIterator1 last,
                                      BidirectionalIterator2 result) {
        return __copy_backward(first, last, result);
    }
};

#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION 
/*
 如果迭代器是指针类型的, 就直接内存的拷贝.
 算是做类型的偏特化
 */
template <class T>
inline T* __copy_backward_t(const T* first, const T* last, T* result,
                            __true_type) {
    const ptrdiff_t N = last - first;
    memmove(result - N, first, sizeof(T) * N);
    return result - N;
}
/*
 如果迭代器是指针类型的, 就直接内存的拷贝.
 算是做类型的偏特化
 */
template <class T>
inline T* __copy_backward_t(const T* first, const T* last, T* result,
                            __false_type) {
    return __copy_backward(first, last, result);
}

template <class T>
struct __copy_backward_dispatch<T*, T*>
{
    T* operator()(T* first, T* last, T* result) {
        typedef typename __type_traits<T>::has_trivial_assignment_operator t;
        return __copy_backward_t(first, last, result, t());
    }
};

template <class T>
struct __copy_backward_dispatch<const T*, T*>
{
    T* operator()(const T* first, const T* last, T* result) {
        typedef typename __type_traits<T>::has_trivial_assignment_operator t;
        return __copy_backward_t(first, last, result, t());
    }
};

#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

template <class BidirectionalIterator1, class BidirectionalIterator2>
inline BidirectionalIterator2 copy_backward(BidirectionalIterator1 first, 
                                            BidirectionalIterator1 last,
                                            BidirectionalIterator2 result) {
    return __copy_backward_dispatch<BidirectionalIterator1,
    BidirectionalIterator2>()(first, last,
                              result);
}

/*
 用 N 来决定 forloop 的次数, 要比迭代器的判断要快一点.
 */
template <class InputIterator, class Size, class OutputIterator>
pair<InputIterator, OutputIterator> __copy_n(InputIterator first, Size count,
                                             OutputIterator result,
                                             input_iterator_tag) {
    for ( ; count > 0; --count, ++first, ++result)
        *result = *first;
    return pair<InputIterator, OutputIterator>(first, result);
}

template <class RandomAccessIterator, class Size, class OutputIterator>
inline pair<RandomAccessIterator, OutputIterator>
__copy_n(RandomAccessIterator first, Size count,
         OutputIterator result,
         random_access_iterator_tag) {
    RandomAccessIterator last = first + count;
    return pair<RandomAccessIterator, OutputIterator>(last,
                                                      copy(first, last, result));
}

template <class InputIterator, class Size, class OutputIterator>
inline pair<InputIterator, OutputIterator>
copy_n(InputIterator first, Size count,
       OutputIterator result) {
    return __copy_n(first, count, result, iterator_category(first));
}

//Fill
/*
 从 First 到 last, 都进行 value 的覆盖工作.
 */
template <class ForwardIterator, class T>
void fill(ForwardIterator first, ForwardIterator last, const T& value) {
    for ( ; first != last; ++first)
        *first = value;
}

/*
 从 first 开始, 后面的 n 的位置, 都进行 value 的覆盖工作.
 */
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
// 比较两个序列, 增加了比较的闭包.
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
