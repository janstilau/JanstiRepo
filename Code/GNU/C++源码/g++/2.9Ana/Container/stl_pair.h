/* NOTE: This is an internal header file, included by other STL headers.
 *   You should not attempt to use it directly.
 */

#ifndef __SGI_STL_INTERNAL_PAIR_H
#define __SGI_STL_INTERNAL_PAIR_H

__STL_BEGIN_NAMESPACE

/*
 Pair 是一个纯数据类. 里面没有太多的方法.
 在关联式容器里面, 也就是 hash, rbtree 里面, 用的非常多.
 关联式容器的思想, 就是用一个容易查找的值, 来代替复杂的对象的查找工作. 所以, 关联式容器里面的数据, 一般是一个 key 值, 一个 value 值. key 值做容器层面的快速查找, value 值用来做业务逻辑.
 */

template <class T1, class T2>
struct pair {
    typedef T1 first_type;
    typedef T2 second_type;
    
    T1 first;
    T2 second;
    // 默认的构造函数, 就是调用自己的默认的构造函数.
    pair() : first(T1()), second(T2()) {}
    pair(const T1& a, const T2& b) : first(a), second(b) {}
};


// 定义一些常见操作符, 给 Pair. 这些操作符, 会在通用算法里面大量的使用.
template <class T1, class T2>
inline bool operator==(const pair<T1, T2>& x, const pair<T1, T2>& y) { 
    return x.first == y.first && x.second == y.second;
}

template <class T1, class T2>
inline bool operator<(const pair<T1, T2>& x, const pair<T1, T2>& y) { 
    return x.first < y.first || (!(y.first < x.first) && x.second < y.second);
}

template <class T1, class T2>
inline pair<T1, T2> make_pair(const T1& x, const T2& y) {
    return pair<T1, T2>(x, y);
}

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_PAIR_H */

// Local Variables:
// mode:C++
// End:
