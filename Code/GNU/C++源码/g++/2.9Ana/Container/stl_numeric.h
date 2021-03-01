#ifndef __SGI_STL_INTERNAL_NUMERIC_H
#define __SGI_STL_INTERNAL_NUMERIC_H

__STL_BEGIN_NAMESPACE


 // 在其他语言里面, reduce, 传入一个 init 值, 然后进行迭代累加的工作.
template <class InputIterator, class T>
T accumulate(InputIterator first, InputIterator last, T init) {
    for ( ; first != last; ++first)
        init = init + *first;
    return init;
}

// 增加了闭包传入, 增加了扩展性.
// 注意, 这里可以不是闭包, 可以是一个 lambda, 可以是一个 c func, 可以是一个仿函数.
// 只要, 编译的时候, 发现可以进行 () 的调用, 那么就是正确的.
template <class InputIterator, class T, class BinaryOperation>
T accumulate(InputIterator first, InputIterator last, T init,
             BinaryOperation binary_op) {
    for ( ; first != last; ++first)
        init = binary_op(init, *first);
    return init;
}

// product 有着乘积的意思. 这个函数的意思, 就是两个序列, 相同位置乘积的和. 这里, 两个序列, 只给了一个序列的头尾, 第二个序列的长度, 需要调用者保证.
template <class InputIterator1, class InputIterator2, class T>
T inner_product(InputIterator1 first1, InputIterator1 last1,
                InputIterator2 first2, T init) {
    for ( ; first1 != last1; ++first1, ++first2)
        init = init + (*first1 * *first2);
    return init;
}

// inner_product 的可配置版本
template <class InputIterator1, class InputIterator2, class T,
class BinaryOperation1, class BinaryOperation2>
T inner_product(InputIterator1 first1, InputIterator1 last1,
                InputIterator2 first2, T init, BinaryOperation1 binary_op1,
                BinaryOperation2 binary_op2) {
    for ( ; first1 != last1; ++first1, ++first2)
        init = binary_op1(init, binary_op2(*first1, *first2));
    return init;
}



// partial_sum 的入口函数. partial_sum 是累加的意思.
template <class InputIterator, class OutputIterator>
OutputIterator partial_sum(InputIterator first, InputIterator last,
                           OutputIterator result) {
    if (first == last) return result;
    *result = *first;
    return __partial_sum(first, last, result, value_type(first));
}

// partial_sum 的可配置版本入口函数
template <class InputIterator, class OutputIterator, class BinaryOperation>
OutputIterator partial_sum(InputIterator first, InputIterator last,
                           OutputIterator result, BinaryOperation binary_op) {
    if (first == last) return result;
    *result = *first;
    return __partial_sum(first, last, result, value_type(first), binary_op);
}


template <class InputIterator, class OutputIterator, class T>
OutputIterator __partial_sum(InputIterator first, InputIterator last,
                             OutputIterator result, T*) {
    T value = *first;
    while (++first != last) {
        value = value + *first;
        *++result = value;
    }
    return ++result;
}

template <class InputIterator, class OutputIterator, class T,
class BinaryOperation>
OutputIterator __partial_sum(InputIterator first, InputIterator last,
                             OutputIterator result, T*,
                             BinaryOperation binary_op) {
    T value = *first;
    while (++first != last) {
        value = binary_op(value, *first);
        *++result = value;
    }
    return ++result;
}







/*
 序列里面, 相邻元素的差值.
 */
template <class InputIterator, class OutputIterator>
OutputIterator adjacent_difference(InputIterator first, InputIterator last,
                                   OutputIterator result) {
    if (first == last) return result;
    *result = *first;
    return __adjacent_difference(first, last, result, value_type(first));
}

template <class InputIterator, class OutputIterator, class T>
OutputIterator __adjacent_difference(InputIterator first, InputIterator last, 
                                     OutputIterator result, T*) {
    T value = *first;
    while (++first != last) {
        T tmp = *first;
        *++result = tmp - value;
        value = tmp;
    }
    return ++result;
}

/*
 增加了闭包, 进行差值的计算.
 */
template <class InputIterator, class OutputIterator, class T,
class BinaryOperation>
OutputIterator __adjacent_difference(InputIterator first, InputIterator last, 
                                     OutputIterator result, T*,
                                     BinaryOperation binary_op) {
    T value = *first;
    while (++first != last) {
        T tmp = *first;
        *++result = binary_op(tmp, value);
        value = tmp;
    }
    return ++result;
}

template <class InputIterator, class OutputIterator, class BinaryOperation>
OutputIterator adjacent_difference(InputIterator first, InputIterator last,
                                   OutputIterator result,
                                   BinaryOperation binary_op) {
    if (first == last) return result;
    *result = *first;
    return __adjacent_difference(first, last, result, value_type(first),
                                 binary_op);
}

// Returns x ** n, where n >= 0.  Note that "multiplication"
//  is required to be associative, but not necessarily commutative.

template <class T, class Integer, class MonoidOperation>
T power(T x, Integer n, MonoidOperation op) {
    if (n == 0)
        return identity_element(op);
    else {
        // 这里, 为什么不直接判断 == 0 呢.
        while ((n & 1) == 0) {
            n >>= 1;
            x = op(x, x);
        }
        T result = x;
        n >>= 1;
        while (n != 0) {
            x = op(x, x);
            if ((n & 1) != 0)
                result = op(result, x);
            n >>= 1;
        }
        return result;
    }
}

template <class T, class Integer>
inline T power(T x, Integer n) {
    return power(x, n, multiplies<T>());
}


template <class ForwardIterator, class T>
void iota(ForwardIterator first, ForwardIterator last, T value) {
    while (first != last) *first++ = value++;
}

__STL_END_NAMESPACE

#endif /* __SGI_STL_INTERNAL_NUMERIC_H */

// Local Variables:
// mode:C++
// End:
