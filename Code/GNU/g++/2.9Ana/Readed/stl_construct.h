#ifndef __SGI_STL_INTERNAL_CONSTRUCT_H
#define __SGI_STL_INTERNAL_CONSTRUCT_H

#include <new.h>

__STL_BEGIN_NAMESPACE

template <class ForwardIterator>
inline void destroy(ForwardIterator first, ForwardIterator last) {
    __destroy(first, last, value_type(first));
}

template <class ForwardIterator, class T>
inline void __destroy(ForwardIterator first, ForwardIterator last, T*) {
    typedef typename __type_traits<T>::has_trivial_destructor trivial_destructor;
    /*
     trivial_destructor 判断, 析构函数是否需要调用.
     */
    __destroy_aux(first, last, trivial_destructor());
}

/*
 如果需要调用各个类型的析构函数, 就调用序列中每个值的析构函数.
 */
template <class ForwardIterator>
inline void
__destroy_aux(ForwardIterator first, ForwardIterator last, __false_type) {
    for ( ; first < last; ++first)
        destroy(&*first);
}

/*
 如果不需要进行析构函数的调用, 就什么都不做.
 */
template <class ForwardIterator>
inline void __destroy_aux(ForwardIterator, ForwardIterator, __true_type) {}

/*
 如果迭代器是char* 指针, 不需要进行析构函数的调用.
 */
inline void destroy(char*, char*) {}
inline void destroy(wchar_t*, wchar_t*) {}

/*
 如果 T 需要调用析构函数, 那么就会到达该方法. 这里, 会调用 T 的析构函数.
 */
template <class T>
inline void destroy(T* pointer) {
    pointer->~T();
}


/*
 在指定的位置, 调用拷贝构造函数.
 这里使用了 new 操作符的特殊设计, 就是传入地址和值, 就在该地址上, 调用 T1 的构造函数, 以 T2 为参数.
 */
template <class T1, class T2>
inline void construct(T1* p, const T2& value) {
    new (p) T1(value);
}

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_CONSTRUCT_H */

// Local Variables:
// mode:C++
// End:
