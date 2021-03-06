//
//  main.cpp
//  Sort3
//
//  Created by JustinLau on 2019/3/10.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

/*
 桶排序
 
 桶排序的例子在大话算法里面有提到, 有着有限的区间的对象, 于是开辟了最大值那么多个桶, 然后将这些对象按照自己的值放到桶里面, 最后遍历一遍桶就能拿到最终的结果.
 桶排序的条件比较苛刻, 待排序的对象的范围, 应该尽可能的分散, 这样每一个桶里面的对象就不会太多. 桶内可以用任何的办法进行排序, 在最终合并的时候, 桶内的元素是有序的, 桶之间的元素是有序的. 所以, 最终结果也是有序的.
 如果桶的个数, 能够和元素的个数尽可能相等, 元素又尽可能的分散, 那么 On 的时间复杂度.
 桶排序还是用空间换时间的思想, 桶作为一个有序的概念, 存放在物理内存上, 然后数据根据比较的条件, 放到不同的桶里, 这个放置的过程, 本身就是排序的过程.
 外部排序, 就是使用桶排序的思想.
 
 基数排序.
 
 基数排序对要排序的数据是有要求的，需要可以分割出独立的“位”来比较，而且位 之间有递进的关系，如果 a 数据的高位比 b 数据大，那剩下的低位就不用比较了。除此之外，每一 位的数据范围不能太大，要可以用线性排序算法来排序，否则，基数排序的时间复杂度就无法做到On
 
 基数排序的典型代表就是手机号码. 首先, 对低阶位号码排序, 最后一位, 然后, 对倒数第二位进行排序. 因为倒数第二位的判断优先于第一位, 所以, 倒数第二位小的靠前. 那倒数第二位相等的呢, 应该用倒数第一位的判断标准, 而这个结果, 我们之前已经用过了, 所以这个时候, 如果算法是稳定的排序算法, 倒数第二位如果相同, 还保持着原来的顺序, 这个时候, 每一位的价值都能够进行保留, 而高阶的位排序的时候, 高阶大小不一样, 用高阶排序, 高阶大小一样, 之前低阶的位的运算结果还能保留.
 这里发现了之前的一个理解问题, 就是用户排序那, 如果想 优先年龄排序, 然后是分数. 那么首先应该按照分数排序, 然后在按照年龄排序, 最主要的排序标准, 一定要在最后排序, 并且, 这两个排序标准要互相独立, 不能有联系.
 
 在数据量不是很大的时候, 用 n*n 的排序算法, 不一定要比 nlogn 的慢, 因为时间复杂度其实是省略了常量系数了, 而时间复杂度, 更多的表示的是当数据量增大的时候, 代码所需要的时间的增长曲线. 在数据量比较小的时候, n2的操作不一定要比 nlogn 的大, 而且, 如果乘以原来的省略的常量系数, 还可能小. 所以, 每种排序算法, 其实都是有用的.
 
 */

void mergeSort(int *origin, int length, int capacity,
               int* target, int targertLength) {
    if (length + targertLength < capacity) { return; }
    int originIndex = length - 1;
    int targetIndex = targertLength - 1;
    int mergedIndex = length + targertLength - 1;
    while (originIndex > 0 && targertLength > 0) {
        if (origin[originIndex] >= target[targertLength]) {
            origin[mergedIndex] = origin[originIndex];
            originIndex -= 1;
        } else {
            origin[mergedIndex] = target[targetIndex];
            targetIndex -= 1;
        }
        mergedIndex -= 1;
    }
    if (targetIndex) {
        while (mergedIndex) {
            origin[mergedIndex--] = target[targetIndex--];
        }
    }
}

int main(int argc, const char * argv[]) {
    // insert code here...
    std::cout << "Hello, World!\n";
    return 0;
}
