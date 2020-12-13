#ifndef __SGI_STL_INTERNAL_ALGO_H
#define __SGI_STL_INTERNAL_ALGO_H

#include <stl_heap.h>

__STL_BEGIN_NAMESPACE


/*
 forEach 这个函数居然有返回值.
 */
template <class InputIterator, class Function>
Function for_each(InputIterator first, InputIterator last, Function f) {
    for ( ; first != last; ++first)
        f(*first);
    return f;
}

// find 协议簇
// 线性查找的函数, 如果, 容器有着自己的 find, 就是利用自己的特性进行查找, 例如 hashTable.
template <class InputIterator, class T>
InputIterator find(InputIterator first, InputIterator last, const T& value) {
    while (first != last && *first != value) ++first;
    return first;
}

template <class InputIterator, class Predicate>
InputIterator find_if(InputIterator first, InputIterator last,
                      Predicate pred) {
    while (first != last && !pred(*first)) ++first;
    return first;
}


// count 函数簇, 分为返回值版本, 和传出参数版本,
template <class InputIterator, class T, class Size>
void count(InputIterator first, InputIterator last, const T& value,
           Size& n) {
    for ( ; first != last; ++first)
        if (*first == value)
            ++n;
}

template <class InputIterator, class Predicate, class Size>
void count_if(InputIterator first, InputIterator last, Predicate pred,
              Size& n) {
    for ( ; first != last; ++first)
        if (pred(*first))
            ++n;
}

template <class InputIterator, class T>
typename iterator_traits<InputIterator>::difference_type
count(InputIterator first, InputIterator last, const T& value) {
    typename iterator_traits<InputIterator>::difference_type n = 0;
    for ( ; first != last; ++first)
        if (*first == value)
            ++n;
    return n;
}

template <class InputIterator, class Predicate>
typename iterator_traits<InputIterator>::difference_type
count_if(InputIterator first, InputIterator last, Predicate pred) {
    typename iterator_traits<InputIterator>::difference_type n = 0;
    for ( ; first != last; ++first)
        if (pred(*first))
            ++n;
    return n;
}


/*
 判断相等, 增加了闭包的自定义化.
 */
template <class ForwardIterator1, class ForwardIterator2,
class BinaryPredicate>
inline ForwardIterator1 search(ForwardIterator1 first1, ForwardIterator1 last1,
                               ForwardIterator2 first2, ForwardIterator2 last2,
                               BinaryPredicate binary_pred) {
    return __search(first1, last1, first2, last2, binary_pred,
                    distance_type(first1), distance_type(first2));
}

/*
 这是指针类型的 iterator, 函数里面直接是指针操作.
 就是判断, 在 1 中, 能不能找到完全和 2 相同的序列. 然后返回在 1 中的位置.
 */

template <class ForwardIterator1, class ForwardIterator2, class Distance1,
class Distance2>
ForwardIterator1 __search(ForwardIterator1 first1, ForwardIterator1 last1,
                          ForwardIterator2 first2, ForwardIterator2 last2,
                          Distance1*, Distance2*) {
    Distance1 d1 = 0;
    distance(first1, last1, d1);
    Distance2 d2 = 0;
    distance(first2, last2, d2);
    
    if (d1 < d2) return last1;
    
    ForwardIterator1 current1 = first1;
    ForwardIterator2 current2 = first2;
    
    /*
     这里, current2 能够动的话一定是 *current1 == *current2, 也就是匹配上了. 也就是说, while 能够退出, 一定是匹配到了最后.
     */
    while (current2 != last2)
        if (*current1 == *current2) {
            ++current1;
            ++current2;
        } else {
            /*
             如果, d1 == d2 了, 头部还是不相等, 那就是找不到了
             */
            if (d1 == d2)
                return last1;
            else {
                /*
                 长序列的头部往后, 短序列的头部重置.
                 */
                current1 = ++first1;
                current2 = first2;
                --d1;
            }
        }
    return first1;
}

template <class ForwardIterator1, class ForwardIterator2>
inline ForwardIterator1 search(ForwardIterator1 first1, ForwardIterator1 last1,
                               ForwardIterator2 first2, ForwardIterator2 last2)
{
    return __search(first1, last1, first2, last2, distance_type(first1),
                    distance_type(first2));
}

/*
 这是迭代器版本的, 里面的逻辑, 基本差不多, 只不过指针相关的操作, 变成了迭代器.
 */
template <class ForwardIterator1, class ForwardIterator2,
class BinaryPredicate, class Distance1, class Distance2>
ForwardIterator1 __search(ForwardIterator1 first1, ForwardIterator1 last1,
                          ForwardIterator2 first2, ForwardIterator2 last2,
                          BinaryPredicate binary_pred, Distance1*, Distance2*) {
    Distance1 d1 = 0;
    distance(first1, last1, d1);
    Distance2 d2 = 0;
    distance(first2, last2, d2);
    
    if (d1 < d2) return last1;
    
    ForwardIterator1 current1 = first1;
    ForwardIterator2 current2 = first2;
    
    while (current2 != last2)
        if (binary_pred(*current1, *current2)) {
            ++current1;
            ++current2;
        }
        else {
            if (d1 == d2)
                return last1;
            else {
                current1 = ++first1;
                current2 = first2;
                --d1;
            }
        }
    return first1;
}

/*
 Searches the range [first, last) for the first sequence of count identical elements, each equal to the given value value.
 要连续相等才可以.
 */
template <class ForwardIterator, class Integer, class T>
ForwardIterator search_n(ForwardIterator first, ForwardIterator last,
                         Integer count, const T& value) {
    if (count <= 0) { return first; }
    
    first = find(first, last, value);
    /*
     先找第一个 value 的值的位置, 然后判断后续的 n 个值是不是都是 value 值, 如果没有达到 n 的条件, 重复寻找.
     */
    while (first != last) {
        Integer n = count - 1;
        ForwardIterator i = first;
        ++i;
        /*
         这里判断了连续相等.
         */
        while (i != last && n != 0 && *i == value) {
            ++i;
            --n;
        }
        if (n == 0)
            return first;
        else
            first = find(i, last, value); // 注意, 这里的 first 的值变成了 i.
    }
    return last;
}

/*
 增加了闭包的传入.
 */
template <class ForwardIterator, class Integer, class T, class BinaryPredicate>
ForwardIterator search_n(ForwardIterator first, ForwardIterator last,
                         Integer count, const T& value,
                         BinaryPredicate binary_pred) {
    if (count <= 0)
        return first;
    else {
        while (first != last) {
            if (binary_pred(*first, value)) break;
            ++first;
        }
        /*
         这里, 没有了 find 函数, 按照最原始的遍历, 寻找第一个符合条件的 iterator 的位置.
         */
        while (first != last) {
            Integer n = count - 1;
            ForwardIterator i = first;
            ++i;
            while (i != last && n != 0 && binary_pred(*i, value)) {
                ++i;
                --n;
            }
            if (n == 0)
                return first;
            else {
                while (i != last) {
                    if (binary_pred(*i, value)) break;
                    ++i;
                }
                first = i;
            }
        }
        return last;
    }
} 


//  Exchanges elements between range [first1, last1) and another range starting at first2.
/*
 这里没有考虑 第二个序列的长度问题, 所以, 调用者有业务保证两个序列的有效性.
 inline void __iter_swap(ForwardIterator1 a, ForwardIterator2 b, T*) {
 T tmp = *a;
 *a = *b;
 *b = tmp;
 }
 iter_swap 的实现如上, 就是最基本的操作. 迭代器
 最朴素的, 原始的 swap range 的写法, 就是一个个的交换.
 */
template <class ForwardIterator1, class ForwardIterator2>
ForwardIterator2 swap_ranges(ForwardIterator1 first1, ForwardIterator1 last1,
                             ForwardIterator2 first2) {
    for ( ; first1 != last1; ++first1, ++first2)
        iter_swap(first1, first2);
    return first2;
}

template <class InputIterator, class OutputIterator, class UnaryOperation>
OutputIterator transform(InputIterator first, InputIterator last,
                         OutputIterator result, UnaryOperation op) {
    for ( ; first != last; ++first, ++result)
        *result = op(*first);
    return result;
}

template <class InputIterator1, class InputIterator2, class OutputIterator,
class BinaryOperation>
OutputIterator transform(InputIterator1 first1, InputIterator1 last1,
                         InputIterator2 first2, OutputIterator result,
                         BinaryOperation binary_op) {
    for ( ; first1 != last1; ++first1, ++first2, ++result)
        *result = binary_op(*first1, *first2);
    return result;
}


// replace 函数簇
template <class ForwardIterator, class T>
void replace(ForwardIterator first, ForwardIterator last, const T& old_value,
             const T& new_value) {
    for ( ; first != last; ++first)
        if (*first == old_value) *first = new_value;
}

template <class ForwardIterator, class Predicate, class T>
void replace_if(ForwardIterator first, ForwardIterator last, Predicate pred,
                const T& new_value) {
    for ( ; first != last; ++first)
        if (pred(*first)) *first = new_value;
}

template <class InputIterator, class OutputIterator, class T>
OutputIterator replace_copy(InputIterator first, InputIterator last,
                            OutputIterator result, const T& old_value,
                            const T& new_value) {
    for ( ; first != last; ++first, ++result)
        *result = *first == old_value ? new_value : *first;
    return result;
}

template <class Iterator, class OutputIterator, class Predicate, class T>
OutputIterator replace_copy_if(Iterator first, Iterator last,
                               OutputIterator result, Predicate pred,
                               const T& new_value) {
    for ( ; first != last; ++first, ++result)
        *result = pred(*first) ? new_value : *first;
    return result;
}

/*
 范围用 gen() 代替原始值.
 */
template <class ForwardIterator, class Generator>
void generate(ForwardIterator first, ForwardIterator last, Generator gen) {
    for ( ; first != last; ++first)
        *first = gen();
}

/*
 范围用 gen() 代替 n 个值.
 */
template <class OutputIterator, class Size, class Generator>
OutputIterator generate_n(OutputIterator first, Size n, Generator gen) {
    for ( ; n > 0; --n, ++first)
        *first = gen();
    return first;
}

/*
 其实就是 fitler.
 */
template <class InputIterator, class OutputIterator, class T>
OutputIterator remove_copy(InputIterator first, InputIterator last,
                           OutputIterator result, const T& value) {
    for ( ; first != last; ++first)
        if (*first != value) {
            *result = *first;
            ++result;
        }
    return result;
}

/*
 filter 的闭包判断实现.
 */
template <class InputIterator, class OutputIterator, class Predicate>
OutputIterator remove_copy_if(InputIterator first, InputIterator last,
                              OutputIterator result, Predicate pred) {
    for ( ; first != last; ++first)
        if (!pred(*first)) {
            *result = *first;
            ++result;
        }
    return result;
}

/*
 只会删除第一个 value node.
 并且其实也不是删除, 要注意, 函数到底应不应该改变原始的值.
 这里, 是略过了第一个 value 值的 node, 拷贝了后面的 序列.
 */
template <class ForwardIterator, class T>
ForwardIterator remove(ForwardIterator first, ForwardIterator last,
                       const T& value) {
    first = find(first, last, value);
    ForwardIterator next = first;
    return first == last ? first : remove_copy(++next, last, first, value);
}

template <class ForwardIterator, class Predicate>
ForwardIterator remove_if(ForwardIterator first, ForwardIterator last,
                          Predicate pred) {
    first = find_if(first, last, pred);
    ForwardIterator next = first;
    return first == last ? first : remove_copy_if(++next, last, first, pred);
}

/*
 翻转.
 */
template <class BidirectionalIterator>
inline void reverse(BidirectionalIterator first, BidirectionalIterator last) {
    __reverse(first, last, iterator_category(first));
}

template <class BidirectionalIterator>
void __reverse(BidirectionalIterator first, BidirectionalIterator last, 
               bidirectional_iterator_tag) {
    while (true)
        if (first == last || first == --last) { return; }
        iter_swap(first++, last);
}

template <class RandomAccessIterator>
void __reverse(RandomAccessIterator first, RandomAccessIterator last,
               random_access_iterator_tag) {
    while (first < last) iter_swap(first++, --last);
}

/*
 reverse_copy 就是从后向前进行复制就可以了.
 */
template <class BidirectionalIterator, class OutputIterator>
OutputIterator reverse_copy(BidirectionalIterator first,
                            BidirectionalIterator last,
                            OutputIterator result) {
    while (first != last) {
        --last;
        *result = *last;
        ++result;
    }
    return result;
}


// rotate 函数簇
template <class ForwardIterator>
inline void rotate(ForwardIterator first, ForwardIterator middle,
                   ForwardIterator last) {
    if (first == middle || middle == last) return;
    __rotate(first, middle, last,
             distance_type(first),
             iterator_category(first));
}

template <class ForwardIterator, class Distance>
void __rotate(ForwardIterator first, ForwardIterator middle,
              ForwardIterator last,
              Distance*,
              forward_iterator_tag) {
    for (ForwardIterator i = middle; ;) {
        iter_swap(first, i);
        ++first;
        ++i;
        if (first == middle) {
            if (i == last) return;
            middle = i;
        }
        else if (i == last)
            i = middle;
    }
}

/*
 双向的, 才能使用 reverse 函数.
 */
template <class BidirectionalIterator, class Distance>
void __rotate(BidirectionalIterator first, BidirectionalIterator middle,
              BidirectionalIterator last, Distance*,
              bidirectional_iterator_tag) {
    reverse(first, middle);
    reverse(middle, last);
    reverse(first, last);
}

template <class RandomAccessIterator, class Distance>
void __random_shuffle(RandomAccessIterator first, RandomAccessIterator last,
                      Distance*) {
    if (first == last) return;
    // 这里, 就是从头到尾的遍历, 然后不断地进行交换.
    for (RandomAccessIterator i = first + 1; i != last; ++i)
        iter_swap(i, first + Distance(rand() % ((i - first) + 1)));
}

template <class RandomAccessIterator>
inline void random_shuffle(RandomAccessIterator first,
                           RandomAccessIterator last) {
    __random_shuffle(first, last, distance_type(first));
}

template <class RandomAccessIterator, class RandomNumberGenerator>
void random_shuffle(RandomAccessIterator first, RandomAccessIterator last,
                    RandomNumberGenerator& rand) {
    if (first == last) return;
    for (RandomAccessIterator i = first + 1; i != last; ++i)
        iter_swap(i, first + rand((i - first) + 1));
}


/*
 10, 10, 10, 20, 20, 20, 30
 如果查找 20 的 lowerBound 的话, 那么就是 3
 如果查找 20 的 upperBound 的话, 那么就是 6
 */

// lowerbound 函数簇.
template <class ForwardIterator, class T>
inline ForwardIterator lower_bound(ForwardIterator first, ForwardIterator last,
                                   const T& value) {
    return __lower_bound(first, last, value, distance_type(first),
                         iterator_category(first));
}

// 可配置闭包版本的 lowerbound
template <class ForwardIterator, class T, class Compare>
inline ForwardIterator lower_bound(ForwardIterator first, ForwardIterator last,
                                   const T& value, Compare comp) {
    return __lower_bound(first, last, value, comp, distance_type(first),
                         iterator_category(first));
}

template <class ForwardIterator, class T, class Distance>
ForwardIterator __lower_bound(ForwardIterator first, ForwardIterator last,
                              const T& value, Distance*,
                              forward_iterator_tag) {
    Distance len = 0;
    distance(first, last, len); // 必须通过 distance 获取长度.
    Distance half;
    ForwardIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first;
        advance(middle, half); // 必须通过 advance 进行指针的改变.
        if (*middle < value) {
            first = middle;
            ++first;
            len = len - half - 1;
        }
        else
            len = half;
    }
    return first;
}

// random 的版本, 直接用操作符就可以获取到长度, 改变指针.
template <class RandomAccessIterator, class T, class Distance>
RandomAccessIterator __lower_bound(RandomAccessIterator first,
                                   RandomAccessIterator last, const T& value,
                                   Distance*, random_access_iterator_tag) {
    Distance len = last - first;
    Distance half;
    RandomAccessIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first + half;
        if (*middle < value) {
            first = middle + 1;
            len = len - half - 1;
        }
        else
            len = half;
    }
    return first;
}

// 带有闭包版本的 lowerbound 实现.
template <class ForwardIterator, class T, class Compare, class Distance>
ForwardIterator __lower_bound(ForwardIterator first, ForwardIterator last,
                              const T& value, Compare comp, Distance*,
                              forward_iterator_tag) {
    Distance len = 0;
    distance(first, last, len);
    Distance half;
    ForwardIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first;
        advance(middle, half);
        if (comp(*middle, value)) {
            first = middle;
            ++first;
            len = len - half - 1;
        }
        else
            len = half;
    }
    return first;
}

template <class RandomAccessIterator, class T, class Compare, class Distance>
RandomAccessIterator __lower_bound(RandomAccessIterator first,
                                   RandomAccessIterator last,
                                   const T& value, Compare comp, Distance*,
                                   random_access_iterator_tag) {
    Distance len = last - first;
    Distance half;
    RandomAccessIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first + half;
        if (comp(*middle, value)) {
            first = middle + 1;
            len = len - half - 1;
        }
        else
            len = half;
    }
    return first;
}


// upper_bound 函数簇.
// 和 lower_bound 同样的思考就可以了
template <class ForwardIterator, class T>
inline ForwardIterator upper_bound(ForwardIterator first, ForwardIterator last,
                                   const T& value) {
    return __upper_bound(first, last, value, distance_type(first),
                         iterator_category(first));
}

template <class ForwardIterator, class T, class Compare>
inline ForwardIterator upper_bound(ForwardIterator first, ForwardIterator last,
                                   const T& value, Compare comp) {
    return __upper_bound(first, last, value, comp, distance_type(first),
                         iterator_category(first));
}

template <class ForwardIterator, class T, class Distance>
ForwardIterator __upper_bound(ForwardIterator first, ForwardIterator last,
                              const T& value, Distance*,
                              forward_iterator_tag) {
    Distance len = 0;
    distance(first, last, len);
    Distance half;
    ForwardIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first;
        advance(middle, half);
        if (value < *middle)
            len = half;
        else {
            first = middle;
            ++first;
            len = len - half - 1;
        }
    }
    return first;
}

template <class RandomAccessIterator, class T, class Distance>
RandomAccessIterator __upper_bound(RandomAccessIterator first,
                                   RandomAccessIterator last, const T& value,
                                   Distance*, random_access_iterator_tag) {
    Distance len = last - first;
    Distance half;
    RandomAccessIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first + half;
        if (value < *middle)
            len = half;
        else {
            first = middle + 1;
            len = len - half - 1;
        }
    }
    return first;
}

template <class ForwardIterator, class T, class Compare, class Distance>
ForwardIterator __upper_bound(ForwardIterator first, ForwardIterator last,
                              const T& value, Compare comp, Distance*,
                              forward_iterator_tag) {
    Distance len = 0;
    distance(first, last, len);
    Distance half;
    ForwardIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first;
        advance(middle, half);
        if (comp(value, *middle))
            len = half;
        else {
            first = middle;
            ++first;
            len = len - half - 1;
        }
    }
    return first;
}

template <class RandomAccessIterator, class T, class Compare, class Distance>
RandomAccessIterator __upper_bound(RandomAccessIterator first,
                                   RandomAccessIterator last,
                                   const T& value, Compare comp, Distance*,
                                   random_access_iterator_tag) {
    Distance len = last - first;
    Distance half;
    RandomAccessIterator middle;
    
    while (len > 0) {
        half = len >> 1;
        middle = first + half;
        if (comp(value, *middle))
            len = half;
        else {
            first = middle + 1;
            len = len - half - 1;
        }
    }
    return first;
}







template <class ForwardIterator, class T, class Distance>
pair<ForwardIterator, ForwardIterator>
__equal_range(ForwardIterator first, ForwardIterator last, const T& value,
              Distance*, forward_iterator_tag) {
    Distance len = 0;
    distance(first, last, len);
    Distance half;
    ForwardIterator middle, left, right;
    
    while (len > 0) {
        half = len >> 1;
        middle = first;
        advance(middle, half);
        if (*middle < value) {
            first = middle;
            ++first;
            len = len - half - 1;
        }
        else if (value < *middle)
            len = half;
        else {
            left = lower_bound(first, middle, value);
            advance(first, len);
            right = upper_bound(++middle, first, value);
            return pair<ForwardIterator, ForwardIterator>(left, right);
        }
    }
    return pair<ForwardIterator, ForwardIterator>(first, first);
}

template <class RandomAccessIterator, class T, class Distance>
pair<RandomAccessIterator, RandomAccessIterator>
__equal_range(RandomAccessIterator first, RandomAccessIterator last,
              const T& value, Distance*, random_access_iterator_tag) {
    Distance len = last - first;
    Distance half;
    RandomAccessIterator middle, left, right;
    
    while (len > 0) {
        half = len >> 1;
        middle = first + half;
        if (*middle < value) {
            first = middle + 1;
            len = len - half - 1;
        }
        else if (value < *middle)
            len = half;
        else {
            left = lower_bound(first, middle, value);
            right = upper_bound(++middle, first + len, value);
            return pair<RandomAccessIterator, RandomAccessIterator>(left,
                                                                    right);
        }
    }
    return pair<RandomAccessIterator, RandomAccessIterator>(first, first);
}

template <class ForwardIterator, class T>
inline pair<ForwardIterator, ForwardIterator>
equal_range(ForwardIterator first, ForwardIterator last, const T& value) {
    return __equal_range(first, last, value, distance_type(first),
                         iterator_category(first));
}

template <class ForwardIterator, class T, class Compare, class Distance>
pair<ForwardIterator, ForwardIterator>
__equal_range(ForwardIterator first, ForwardIterator last, const T& value,
              Compare comp, Distance*, forward_iterator_tag) {
    Distance len = 0;
    distance(first, last, len);
    Distance half;
    ForwardIterator middle, left, right;
    
    while (len > 0) {
        half = len >> 1;
        middle = first;
        advance(middle, half);
        if (comp(*middle, value)) {
            first = middle;
            ++first;
            len = len - half - 1;
        }
        else if (comp(value, *middle))
            len = half;
        else {
            left = lower_bound(first, middle, value, comp);
            advance(first, len);
            right = upper_bound(++middle, first, value, comp);
            return pair<ForwardIterator, ForwardIterator>(left, right);
        }
    }
    return pair<ForwardIterator, ForwardIterator>(first, first);
}

template <class RandomAccessIterator, class T, class Compare, class Distance>
pair<RandomAccessIterator, RandomAccessIterator>
__equal_range(RandomAccessIterator first, RandomAccessIterator last,
              const T& value, Compare comp, Distance*,
              random_access_iterator_tag) {
    Distance len = last - first;
    Distance half;
    RandomAccessIterator middle, left, right;
    
    while (len > 0) {
        half = len >> 1;
        middle = first + half;
        if (comp(*middle, value)) {
            first = middle + 1;
            len = len - half - 1;
        }
        else if (comp(value, *middle))
            len = half;
        else {
            left = lower_bound(first, middle, value, comp);
            right = upper_bound(++middle, first + len, value, comp);
            return pair<RandomAccessIterator, RandomAccessIterator>(left,
                                                                    right);
        }
    }
    return pair<RandomAccessIterator, RandomAccessIterator>(first, first);
}

template <class ForwardIterator, class T, class Compare>
inline pair<ForwardIterator, ForwardIterator>
equal_range(ForwardIterator first, ForwardIterator last, const T& value,
            Compare comp) {
    return __equal_range(first, last, value, comp, distance_type(first),
                         iterator_category(first));
}

template <class ForwardIterator, class T>
bool binary_search(ForwardIterator first, ForwardIterator last,
                   const T& value) {
    ForwardIterator i = lower_bound(first, last, value);
    return i != last && !(value < *i);
}

template <class ForwardIterator, class T, class Compare>
bool binary_search(ForwardIterator first, ForwardIterator last, const T& value,
                   Compare comp) {
    ForwardIterator i = lower_bound(first, last, value, comp);
    return i != last && !comp(value, *i);
}

template <class InputIterator1, class InputIterator2, class OutputIterator>
OutputIterator merge(InputIterator1 first1, InputIterator1 last1,
                     InputIterator2 first2, InputIterator2 last2,
                     OutputIterator result) {
    while (first1 != last1 && first2 != last2) {
        if (*first2 < *first1) {
            *result = *first2;
            ++first2;
        }
        else {
            *result = *first1;
            ++first1;
        }
        ++result;
    }
    return copy(first2, last2, copy(first1, last1, result));
}

template <class InputIterator1, class InputIterator2, class OutputIterator,
class Compare>
OutputIterator merge(InputIterator1 first1, InputIterator1 last1,
                     InputIterator2 first2, InputIterator2 last2,
                     OutputIterator result, Compare comp) {
    while (first1 != last1 && first2 != last2) {
        if (comp(*first2, *first1)) {
            *result = *first2;
            ++first2;
        }
        else {
            *result = *first1;
            ++first1;
        }
        ++result;
    }
    return copy(first2, last2, copy(first1, last1, result));
}

template <class BidirectionalIterator, class Distance>
void __merge_without_buffer(BidirectionalIterator first,
                            BidirectionalIterator middle,
                            BidirectionalIterator last,
                            Distance len1, Distance len2) {
    if (len1 == 0 || len2 == 0) return;
    if (len1 + len2 == 2) {
        // 提前判断, 交换退出, 提高了效率
        if (*middle < *first) iter_swap(first, middle);
        return;
    }
    BidirectionalIterator first_cut = first;
    BidirectionalIterator second_cut = middle;
    Distance len11 = 0;
    Distance len22 = 0;
    if (len1 > len2) {
        len11 = len1 / 2;
        advance(first_cut, len11);
        second_cut = lower_bound(middle, last, *first_cut);
        distance(middle, second_cut, len22);
    } else {
        len22 = len2 / 2;
        advance(second_cut, len22);
        first_cut = upper_bound(first, middle, *second_cut);
        distance(first, first_cut, len11);
    }
    rotate(first_cut, middle, second_cut);
    BidirectionalIterator new_middle = first_cut;
    advance(new_middle, len22);
    __merge_without_buffer(first, first_cut, new_middle, len11, len22);
    __merge_without_buffer(new_middle, second_cut, last, len1 - len11,
                           len2 - len22);
}

template <class BidirectionalIterator, class Distance, class Compare>
void __merge_without_buffer(BidirectionalIterator first,
                            BidirectionalIterator middle,
                            BidirectionalIterator last,
                            Distance len1, Distance len2, Compare comp) {
    if (len1 == 0 || len2 == 0) return;
    if (len1 + len2 == 2) {
        if (comp(*middle, *first)) iter_swap(first, middle);
        return;
    }
    BidirectionalIterator first_cut = first;
    BidirectionalIterator second_cut = middle;
    Distance len11 = 0;
    Distance len22 = 0;
    if (len1 > len2) {
        len11 = len1 / 2;
        advance(first_cut, len11);
        second_cut = lower_bound(middle, last, *first_cut, comp);
        distance(middle, second_cut, len22);
    }
    else {
        len22 = len2 / 2;
        advance(second_cut, len22);
        first_cut = upper_bound(first, middle, *second_cut, comp);
        distance(first, first_cut, len11);
    }
    rotate(first_cut, middle, second_cut);
    BidirectionalIterator new_middle = first_cut;
    advance(new_middle, len22);
    __merge_without_buffer(first, first_cut, new_middle, len11, len22, comp);
    __merge_without_buffer(new_middle, second_cut, last, len1 - len11,
                           len2 - len22, comp);
}

template <class BidirectionalIterator1, class BidirectionalIterator2,
class Distance>
BidirectionalIterator1 __rotate_adaptive(BidirectionalIterator1 first,
                                         BidirectionalIterator1 middle,
                                         BidirectionalIterator1 last,
                                         Distance len1, Distance len2,
                                         BidirectionalIterator2 buffer,
                                         Distance buffer_size) {
    BidirectionalIterator2 buffer_end;
    if (len1 > len2 && len2 <= buffer_size) {
        buffer_end = copy(middle, last, buffer);
        copy_backward(first, middle, last);
        return copy(buffer, buffer_end, first);
    } else if (len1 <= buffer_size) {
        buffer_end = copy(first, middle, buffer);
        copy(middle, last, first);
        return copy_backward(buffer, buffer_end, last);
    } else  {
        rotate(first, middle, last);
        advance(first, len2);
        return first;
    }
}

template <class BidirectionalIterator1, class BidirectionalIterator2,
class BidirectionalIterator3>
BidirectionalIterator3 __merge_backward(BidirectionalIterator1 first1,
                                        BidirectionalIterator1 last1,
                                        BidirectionalIterator2 first2,
                                        BidirectionalIterator2 last2,
                                        BidirectionalIterator3 result) {
    if (first1 == last1) return copy_backward(first2, last2, result);
    if (first2 == last2) return copy_backward(first1, last1, result);
    --last1;
    --last2;
    while (true) {
        if (*last2 < *last1) {
            *--result = *last1;
            if (first1 == last1) return copy_backward(first2, ++last2, result);
            --last1;
        }
        else {
            *--result = *last2;
            if (first2 == last2) return copy_backward(first1, ++last1, result);
            --last2;
        }
    }
}

template <class BidirectionalIterator1, class BidirectionalIterator2,
class BidirectionalIterator3, class Compare>
BidirectionalIterator3 __merge_backward(BidirectionalIterator1 first1,
                                        BidirectionalIterator1 last1,
                                        BidirectionalIterator2 first2,
                                        BidirectionalIterator2 last2,
                                        BidirectionalIterator3 result,
                                        Compare comp) {
    if (first1 == last1) return copy_backward(first2, last2, result);
    if (first2 == last2) return copy_backward(first1, last1, result);
    --last1;
    --last2;
    while (true) {
        if (comp(*last2, *last1)) {
            *--result = *last1;
            if (first1 == last1) return copy_backward(first2, ++last2, result);
            --last1;
        }
        else {
            *--result = *last2;
            if (first2 == last2) return copy_backward(first1, ++last1, result);
            --last2;
        }
    }
}

template <class BidirectionalIterator, class Distance, class Pointer>
void __merge_adaptive(BidirectionalIterator first,
                      BidirectionalIterator middle,
                      BidirectionalIterator last, Distance len1, Distance len2,
                      Pointer buffer, Distance buffer_size) {
    if (len1 <= len2 && len1 <= buffer_size) {
        Pointer end_buffer = copy(first, middle, buffer);
        merge(buffer, end_buffer, middle, last, first);
    }
    else if (len2 <= buffer_size) {
        Pointer end_buffer = copy(middle, last, buffer);
        __merge_backward(first, middle, buffer, end_buffer, last);
    }
    else {
        BidirectionalIterator first_cut = first;
        BidirectionalIterator second_cut = middle;
        Distance len11 = 0;
        Distance len22 = 0;
        if (len1 > len2) {
            len11 = len1 / 2;
            advance(first_cut, len11);
            second_cut = lower_bound(middle, last, *first_cut);
            distance(middle, second_cut, len22);
        }
        else {
            len22 = len2 / 2;
            advance(second_cut, len22);
            first_cut = upper_bound(first, middle, *second_cut);
            distance(first, first_cut, len11);
        }
        BidirectionalIterator new_middle =
        __rotate_adaptive(first_cut, middle, second_cut, len1 - len11,
                          len22, buffer, buffer_size);
        __merge_adaptive(first, first_cut, new_middle, len11, len22, buffer,
                         buffer_size);
        __merge_adaptive(new_middle, second_cut, last, len1 - len11,
                         len2 - len22, buffer, buffer_size);
    }
}

template <class BidirectionalIterator, class Distance, class Pointer,
class Compare>
void __merge_adaptive(BidirectionalIterator first,
                      BidirectionalIterator middle,
                      BidirectionalIterator last, Distance len1, Distance len2,
                      Pointer buffer, Distance buffer_size, Compare comp) {
    if (len1 <= len2 && len1 <= buffer_size) {
        Pointer end_buffer = copy(first, middle, buffer);
        merge(buffer, end_buffer, middle, last, first, comp);
    }
    else if (len2 <= buffer_size) {
        Pointer end_buffer = copy(middle, last, buffer);
        __merge_backward(first, middle, buffer, end_buffer, last, comp);
    }
    else {
        BidirectionalIterator first_cut = first;
        BidirectionalIterator second_cut = middle;
        Distance len11 = 0;
        Distance len22 = 0;
        if (len1 > len2) {
            len11 = len1 / 2;
            advance(first_cut, len11);
            second_cut = lower_bound(middle, last, *first_cut, comp);
            distance(middle, second_cut, len22);
        }
        else {
            len22 = len2 / 2;
            advance(second_cut, len22);
            first_cut = upper_bound(first, middle, *second_cut, comp);
            distance(first, first_cut, len11);
        }
        BidirectionalIterator new_middle =
        __rotate_adaptive(first_cut, middle, second_cut, len1 - len11,
                          len22, buffer, buffer_size);
        __merge_adaptive(first, first_cut, new_middle, len11, len22, buffer,
                         buffer_size, comp);
        __merge_adaptive(new_middle, second_cut, last, len1 - len11,
                         len2 - len22, buffer, buffer_size, comp);
    }
}

template <class BidirectionalIterator, class T, class Distance>
inline void __inplace_merge_aux(BidirectionalIterator first,
                                BidirectionalIterator middle,
                                BidirectionalIterator last, T*, Distance*) {
    Distance len1 = 0;
    distance(first, middle, len1);
    Distance len2 = 0;
    distance(middle, last, len2);
    
    temporary_buffer<BidirectionalIterator, T> buf(first, last);
    if (buf.begin() == 0)
        __merge_without_buffer(first, middle, last, len1, len2);
    else
        __merge_adaptive(first, middle, last, len1, len2,
                         buf.begin(), Distance(buf.size()));
}

template <class BidirectionalIterator, class T, class Distance, class Compare>
inline void __inplace_merge_aux(BidirectionalIterator first,
                                BidirectionalIterator middle,
                                BidirectionalIterator last, T*, Distance*,
                                Compare comp) {
    Distance len1 = 0;
    distance(first, middle, len1);
    Distance len2 = 0;
    distance(middle, last, len2);
    
    temporary_buffer<BidirectionalIterator, T> buf(first, last);
    if (buf.begin() == 0)
        __merge_without_buffer(first, middle, last, len1, len2, comp);
    else
        __merge_adaptive(first, middle, last, len1, len2,
                         buf.begin(), Distance(buf.size()),
                         comp);
}

template <class BidirectionalIterator>
inline void inplace_merge(BidirectionalIterator first,
                          BidirectionalIterator middle,
                          BidirectionalIterator last) {
    if (first == middle || middle == last) return;
    __inplace_merge_aux(first, middle, last, value_type(first),
                        distance_type(first));
}

template <class BidirectionalIterator, class Compare>
inline void inplace_merge(BidirectionalIterator first,
                          BidirectionalIterator middle,
                          BidirectionalIterator last, Compare comp) {
    if (first == middle || middle == last) return;
    __inplace_merge_aux(first, middle, last, value_type(first),
                        distance_type(first), comp);
}

template <class InputIterator1, class InputIterator2>
bool includes(InputIterator1 first1, InputIterator1 last1,
              InputIterator2 first2, InputIterator2 last2) {
    while (first1 != last1 && first2 != last2)
        if (*first2 < *first1)
            return false;
        else if(*first1 < *first2)
            ++first1;
        else
            ++first1, ++first2;
    
    return first2 == last2;
}

template <class InputIterator1, class InputIterator2, class Compare>
bool includes(InputIterator1 first1, InputIterator1 last1,
              InputIterator2 first2, InputIterator2 last2, Compare comp) {
    while (first1 != last1 && first2 != last2)
        if (comp(*first2, *first1))
            return false;
        else if(comp(*first1, *first2))
            ++first1;
        else
            ++first1, ++first2;
    
    return first2 == last2;
}

template <class InputIterator1, class InputIterator2, class OutputIterator>
OutputIterator set_union(InputIterator1 first1, InputIterator1 last1,
                         InputIterator2 first2, InputIterator2 last2,
                         OutputIterator result) {
    while (first1 != last1 && first2 != last2) {
        if (*first1 < *first2) {
            *result = *first1;
            ++first1;
        }
        else if (*first2 < *first1) {
            *result = *first2;
            ++first2;
        }
        else {
            *result = *first1;
            ++first1;
            ++first2;
        }
        ++result;
    }
    return copy(first2, last2, copy(first1, last1, result));
}

template <class InputIterator1, class InputIterator2, class OutputIterator,
class Compare>
OutputIterator set_union(InputIterator1 first1, InputIterator1 last1,
                         InputIterator2 first2, InputIterator2 last2,
                         OutputIterator result, Compare comp) {
    while (first1 != last1 && first2 != last2) {
        if (comp(*first1, *first2)) {
            *result = *first1;
            ++first1;
        }
        else if (comp(*first2, *first1)) {
            *result = *first2;
            ++first2;
        }
        else {
            *result = *first1;
            ++first1;
            ++first2;
        }
        ++result;
    }
    return copy(first2, last2, copy(first1, last1, result));
}

template <class InputIterator1, class InputIterator2, class OutputIterator>
OutputIterator set_intersection(InputIterator1 first1, InputIterator1 last1,
                                InputIterator2 first2, InputIterator2 last2,
                                OutputIterator result) {
    while (first1 != last1 && first2 != last2)
        if (*first1 < *first2)
            ++first1;
        else if (*first2 < *first1)
            ++first2;
        else {
            *result = *first1;
            ++first1;
            ++first2;
            ++result;
        }
    return result;
}

template <class InputIterator1, class InputIterator2, class OutputIterator,
class Compare>
OutputIterator set_intersection(InputIterator1 first1, InputIterator1 last1,
                                InputIterator2 first2, InputIterator2 last2,
                                OutputIterator result, Compare comp) {
    while (first1 != last1 && first2 != last2)
        if (comp(*first1, *first2))
            ++first1;
        else if (comp(*first2, *first1))
            ++first2;
        else {
            *result = *first1;
            ++first1;
            ++first2;
            ++result;
        }
    return result;
}

template <class InputIterator1, class InputIterator2, class OutputIterator>
OutputIterator set_difference(InputIterator1 first1, InputIterator1 last1,
                              InputIterator2 first2, InputIterator2 last2,
                              OutputIterator result) {
    while (first1 != last1 && first2 != last2)
        if (*first1 < *first2) {
            *result = *first1;
            ++first1;
            ++result;
        }
        else if (*first2 < *first1)
            ++first2;
        else {
            ++first1;
            ++first2;
        }
    return copy(first1, last1, result);
}

template <class InputIterator1, class InputIterator2, class OutputIterator,
class Compare>
OutputIterator set_difference(InputIterator1 first1, InputIterator1 last1,
                              InputIterator2 first2, InputIterator2 last2,
                              OutputIterator result, Compare comp) {
    while (first1 != last1 && first2 != last2)
        if (comp(*first1, *first2)) {
            *result = *first1;
            ++first1;
            ++result;
        }
        else if (comp(*first2, *first1))
            ++first2;
        else {
            ++first1;
            ++first2;
        }
    return copy(first1, last1, result);
}

template <class InputIterator1, class InputIterator2, class OutputIterator>
OutputIterator set_symmetric_difference(InputIterator1 first1,
                                        InputIterator1 last1,
                                        InputIterator2 first2,
                                        InputIterator2 last2,
                                        OutputIterator result) {
    while (first1 != last1 && first2 != last2)
        if (*first1 < *first2) {
            *result = *first1;
            ++first1;
            ++result;
        }
        else if (*first2 < *first1) {
            *result = *first2;
            ++first2;
            ++result;
        }
        else {
            ++first1;
            ++first2;
        }
    return copy(first2, last2, copy(first1, last1, result));
}

template <class InputIterator1, class InputIterator2, class OutputIterator,
class Compare>
OutputIterator set_symmetric_difference(InputIterator1 first1,
                                        InputIterator1 last1,
                                        InputIterator2 first2,
                                        InputIterator2 last2,
                                        OutputIterator result, Compare comp) {
    while (first1 != last1 && first2 != last2)
        if (comp(*first1, *first2)) {
            *result = *first1;
            ++first1;
            ++result;
        }
        else if (comp(*first2, *first1)) {
            *result = *first2;
            ++first2;
            ++result;
        }
        else {
            ++first1;
            ++first2;
        }
    return copy(first2, last2, copy(first1, last1, result));
}

template <class ForwardIterator>
ForwardIterator max_element(ForwardIterator first, ForwardIterator last) {
    if (first == last) return first;
    ForwardIterator result = first;
    while (++first != last)
        if (*result < *first) result = first;
    return result;
}

template <class ForwardIterator, class Compare>
ForwardIterator max_element(ForwardIterator first, ForwardIterator last,
                            Compare comp) {
    if (first == last) return first;
    ForwardIterator result = first;
    while (++first != last)
        if (comp(*result, *first)) result = first;
    return result;
}

template <class ForwardIterator>
ForwardIterator min_element(ForwardIterator first, ForwardIterator last) {
    if (first == last) return first;
    ForwardIterator result = first;
    while (++first != last)
        if (*first < *result) result = first;
    return result;
}

template <class ForwardIterator, class Compare>
ForwardIterator min_element(ForwardIterator first, ForwardIterator last,
                            Compare comp) {
    if (first == last) return first;
    ForwardIterator result = first;
    while (++first != last)
        if (comp(*first, *result)) result = first;
    return result;
}

template <class BidirectionalIterator>
bool next_permutation(BidirectionalIterator first,
                      BidirectionalIterator last) {
    if (first == last) return false;
    BidirectionalIterator i = first;
    ++i;
    if (i == last) return false;
    i = last;
    --i;
    
    for(;;) {
        BidirectionalIterator ii = i;
        --i;
        if (*i < *ii) {
            BidirectionalIterator j = last;
            while (!(*i < *--j));
            iter_swap(i, j);
            reverse(ii, last);
            return true;
        }
        if (i == first) {
            reverse(first, last);
            return false;
        }
    }
}

template <class BidirectionalIterator, class Compare>
bool next_permutation(BidirectionalIterator first, BidirectionalIterator last,
                      Compare comp) {
    if (first == last) return false;
    BidirectionalIterator i = first;
    ++i;
    if (i == last) return false;
    i = last;
    --i;
    
    for(;;) {
        BidirectionalIterator ii = i;
        --i;
        if (comp(*i, *ii)) {
            BidirectionalIterator j = last;
            while (!comp(*i, *--j));
            iter_swap(i, j);
            reverse(ii, last);
            return true;
        }
        if (i == first) {
            reverse(first, last);
            return false;
        }
    }
}

template <class BidirectionalIterator>
bool prev_permutation(BidirectionalIterator first,
                      BidirectionalIterator last) {
    if (first == last) return false;
    BidirectionalIterator i = first;
    ++i;
    if (i == last) return false;
    i = last;
    --i;
    
    for(;;) {
        BidirectionalIterator ii = i;
        --i;
        if (*ii < *i) {
            BidirectionalIterator j = last;
            while (!(*--j < *i));
            iter_swap(i, j);
            reverse(ii, last);
            return true;
        }
        if (i == first) {
            reverse(first, last);
            return false;
        }
    }
}

template <class BidirectionalIterator, class Compare>
bool prev_permutation(BidirectionalIterator first, BidirectionalIterator last,
                      Compare comp) {
    if (first == last) return false;
    BidirectionalIterator i = first;
    ++i;
    if (i == last) return false;
    i = last;
    --i;
    
    for(;;) {
        BidirectionalIterator ii = i;
        --i;
        if (comp(*ii, *i)) {
            BidirectionalIterator j = last;
            while (!comp(*--j, *i));
            iter_swap(i, j);
            reverse(ii, last);
            return true;
        }
        if (i == first) {
            reverse(first, last);
            return false;
        }
    }
}

template <class InputIterator, class ForwardIterator>
InputIterator find_first_of(InputIterator first1, InputIterator last1,
                            ForwardIterator first2, ForwardIterator last2)
{
    for ( ; first1 != last1; ++first1)
        for (ForwardIterator iter = first2; iter != last2; ++iter)
            if (*first1 == *iter)
                return first1;
    return last1;
}

template <class InputIterator, class ForwardIterator, class BinaryPredicate>
InputIterator find_first_of(InputIterator first1, InputIterator last1,
                            ForwardIterator first2, ForwardIterator last2,
                            BinaryPredicate comp)
{
    for ( ; first1 != last1; ++first1)
        for (ForwardIterator iter = first2; iter != last2; ++iter)
            if (comp(*first1, *iter))
                return first1;
    return last1;
}


// Search [first2, last2) as a subsequence in [first1, last1).

// find_end for forward iterators.
template <class ForwardIterator1, class ForwardIterator2>
ForwardIterator1 __find_end(ForwardIterator1 first1, ForwardIterator1 last1,
                            ForwardIterator2 first2, ForwardIterator2 last2,
                            forward_iterator_tag, forward_iterator_tag)
{
    if (first2 == last2)
        return last1;
    else {
        ForwardIterator1 result = last1;
        while (1) {
            ForwardIterator1 new_result = search(first1, last1, first2, last2);
            if (new_result == last1)
                return result;
            else {
                result = new_result;
                first1 = new_result;
                ++first1;
            }
        }
    }
}

template <class ForwardIterator1, class ForwardIterator2,
class BinaryPredicate>
ForwardIterator1 __find_end(ForwardIterator1 first1, ForwardIterator1 last1,
                            ForwardIterator2 first2, ForwardIterator2 last2,
                            forward_iterator_tag, forward_iterator_tag,
                            BinaryPredicate comp)
{
    if (first2 == last2)
        return last1;
    else {
        ForwardIterator1 result = last1;
        while (1) {
            ForwardIterator1 new_result = search(first1, last1, first2, last2, comp);
            if (new_result == last1)
                return result;
            else {
                result = new_result;
                first1 = new_result;
                ++first1;
            }
        }
    }
}

// find_end for bidirectional iterators.  Requires partial specialization.
#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION

template <class BidirectionalIterator1, class BidirectionalIterator2>
BidirectionalIterator1
__find_end(BidirectionalIterator1 first1, BidirectionalIterator1 last1,
           BidirectionalIterator2 first2, BidirectionalIterator2 last2,
           bidirectional_iterator_tag, bidirectional_iterator_tag)
{
    typedef reverse_iterator<BidirectionalIterator1> reviter1;
    typedef reverse_iterator<BidirectionalIterator2> reviter2;
    
    reviter1 rlast1(first1);
    reviter2 rlast2(first2);
    reviter1 rresult = search(reviter1(last1), rlast1, reviter2(last2), rlast2);
    
    if (rresult == rlast1)
        return last1;
    else {
        BidirectionalIterator1 result = rresult.base();
        advance(result, -distance(first2, last2));
        return result;
    }
}

template <class BidirectionalIterator1, class BidirectionalIterator2,
class BinaryPredicate>
BidirectionalIterator1
__find_end(BidirectionalIterator1 first1, BidirectionalIterator1 last1,
           BidirectionalIterator2 first2, BidirectionalIterator2 last2,
           bidirectional_iterator_tag, bidirectional_iterator_tag,
           BinaryPredicate comp)
{
    typedef reverse_iterator<BidirectionalIterator1> reviter1;
    typedef reverse_iterator<BidirectionalIterator2> reviter2;
    
    reviter1 rlast1(first1);
    reviter2 rlast2(first2);
    reviter1 rresult = search(reviter1(last1), rlast1, reviter2(last2), rlast2,
                              comp);
    
    if (rresult == rlast1)
        return last1;
    else {
        BidirectionalIterator1 result = rresult.base();
        advance(result, -distance(first2, last2));
        return result;
    }
}
#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */

// Dispatching functions.

template <class ForwardIterator1, class ForwardIterator2>
inline ForwardIterator1
find_end(ForwardIterator1 first1, ForwardIterator1 last1,
         ForwardIterator2 first2, ForwardIterator2 last2)
{
#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION
    typedef typename iterator_traits<ForwardIterator1>::iterator_category
    category1;
    typedef typename iterator_traits<ForwardIterator2>::iterator_category
    category2;
    return __find_end(first1, last1, first2, last2, category1(), category2());
#else /* __STL_CLASS_PARTIAL_SPECIALIZATION */
    return __find_end(first1, last1, first2, last2,
                      forward_iterator_tag(), forward_iterator_tag());
#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */
}

template <class ForwardIterator1, class ForwardIterator2,
class BinaryPredicate>
inline ForwardIterator1
find_end(ForwardIterator1 first1, ForwardIterator1 last1,
         ForwardIterator2 first2, ForwardIterator2 last2,
         BinaryPredicate comp)
{
#ifdef __STL_CLASS_PARTIAL_SPECIALIZATION
    typedef typename iterator_traits<ForwardIterator1>::iterator_category
    category1;
    typedef typename iterator_traits<ForwardIterator2>::iterator_category
    category2;
    return __find_end(first1, last1, first2, last2, category1(), category2(),
                      comp);
#else /* __STL_CLASS_PARTIAL_SPECIALIZATION */
    return __find_end(first1, last1, first2, last2,
                      forward_iterator_tag(), forward_iterator_tag(),
                      comp);
#endif /* __STL_CLASS_PARTIAL_SPECIALIZATION */
}

template <class RandomAccessIterator, class Distance>
bool __is_heap(RandomAccessIterator first, RandomAccessIterator last,
               Distance*)
{
    const Distance n = last - first;
    
    Distance parent = 0;
    for (Distance child = 1; child < n; ++child) {
        if (first[parent] < first[child])
            return false;
        if ((child & 1) == 0)
            ++parent;
    }
    return true;
}

template <class RandomAccessIterator>
inline bool is_heap(RandomAccessIterator first, RandomAccessIterator last)
{
    return __is_heap(first, last, distance_type(first));
}


template <class RandomAccessIterator, class Distance, class StrictWeakOrdering>
bool __is_heap(RandomAccessIterator first, RandomAccessIterator last,
               StrictWeakOrdering comp,
               Distance*)
{
    const Distance n = last - first;
    
    Distance parent = 0;
    for (Distance child = 1; child < n; ++child) {
        if (comp(first[parent], first[child]))
            return false;
        if ((child & 1) == 0)
            ++parent;
    }
    return true;
}

template <class RandomAccessIterator, class StrictWeakOrdering>
inline bool is_heap(RandomAccessIterator first, RandomAccessIterator last,
                    StrictWeakOrdering comp)
{
    return __is_heap(first, last, comp, distance_type(first));
}


template <class ForwardIterator>
bool is_sorted(ForwardIterator first, ForwardIterator last)
{
    if (first == last)
        return true;
    
    ForwardIterator next = first;
    for (++next; next != last; first = next, ++next) {
        if (*next < *first)
            return false;
    }
    
    return true;
}

template <class ForwardIterator, class StrictWeakOrdering>
bool is_sorted(ForwardIterator first, ForwardIterator last,
               StrictWeakOrdering comp)
{
    if (first == last)
        return true;
    
    ForwardIterator next = first;
    for (++next; next != last; first = next, ++next) {
        if (comp(*next, *first))
            return false;
    }
    
    return true;
}
