#ifndef __SGI_STL_INTERNAL_CONSTRUCT_H
#define __SGI_STL_INTERNAL_CONSTRUCT_H
 
#include <new.h>

__STL_BEGIN_NAMESPACE

// 销毁, 是为了回收迭代器所指向的对象, 管理的资源, 而不是迭代器指向的资源
// destory 的入口函数.
template <class ForwardIterator>
inline void destroy(ForwardIterator first,
                    ForwardIterator last) {
    __destroy(first, last, value_type(first));
}

// 萃取过程, 使用了 __type_traits 来获取, 是否需要调用析构函数.
template <class ForwardIterator, class T>
inline void __destroy(ForwardIterator first, ForwardIterator last, T*) {
    // 通过 __type_traits 来获取, T 这种类型, 是不是应该调用析构函数.
    typedef typename __type_traits<T>::has_trivial_destructor trivial_destructor;
    __destroy_aux(first, last, trivial_destructor());
}

// 不需要调用析构函数, 什么都不需要做.
template <class ForwardIterator>
inline void __destroy_aux(ForwardIterator, ForwardIterator, __true_type) {}
// 这里是函数重载, 如果是裸指针, 根本不需要回收指向的资源.
inline void destroy(char*, char*) {}
inline void destroy(wchar_t*, wchar_t*) {}

// 需要专门回收, 迭代器所指向的资源.
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
