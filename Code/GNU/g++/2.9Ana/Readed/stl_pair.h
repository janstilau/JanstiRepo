/* NOTE: This is an internal header file, included by other STL headers.
 *   You should not attempt to use it directly.
 */

#ifndef __SGI_STL_INTERNAL_PAIR_H
#define __SGI_STL_INTERNAL_PAIR_H

__STL_BEGIN_NAMESPACE

/*
 Pair 是一个纯数据类. 里面没有太多的方法.
 从关联式容器我们得知, 其实真正存储的是一个 pair. 在算法里面, 根据 pair 的 first, 也就是 key 进行查找的工作. 根据 pair 的 second, 也就是 second, 进行判断相等的工作.
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
