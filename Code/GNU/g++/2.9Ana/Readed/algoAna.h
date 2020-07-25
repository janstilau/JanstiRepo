//
//  algoAna.h
//  2.9Ana
//
//  Created by JustinLau on 2020/7/23.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#ifndef algoAna_h
#define algoAna_h
/*
 for_each 迭代处理, 传入闭包, 各个语言的 foreach 的 C++ 实现.
 
 find 顺序查找, On 复杂度, find_if可以自定义相等判断闭包.
 
 adjacent_find 毗邻查找, 如果相邻相等返回第一个位置. 可以传入闭包, 自定义相等判断逻辑.
 
 int count(InputIterator first, InputIterator last, const T& value), count_if 判断迭代范围里面, 有多少个 value. if 传入判断逻辑.
 
 inline ForwardIterator1 search(ForwardIterator1 first1, ForwardIterator1 last1,
 ForwardIterator2 first2, ForwardIterator2 last2)
 在 第一个序列中, 查找第二个序列, 返回第一个序列的位置. 如果查找不到, 返回 last1.
 
 ForwardIterator search_n(ForwardIterator first, ForwardIterator last,
 Integer count, const T& value) 在序列中, 寻找连续 N 个 value 出现的位置. 如果没有, 返回 last. 该函数可以传入相等判断闭包.
 
 ForwardIterator2 swap_ranges(ForwardIterator1 first1, ForwardIterator1 last1,
 ForwardIterator2 first2) 将第一个序列里面的片段里面的内容, 用第二序列里面进行替换. 使用者要保证不出序列的长度有效.
 
 OutputIterator transform(InputIterator first, InputIterator last,
 OutputIterator result, UnaryOperation op) 类似于 map 函数, 不过需要体现开辟内存空间给 result.
 
 void replace(ForwardIterator first, ForwardIterator last, const T& old_value,
 const T& new_value), 和 replace_if, 将范围内的内容中, old_value 的节点, 替换为 new_value 的内容.
 
 OutputIterator replace_copy(InputIterator first, InputIterator last,
 OutputIterator result, const T& old_value,
 const T& new_value), replace_copy_if, 将范围内的内容, 复制到 result 中去, 如果原始内容为 old_value, 则替换为 new_value.
 
 generate(ForwardIterator first, ForwardIterator last, Generator gen), 将范围内的内容, 通过 gen() 来替换.
 generate_n(OutputIterator first, Size n, Generator gen) 将固定范围的内容, 通过 gen() 来替换.
 
 remove_copy(InputIterator first, InputIterator last,
 OutputIterator result, const T& value) 将范围内中, 不是 value 的节点, 拷贝到 result 所在的序列里面.
 remove_copy_if 增加了判断相等的闭包传入.
 
 unique_copy(InputIterator first, InputIterator last,
 OutputIterator result,
 BinaryPredicate binary_pred) 拷贝非连续重复的资源到 result 中, 加入了判断相等的闭包的传入.
 
 reverse(BidirectionalIterator first, BidirectionalIterator last) 翻转序列.
 
 OutputIterator reverse_copy(BidirectionalIterator first,
 BidirectionalIterator last,
 OutputIterator result) 翻转存储到 result 中去.
 
 random_shuffle(RandomAccessIterator first,
 RandomAccessIterator last) 重新洗牌, 不断地随机交换.
 
 
 
 */

#endif /* algoAna_h */
