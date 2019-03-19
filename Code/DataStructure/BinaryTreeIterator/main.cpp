//
//  main.cpp
//  BinaryTreeInArray
//
//  Created by JustinLau on 2019/3/12.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

struct BTNode {
    char data;
    struct BTNode *lChild;
    struct BTNode *rChild;
};

typedef struct BTNode BTNode;

/*
 写出自己模拟的栈来代替系统调用产生的栈, 这就是写出非递归实现的二叉树遍历的基本思路.
 */

const int kMaxSize = 10000;

void visit(struct BTNode *root) {}


// 先自己, 入栈右, 入栈左, 出栈
void preOrder(BTNode *root) {
    if (!root) { return; }
    BTNode *Stack[kMaxSize];
    int top = 0;
    Stack[top++] = root;
    while (top != 0) {
        BTNode *current = Stack[--top];
        visit(current);
        if (current->rChild) {
            Stack[top++] = current->rChild;
        }
        if (current->lChild) {
            Stack[top++] = current->lChild;
        }
    }
}

void midOrder(BTNode *root) {
    if (!root) { return; }
    BTNode *Stack[kMaxSize];
    int top = 0;
    BTNode *current = root;
    if (current->lChild) {
        Stack[top++] = current->lChild;
    } else {
        Stack[top++] = current;
    }
    
    while (top != 0) {
        while (current->lChild) {// 一直入左节点
            Stack[top++] = current->lChild;
            current = current->lChild;
        }
        current = Stack[--top]; // 访问自己
        visit(current);
        if (current->rChild) { // 入右节点.
            Stack[top++] = current->rChild;
            current = current->rChild;
        }
    }
    
}


int maxW = -1000000; //存储背包中物品总重量的最大值
// cw表示当前已经装进去的物品的重量和;i表示考察到哪个物品了;
// w背包重量;items表示每个物品的重量;n表示物品个数
// 假设背包可承受重量100，物品个数10，物品重量存储在数组a中，那可以这样调用函数:
// f(0, 0, a, 10, 100)
void f(int index, int weighTotal, int items[], int itemCount, int weightMax) {
    if (weighTotal == weightMax || index == itemCount) { // cw==w表示装满了;i==n表示已经考察完所有的物品 if (cw > maxW) maxW = cw;
        if (weighTotal > maxW) {
            maxW = weighTotal;
        }
        return;
    }
    f(index+1, weighTotal, items, itemCount, weightMax);
    if (weighTotal + items[index] <= weightMax) {// 已经超过可以背包承受的重量的时候，就不要再装了 }}f(i
        f(index+1, weighTotal+items[index], items, itemCount, weightMax);;
    }
}

/*
 我们这样记录, f(x, y), x 表示当前在第几个节点, y 表示当前的背包的总重量. 那么下面的代码中, 会有重复计算的问题. 重复的原因在于, 虽然前面的几个位置, 选择的策略不一样, 但是当到达 5 这个位置的时候, 可能会有重复的总重量. 而在5这个位置上, 不管前面的策略是什么, 总重量一样就代表在5以后的计算, 只用计算一次就可以了. 因为 5 下面还有巨大的分支, 在这里进行了剪枝, 会避免大量的重复计算.
 剪枝的重要性在于, 剪的枝后面, 还可能有着巨大的计算数据. 减掉, 可以避免很多的重复计算.
 */
void findMaxBag(int index, int weightTotal, int items[], int itemCount, int weightMax, int *result) {
    if (index == itemCount || weightTotal == weightMax) {
        if (weightTotal > *result) {
            *result = weightTotal;
        }
        return;
    }
    // 感觉这样写代码清晰一点点. 剪枝操作, 放到最开始的判断里面.
    if (weightTotal > weightMax) {
        return;
    }
    findMaxBag(index + 1, weightTotal, items, itemCount, weightMax, result); // 选择不装第 i 个元素
    findMaxBag(index + 1, weightTotal + items[index], items, itemCount, weightMax, result); //  选择装第 i 个元素.
}

//weight:物品重量，n:物品个数，w:背包可承载重量

