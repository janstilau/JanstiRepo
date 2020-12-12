#ifndef __SGI_STL_INTERNAL_CONSTRUCT_H
#define __SGI_STL_INTERNAL_CONSTRUCT_H
 
#include <new.h>

__STL_BEGIN_NAMESPACE

// 销毁一段空间, 分发函数. 注意, 这个函数, 不是为了回收空间, 而是为了回收空间中对象所管理的资源.
template <class ForwardIterator>
inline void destroy(ForwardIterator first,
                    ForwardIterator last) {
    __destroy(first, last, value_type(first));
}

// 萃取过程,
template <class ForwardIterator, class T>
inline void __destroy(ForwardIterator first, ForwardIterator last, T*) {
    // 通过 __type_traits 来获取, T 这种类型, 是不是应该调用析构函数.
    typedef typename __type_traits<T>::has_trivial_destructor trivial_destructor;
    __destroy_aux(first, last, trivial_destructor());
}

// 不需要调用析构函数, 什么都不需要做.
template <class ForwardIterator>
inline void __destroy_aux(ForwardIterator, ForwardIterator, __true_type) {}
inline void destroy(char*, char*) {}
inline void destroy(wchar_t*, wchar_t*) {}

// 需要调用析构函数, 一个个的调用 destroy 函数, 而 destroy 函数, 就是调用对应对象的析构函数而已.
template <class ForwardIterator>
inline void
__destroy_aux(ForwardIterator first, ForwardIterator last, __false_type) {
    for ( ; first < last; ++first)
        destroy(&*first);
}

template <class T>
inline void destroy(T* pointer) {
    pointer->~T();
}


// construct 函数, 就是在指定的位置, 调用构造函数而已.
template <class T1, class T2>
inline void construct(T1* p, const T2& value) {
    new (p) T1(value);
}

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_CONSTRUCT_H */

// Local Variables:
// mode:C++
// End:
