//
//  sort.h
//  2.9Ana
//
//  Created by 刘国强 on 2020/12/12.
//  Copyright © 2020 JustinLau. All rights reserved.
//


template <class BidirectionalIterator, class Predicate>
BidirectionalIterator partition(BidirectionalIterator first,
                                BidirectionalIterator last, Predicate pred) {
    while (true) {
        while (true) {
            // 该函数返回第二区域的第一位置, 所以每次指针移动, 都进行检查
            if (first == last)
                return first;
            else if (pred(*first)) // 排在前面
                ++first;
            else
                break; // 这个时候, first 已经指向了不排在前面的位置了.
        }
        --last; // 因为 last 是非法区域, 所以这里要进行 --,
        while (true) {
            // 该函数返回第二区域的第一位置, 所以每次指针移动, 都进行检查
            if (first == last)
                return first;
            else if (!pred(*last)) // 排在后面
                --last;
            else
                break; // 这个时候, last 已经指向了不排在后面的位置了.
        }
        iter_swap(first, last); // 置换非法的区域.
        ++first;
    }
}

template <class ForwardIterator, class Predicate, class Distance>
ForwardIterator __inplace_stable_partition(ForwardIterator first,
                                           ForwardIterator last,
                                           Predicate pred, Distance len) {
    if (len == 1) return pred(*first) ? last : first;
    ForwardIterator middle = first;
    advance(middle, len / 2);
    ForwardIterator
    first_cut = __inplace_stable_partition(first, middle, pred, len / 2);
    ForwardIterator
    second_cut = __inplace_stable_partition(middle, last, pred,
                                            len - len / 2);
    rotate(first_cut, middle, second_cut);
    len = 0;
    distance(middle, second_cut, len);
    advance(first_cut, len);
    return first_cut;
}

template <class ForwardIterator, class Pointer, class Predicate,
class Distance>
ForwardIterator __stable_partition_adaptive(ForwardIterator first,
                                            ForwardIterator last,
                                            Predicate pred, Distance len,
                                            Pointer buffer,
                                            Distance buffer_size) {
    if (len <= buffer_size) {
        ForwardIterator result1 = first;
        Pointer result2 = buffer;
        for ( ; first != last ; ++first)
            if (pred(*first)) {
                *result1 = *first;
                ++result1;
            }
            else {
                *result2 = *first;
                ++result2;
            }
        copy(buffer, result2, result1);
        return result1;
    }
    else {
        ForwardIterator middle = first;
        advance(middle, len / 2);
        ForwardIterator first_cut =
        __stable_partition_adaptive(first, middle, pred, len / 2,
                                    buffer, buffer_size);
        ForwardIterator second_cut =
        __stable_partition_adaptive(middle, last, pred, len - len / 2,
                                    buffer, buffer_size);
        
        rotate(first_cut, middle, second_cut);
        len = 0;
        distance(middle, second_cut, len);
        advance(first_cut, len);
        return first_cut;
    }
}

template <class ForwardIterator, class Predicate, class T, class Distance>
inline ForwardIterator __stable_partition_aux(ForwardIterator first,
                                              ForwardIterator last,
                                              Predicate pred, T*, Distance*) {
    temporary_buffer<ForwardIterator, T> buf(first, last);
    if (buf.size() > 0)
        return __stable_partition_adaptive(first, last, pred,
                                           Distance(buf.requested_size()),
                                           buf.begin(), buf.size());
    else
        return __inplace_stable_partition(first, last, pred,
                                          Distance(buf.requested_size()));
}

template <class ForwardIterator, class Predicate>
inline ForwardIterator stable_partition(ForwardIterator first,
                                        ForwardIterator last,
                                        Predicate pred) {
    if (first == last)
        return first;
    else
        return __stable_partition_aux(first, last, pred,
                                      value_type(first), distance_type(first));
}

/*
 数组相关的分区的函数.
 */
template <class RandomAccessIterator, class T>
RandomAccessIterator __unguarded_partition(RandomAccessIterator first,
                                           RandomAccessIterator last,
                                           T pivot) {
    while (true) {
        while (*first < pivot) ++first;
        --last;
        while (pivot < *last) --last;
        if (!(first < last)) return first;
        iter_swap(first, last);
        ++first;
    }
}

template <class RandomAccessIterator, class T, class Compare>
RandomAccessIterator __unguarded_partition(RandomAccessIterator first,
                                           RandomAccessIterator last,
                                           T pivot, Compare comp) {
    while (1) {
        while (comp(*first, pivot)) ++first;
        --last;
        while (comp(pivot, *last)) --last;
        if (!(first < last)) return first;
        iter_swap(first, last);
        ++first;
    }
}

const int __stl_threshold = 16;

/*
 数组线性插入函数.
 从末尾搬移, 直到发现了应该插入的点.
 */
template <class RandomAccessIterator, class T>
void __unguarded_linear_insert(RandomAccessIterator last, T value) {
    RandomAccessIterator next = last;
    --next;
    while (value < *next) {
        *last = *next;
        last = next;
        --next;
    }
    *last = value;
}

/*
 数组线性插入函数, 可配置的闭包表达式.
 */
template <class RandomAccessIterator, class T, class Compare>
void __unguarded_linear_insert(RandomAccessIterator last, T value,
                               Compare comp) {
    RandomAccessIterator next = last;
    --next;
    while (comp(value , *next)) {
        *last = *next;
        last = next;
        --next;
    }
    *last = value;
}

template <class RandomAccessIterator, class T>
inline void __linear_insert(RandomAccessIterator first,
                            RandomAccessIterator last, T*) {
    T value = *last;
    if (value < *first) {
        copy_backward(first, last, last + 1);
        *first = value;
    }
    else
        __unguarded_linear_insert(last, value);
}

template <class RandomAccessIterator, class T, class Compare>
inline void __linear_insert(RandomAccessIterator first,
                            RandomAccessIterator last, T*, Compare comp) {
    T value = *last;
    if (comp(value, *first)) {
        copy_backward(first, last, last + 1);
        *first = value;
    }
    else
        __unguarded_linear_insert(last, value, comp);
}

template <class RandomAccessIterator>
void __insertion_sort(RandomAccessIterator first, RandomAccessIterator last) {
    if (first == last) return;
    for (RandomAccessIterator i = first + 1; i != last; ++i)
        __linear_insert(first, i, value_type(first));
}

template <class RandomAccessIterator, class Compare>
void __insertion_sort(RandomAccessIterator first,
                      RandomAccessIterator last, Compare comp) {
    if (first == last) return;
    for (RandomAccessIterator i = first + 1; i != last; ++i)
        __linear_insert(first, i, value_type(first), comp);
}

template <class RandomAccessIterator, class T>
void __unguarded_insertion_sort_aux(RandomAccessIterator first,
                                    RandomAccessIterator last, T*) {
    for (RandomAccessIterator i = first; i != last; ++i)
        __unguarded_linear_insert(i, T(*i));
}

template <class RandomAccessIterator>
inline void __unguarded_insertion_sort(RandomAccessIterator first,
                                       RandomAccessIterator last) {
    __unguarded_insertion_sort_aux(first, last, value_type(first));
}

template <class RandomAccessIterator, class T, class Compare>
void __unguarded_insertion_sort_aux(RandomAccessIterator first,
                                    RandomAccessIterator last,
                                    T*, Compare comp) {
    for (RandomAccessIterator i = first; i != last; ++i)
        __unguarded_linear_insert(i, T(*i), comp);
}

template <class RandomAccessIterator, class Compare>
inline void __unguarded_insertion_sort(RandomAccessIterator first,
                                       RandomAccessIterator last,
                                       Compare comp) {
    __unguarded_insertion_sort_aux(first, last, value_type(first), comp);
}

template <class RandomAccessIterator>
void __final_insertion_sort(RandomAccessIterator first,
                            RandomAccessIterator last) {
    if (last - first > __stl_threshold) {
        __insertion_sort(first, first + __stl_threshold);
        __unguarded_insertion_sort(first + __stl_threshold, last);
    }
    else
        __insertion_sort(first, last);
}

template <class RandomAccessIterator, class Compare>
void __final_insertion_sort(RandomAccessIterator first,
                            RandomAccessIterator last, Compare comp) {
    if (last - first > __stl_threshold) {
        __insertion_sort(first, first + __stl_threshold, comp);
        __unguarded_insertion_sort(first + __stl_threshold, last, comp);
    }
    else
        __insertion_sort(first, last, comp);
}

// log 方法.
template <class Size>
inline Size __lg(Size n) {
    Size k;
    for (k = 0; n > 1; n >>= 1) ++k;
    return k;
}

template <class RandomAccessIterator, class T, class Size>
void __introsort_loop(RandomAccessIterator first,
                      RandomAccessIterator last, T*,
                      Size depth_limit) {
    while (last - first > __stl_threshold) {
        if (depth_limit == 0) {
            partial_sort(first, last, last);
            return;
        }
        --depth_limit;
        RandomAccessIterator cut = __unguarded_partition
        (first, last, T(__median(*first, *(first + (last - first)/2),
                                 *(last - 1))));
        __introsort_loop(cut, last, value_type(first), depth_limit);
        last = cut;
    }
}

/*
 depth_limit 避免递归嵌套过深.
 STL的sort算法，数据量大，采用Quick Sort，分段递归排序。一旦分段后的数据量小于某个门槛，为避免Quick Sort的递归调用带来过大的额外负荷，就改用Insertion Sort。如果递归层次过深，还会改用Heap Sort。 Introsort，混合式排序算法。其行为在大部分情况下几乎与Quick sort 相同，但当分割行为有恶化为二次行为的倾向时，改用Heap Sort, 使效率维持在O(N log N)，又比一开始就使用heap sort 效果好。
 */
template <class RandomAccessIterator, class T, class Size, class Compare>
void __introsort_loop(RandomAccessIterator first,
                      RandomAccessIterator last, T*,
                      Size depth_limit, Compare comp) {
    while (last - first > __stl_threshold) {
        if (depth_limit == 0) {
            partial_sort(first, last, last, comp);
            return;
        }
        --depth_limit;
        RandomAccessIterator cut = __unguarded_partition
        (first, last, T(__median(*first, *(first + (last - first)/2),
                                 *(last - 1), comp)), comp);
        __introsort_loop(cut, last, value_type(first), depth_limit, comp);
        last = cut;
    }
}

template <class RandomAccessIterator>
inline void sort(RandomAccessIterator first, RandomAccessIterator last) {
    if (first != last) {
        __introsort_loop(first, last, value_type(first), __lg(last - first) * 2);
        __final_insertion_sort(first, last);
    }
}

template <class RandomAccessIterator, class Compare>
inline void sort(RandomAccessIterator first, RandomAccessIterator last,
                 Compare comp) {
    if (first != last) {
        __introsort_loop(first, last, value_type(first), __lg(last - first) * 2,
                         comp);
        __final_insertion_sort(first, last, comp);
    }
}


template <class RandomAccessIterator>
void __inplace_stable_sort(RandomAccessIterator first,
                           RandomAccessIterator last) {
    if (last - first < 15) {
        __insertion_sort(first, last);
        return;
    }
    RandomAccessIterator middle = first + (last - first) / 2;
    __inplace_stable_sort(first, middle);
    __inplace_stable_sort(middle, last);
    __merge_without_buffer(first, middle, last, middle - first, last - middle);
}

/*
 
 */
template <class RandomAccessIterator, class Compare>
void __inplace_stable_sort(RandomAccessIterator first,
                           RandomAccessIterator last, Compare comp) {
    if (last - first < 15) {
        // 在数量比较小的时候, 插入排序.
        __insertion_sort(first, last, comp);
        return;
    }
    // 不断地进行分割.
    RandomAccessIterator middle = first + (last - first) / 2;
    __inplace_stable_sort(first, middle, comp);
    __inplace_stable_sort(middle, last, comp);
    // 进行合并. 这里自己简单的想了一下, 和两条有序链表合并差不多, 源码的有些复杂.
    __merge_without_buffer(first, middle, last, middle - first,
                           last - middle, comp);
}

template <class RandomAccessIterator1, class RandomAccessIterator2,
class Distance>
void __merge_sort_loop(RandomAccessIterator1 first,
                       RandomAccessIterator1 last,
                       RandomAccessIterator2 result, Distance step_size) {
    Distance two_step = 2 * step_size;
    
    while (last - first >= two_step) {
        result = merge(first, first + step_size,
                       first + step_size, first + two_step, result);
        first += two_step;
    }
    
    step_size = min(Distance(last - first), step_size);
    merge(first, first + step_size, first + step_size, last, result);
}

template <class RandomAccessIterator1, class RandomAccessIterator2,
class Distance, class Compare>
void __merge_sort_loop(RandomAccessIterator1 first,
                       RandomAccessIterator1 last,
                       RandomAccessIterator2 result, Distance step_size,
                       Compare comp) {
    Distance two_step = 2 * step_size;
    
    while (last - first >= two_step) {
        result = merge(first, first + step_size,
                       first + step_size, first + two_step, result, comp);
        first += two_step;
    }
    step_size = min(Distance(last - first), step_size);
    
    merge(first, first + step_size, first + step_size, last, result, comp);
}

const int __stl_chunk_size = 7;

template <class RandomAccessIterator, class Distance>
void __chunk_insertion_sort(RandomAccessIterator first,
                            RandomAccessIterator last, Distance chunk_size) {
    while (last - first >= chunk_size) {
        __insertion_sort(first, first + chunk_size);
        first += chunk_size;
    }
    __insertion_sort(first, last);
}

template <class RandomAccessIterator, class Distance, class Compare>
void __chunk_insertion_sort(RandomAccessIterator first,
                            RandomAccessIterator last,
                            Distance chunk_size, Compare comp) {
    while (last - first >= chunk_size) {
        __insertion_sort(first, first + chunk_size, comp);
        first += chunk_size;
    }
    __insertion_sort(first, last, comp);
}

template <class RandomAccessIterator, class Pointer, class Distance>
void __merge_sort_with_buffer(RandomAccessIterator first,
                              RandomAccessIterator last,
                              Pointer buffer, Distance*) {
    Distance len = last - first;
    Pointer buffer_last = buffer + len;
    
    Distance step_size = __stl_chunk_size;
    __chunk_insertion_sort(first, last, step_size);
    
    while (step_size < len) {
        __merge_sort_loop(first, last, buffer, step_size);
        step_size *= 2;
        __merge_sort_loop(buffer, buffer_last, first, step_size);
        step_size *= 2;
    }
}

template <class RandomAccessIterator, class Pointer, class Distance,
class Compare>
void __merge_sort_with_buffer(RandomAccessIterator first,
                              RandomAccessIterator last, Pointer buffer,
                              Distance*, Compare comp) {
    Distance len = last - first;
    Pointer buffer_last = buffer + len;
    
    Distance step_size = __stl_chunk_size;
    __chunk_insertion_sort(first, last, step_size, comp);
    
    while (step_size < len) {
        __merge_sort_loop(first, last, buffer, step_size, comp);
        step_size *= 2;
        __merge_sort_loop(buffer, buffer_last, first, step_size, comp);
        step_size *= 2;
    }
}

template <class RandomAccessIterator, class Pointer, class Distance>
void __stable_sort_adaptive(RandomAccessIterator first,
                            RandomAccessIterator last, Pointer buffer,
                            Distance buffer_size) {
    Distance len = (last - first + 1) / 2;
    RandomAccessIterator middle = first + len;
    if (len > buffer_size) {
        __stable_sort_adaptive(first, middle, buffer, buffer_size);
        __stable_sort_adaptive(middle, last, buffer, buffer_size);
    } else {
        __merge_sort_with_buffer(first, middle, buffer, (Distance*)0);
        __merge_sort_with_buffer(middle, last, buffer, (Distance*)0);
    }
    __merge_adaptive(first, middle, last, Distance(middle - first),
                     Distance(last - middle), buffer, buffer_size);
}

template <class RandomAccessIterator, class Pointer, class Distance,
class Compare>
void __stable_sort_adaptive(RandomAccessIterator first,
                            RandomAccessIterator last, Pointer buffer,
                            Distance buffer_size, Compare comp) {
    Distance len = (last - first + 1) / 2;
    RandomAccessIterator middle = first + len;
    if (len > buffer_size) {
        __stable_sort_adaptive(first, middle, buffer, buffer_size,
                               comp);
        __stable_sort_adaptive(middle, last, buffer, buffer_size,
                               comp);
    } else {
        __merge_sort_with_buffer(first, middle, buffer, (Distance*)0, comp);
        __merge_sort_with_buffer(middle, last, buffer, (Distance*)0, comp);
    }
    __merge_adaptive(first, middle, last, Distance(middle - first),
                     Distance(last - middle), buffer, buffer_size,
                     comp);
}

template <class RandomAccessIterator, class T, class Distance>
inline void __stable_sort_aux(RandomAccessIterator first,
                              RandomAccessIterator last, T*, Distance*) {
    temporary_buffer<RandomAccessIterator, T> buf(first, last);
    if (buf.begin() == 0)
        __inplace_stable_sort(first, last);
    else
        __stable_sort_adaptive(first, last, buf.begin(), Distance(buf.size()));
}

template <class RandomAccessIterator, class T, class Distance, class Compare>
inline void __stable_sort_aux(RandomAccessIterator first,
                              RandomAccessIterator last, T*, Distance*,
                              Compare comp) {
    temporary_buffer<RandomAccessIterator, T> buf(first, last);
    if (buf.begin() == 0)
        __inplace_stable_sort(first, last, comp);
    else
        __stable_sort_adaptive(first, last, buf.begin(), Distance(buf.size()),
                               comp);
}

template <class RandomAccessIterator>
inline void stable_sort(RandomAccessIterator first,
                        RandomAccessIterator last) {
    __stable_sort_aux(first, last, value_type(first), distance_type(first));
}

template <class RandomAccessIterator, class Compare>
inline void stable_sort(RandomAccessIterator first,
                        RandomAccessIterator last, Compare comp) {
    __stable_sort_aux(first, last, value_type(first), distance_type(first),
                      comp);
}

template <class RandomAccessIterator, class T>
void __partial_sort(RandomAccessIterator first, RandomAccessIterator middle,
                    RandomAccessIterator last, T*) {
    make_heap(first, middle);
    for (RandomAccessIterator i = middle; i < last; ++i)
        if (*i < *first)
            __pop_heap(first, middle, i, T(*i), distance_type(first));
    sort_heap(first, middle);
}

template <class RandomAccessIterator>
inline void partial_sort(RandomAccessIterator first,
                         RandomAccessIterator middle,
                         RandomAccessIterator last) {
    __partial_sort(first, middle, last, value_type(first));
}

template <class RandomAccessIterator, class T, class Compare>
void __partial_sort(RandomAccessIterator first, RandomAccessIterator middle,
                    RandomAccessIterator last, T*, Compare comp) {
    make_heap(first, middle, comp);
    for (RandomAccessIterator i = middle; i < last; ++i)
        if (comp(*i, *first))
            __pop_heap(first, middle, i, T(*i), comp, distance_type(first));
    sort_heap(first, middle, comp);
}

template <class RandomAccessIterator, class Compare>
inline void partial_sort(RandomAccessIterator first,
                         RandomAccessIterator middle,
                         RandomAccessIterator last, Compare comp) {
    __partial_sort(first, middle, last, value_type(first), comp);
}

template <class InputIterator, class RandomAccessIterator, class Distance,
class T>
RandomAccessIterator __partial_sort_copy(InputIterator first,
                                         InputIterator last,
                                         RandomAccessIterator result_first,
                                         RandomAccessIterator result_last,
                                         Distance*, T*) {
    if (result_first == result_last) return result_last;
    RandomAccessIterator result_real_last = result_first;
    while(first != last && result_real_last != result_last) {
        *result_real_last = *first;
        ++result_real_last;
        ++first;
    }
    make_heap(result_first, result_real_last);
    while (first != last) {
        if (*first < *result_first)
            __adjust_heap(result_first, Distance(0),
                          Distance(result_real_last - result_first), T(*first));
        ++first;
    }
    sort_heap(result_first, result_real_last);
    return result_real_last;
}

template <class InputIterator, class RandomAccessIterator>
inline RandomAccessIterator
partial_sort_copy(InputIterator first, InputIterator last,
                  RandomAccessIterator result_first,
                  RandomAccessIterator result_last) {
    return __partial_sort_copy(first, last, result_first, result_last,
                               distance_type(result_first), value_type(first));
}

template <class InputIterator, class RandomAccessIterator, class Compare,
class Distance, class T>
RandomAccessIterator __partial_sort_copy(InputIterator first,
                                         InputIterator last,
                                         RandomAccessIterator result_first,
                                         RandomAccessIterator result_last,
                                         Compare comp, Distance*, T*) {
    if (result_first == result_last) return result_last;
    RandomAccessIterator result_real_last = result_first;
    while(first != last && result_real_last != result_last) {
        *result_real_last = *first;
        ++result_real_last;
        ++first;
    }
    make_heap(result_first, result_real_last, comp);
    while (first != last) {
        if (comp(*first, *result_first))
            __adjust_heap(result_first, Distance(0),
                          Distance(result_real_last - result_first), T(*first),
                          comp);
        ++first;
    }
    sort_heap(result_first, result_real_last, comp);
    return result_real_last;
}

template <class InputIterator, class RandomAccessIterator, class Compare>
inline RandomAccessIterator
partial_sort_copy(InputIterator first, InputIterator last,
                  RandomAccessIterator result_first,
                  RandomAccessIterator result_last, Compare comp) {
    return __partial_sort_copy(first, last, result_first, result_last, comp,
                               distance_type(result_first), value_type(first));
}

template <class RandomAccessIterator, class T>
void __nth_element(RandomAccessIterator first, RandomAccessIterator nth,
                   RandomAccessIterator last, T*) {
    while (last - first > 3) {
        RandomAccessIterator cut = __unguarded_partition
        (first, last, T(__median(*first, *(first + (last - first)/2),
                                 *(last - 1))));
        if (cut <= nth)
            first = cut;
        else
            last = cut;
    }
    __insertion_sort(first, last);
}

template <class RandomAccessIterator>
inline void nth_element(RandomAccessIterator first, RandomAccessIterator nth,
                        RandomAccessIterator last) {
    __nth_element(first, nth, last, value_type(first));
}

template <class RandomAccessIterator, class T, class Compare>
void __nth_element(RandomAccessIterator first, RandomAccessIterator nth,
                   RandomAccessIterator last, T*, Compare comp) {
    while (last - first > 3) {
        RandomAccessIterator cut = __unguarded_partition
        (first, last, T(__median(*first, *(first + (last - first)/2),
                                 *(last - 1), comp)), comp);
        if (cut <= nth)
            first = cut;
        else
            last = cut;
    }
    __insertion_sort(first, last, comp);
}

template <class RandomAccessIterator, class Compare>
inline void nth_element(RandomAccessIterator first, RandomAccessIterator nth,
                        RandomAccessIterator last, Compare comp) {
    __nth_element(first, nth, last, value_type(first), comp);
}
