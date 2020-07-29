//
//  copy.h
//  2.9Ana
//
//  Created by JustinLau on 2020/7/27.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#ifndef copy_h
#define copy_h

/*
 Searches the range [first, last) for two consecutive identical elements.
 找到第一个相等等值的元素.
 */
template <class ForwardIterator>
ForwardIterator adjacent_find(ForwardIterator first, ForwardIterator last) {
    if (first == last) return last;
    ForwardIterator next = first;
    while(++next != last) {
        if (*first == *next) return first;
        first = next;
    }
    return last;
}

// 判断相等的闭包版本.
template <class ForwardIterator, class BinaryPredicate>
ForwardIterator adjacent_find(ForwardIterator first, ForwardIterator last,
                              BinaryPredicate binary_pred) {
    if (first == last) return last;
    ForwardIterator next = first;
    while(++next != last) {
        if (binary_pred(*first, *next)) return first;
        first = next;
    }
    return last;
}

/*
 unique_copy 只会拷贝相邻不相等的数据. 所以, 传入到这个函数中的序列, 只有排序过, 才能实现 unique 的效果..
 */
template <class InputIterator, class OutputIterator, class BinaryPredicate>
inline OutputIterator unique_copy(InputIterator first, InputIterator last,
                                  OutputIterator result,
                                  BinaryPredicate binary_pred) {
    if (first == last) return result;
    return __unique_copy(first, last, result, binary_pred,
                         iterator_category(result));
}

template <class ForwardIterator>
ForwardIterator unique(ForwardIterator first, ForwardIterator last) {
    first = adjacent_find(first, last);
    return unique_copy(first, last, first);
}

template <class ForwardIterator, class BinaryPredicate>
ForwardIterator unique(ForwardIterator first, ForwardIterator last,
                       BinaryPredicate binary_pred) {
    first = adjacent_find(first, last, binary_pred);
    return unique_copy(first, last, first, binary_pred);
}

/*
 Copies the elements from the range [first, last), to another range beginning at d_first in such a way that there are no consecutive equal elements. Only the first element of each group of equal elements is copied.
 unique copy 不是只拷贝不相同的对象, 而是相等的连续对象只拷贝一份, 不连续的还是会重复.
 */
template <class InputIterator, class OutputIterator>
inline OutputIterator __unique_copy(InputIterator first, InputIterator last,
                                    OutputIterator result, // write only.
                                    output_iterator_tag) {
    return __unique_copy(first, last, result, value_type(first));
}

// forward_iterator_tag 可以进行赋值操作.
template <class InputIterator, class ForwardIterator>
ForwardIterator __unique_copy(InputIterator first, InputIterator last,
                              ForwardIterator result,
                              forward_iterator_tag) {
    *result = *first;
    while (++first != last) // first 已经进行了前进
        if (*result != *first) *++result = *first; // 只有不相等, 才会进行 result 的前进. first 的前进和 result 是不同步的.
    return ++result;
}

// 如果是指针.
template <class InputIterator, class OutputIterator, class T>
OutputIterator __unique_copy(InputIterator first, InputIterator last,
                             OutputIterator result,
                             T*) {
    T value = *first;
    *result = value;
    while (++first != last)
        if (value != *first) {
            value = *first;
            *++result = value;
        }
    return ++result;
}

template <class InputIterator, class OutputIterator>
inline OutputIterator unique_copy(InputIterator first, InputIterator last,
                                  OutputIterator result) {
    if (first == last) return result;
    return __unique_copy(first, last, result, iterator_category(result));
}

template <class InputIterator, class ForwardIterator, class BinaryPredicate>
ForwardIterator __unique_copy(InputIterator first, InputIterator last,
                              ForwardIterator result,
                              BinaryPredicate binary_pred,
                              forward_iterator_tag) {
    *result = *first;
    while (++first != last)
        if (!binary_pred(*result, *first)) *++result = *first;
    return ++result;
}

/*
 增加了闭包的传入.
 */
template <class InputIterator, class OutputIterator, class BinaryPredicate,
class T>
OutputIterator __unique_copy(InputIterator first, InputIterator last,
                             OutputIterator result,
                             BinaryPredicate binary_pred, T*) {
    T value = *first;
    *result = value;
    while (++first != last)
        if (!binary_pred(value, *first)) {
            value = *first;
            *++result = value;
        }
    return ++result;
}

template <class InputIterator, class OutputIterator, class BinaryPredicate>
inline OutputIterator __unique_copy(InputIterator first, InputIterator last,
                                    OutputIterator result,
                                    BinaryPredicate binary_pred,
                                    output_iterator_tag) {
    return __unique_copy(first, last, result, binary_pred, value_type(first));
}

#endif /* copy_h */