/*
  上面的回溯, 就是一颗大的二叉树. 而这颗大的二叉树, 里面有着很多重复的内容. 我们利用剪枝的操作, 避免计算这些重复的内容. 大大地优化了效率. 而这里, 是用一张二维表, 记录在每一层里面, 会发生的背包容量的状态. 然后在下一层, 根据上一层的状态进行计算这一层的状态. 而这一层的状态相比上一层,会有两个变化, 就是上一层全部转移下来, 也就是不装这一层的重量. 或者上一层全部加上这一层的重量, 这个时候, 因为我们是根据上一层的状态改变的这一层的状态, 其实是消除了很多不同的选择但是相同的背包重量的计算的.
 所以说, 动态规划, 其实是一种空间换时间的解决方案, 因为我们把中间状态全部记录在我们自己的分劈的内存里面, 就不用系统每次函数调用, 将调用函数进行保存.
 */
int findMaxWeightUsingDynamic(int items[], int itemCount, int weightMax) {
    char weightMatrix[itemCount][weightMax+1];
    memset(weightMatrix, 0, sizeof(char) * itemCount * (weightMax+1));
    weightMatrix[0][0] = 1;
    weightMatrix[0][items[0]] = 1;
    for (int i = 1; i < itemCount; ++i) {
        for (int j = 0; j < weightMax + 1; ++j) {
            char topLevelValue = weightMatrix[i-1][j];
            if (topLevelValue) {
                weightMatrix[i][j] = 1;
                if (topLevelValue + items[j] < weightMax) {
                    weightMatrix[i][topLevelValue + items[j]] = 1;
                }
            }
        }
    }
    for (int i = weightMax - 1; i >= 0; --i) {
        if (weightMatrix[itemCount-1][i]) { return i; }
    }
    return 0;
}

int findMaxWeightUsingDynamicInSingleArray(int items[], int itemCount, int weightMax) {
    char weightMatrix[weightMax + 1];
    memset(weightMatrix, 0, weightMax+1);
    weightMatrix[0] = 1;
    if (items[0] < weightMax) {
        weightMatrix[items[0]] = 1;
    }
    for (int i = 1; i < itemCount; ++i) {
        for (int j = weightMax - items[i]; j >= 0; --j) { // 从后往前, 可以避免从前往后的时候, 加这一层的值而变成的1
            if (weightMatrix[j]) {
                if (weightMatrix[j] + items[i] < weightMax) {
                    weightMatrix[j+items[i]] = 1;
                }
            }
        }
    }
    for (int i = weightMax - 1; i >= 0; --i) {
        if (weightMatrix[i]) { return i; }
    }
    return 0;
}

int levelOfItems(int itemCount) {
    int countTotal = 0;
    int i = 1;
    int level = 0;
    while (countTotal < itemCount) {
        countTotal += i;
        i *= 2;
        level++;
    }
    return level;
}

int findMinPath(int items[], int count) {
    int level = levelOfItems(count);
    int pathes[level*2];
    memset(pathes, 0, level*2*sizeof(int));
    int itemsTotal = 0;
    pathes[0] = items[0];
    itemsTotal += 1;
    for (int i = 1; i <= level; itemsTotal += i *2, ++i) {
        for (int j = 0; j < i*2; ++j) {
            
        }
    }
    return 1;
}


int a[5] ={1, 2, 3, 7, 9};
void matchImp(int coins[], int count, int price, int minCounts[], int currentMinCount) {
    if (price >= 20) { return; }
    if (minCounts[price] == 0) {
        minCounts[price] = currentMinCount;
    } else if (minCounts[price] < currentMinCount){
        return;
    } else {
        minCounts[price] = currentMinCount;
    }
    for (int i = 0; i < count; ++i) {
        currentMinCount++;
        matchImp(coins, count, price+coins[i], minCounts, currentMinCount);
    }
    for (int i = 0; i < 21; i++) {
        std::cout << minCounts[i] << " ";
    }
    std::cout << '\n';
}
int match(int coins[], int count, int price) {
    int minCounts[price+1];
    int currentMinCount = 0;
    memset(minCounts, 0, sizeof(int) * (price+1));
    matchImp(coins, count, 0, minCounts, currentMinCount);
    return minCounts[price];
}


int main(int argc, const char * argv[]) {
    int minCoins = match(a, 5, 20);
    std::cout << minCoins;
    return 0;
}
