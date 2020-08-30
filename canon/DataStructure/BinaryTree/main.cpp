//
//  main.cpp
//  BinaryTree
//
//  Created by JustinLau on 2019/3/12.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

using namespace std;

struct BTNode {
    char data;
    struct BTNode *lChild;
    struct BTNode *rChild;
};
/*
 如果用笔沿着二叉树进行描绘, 那么其实每一个节点, 都有着三次的访问的机会. 第一次是在左从上往下走的时候,
 第二次是在遍历完左子树回到自己位置的时候,
 第三次遍历完右子树对到自己位置的时候.
 在不同的时机, 添加访问操作, 这就是前中后遍历.
 */

typedef struct BTNode BTNode;

void visit(struct BTNode *root) {}

void preOrder(struct BTNode *root){
    if (!root) { return; }
    visit(root);
    preOrder(root->lChild);
    preOrder(root->rChild);
}

int op(char operSign, int left, int right) {
    return -1;
}

// 计算, 中间节点为运算符, 叶子节点为数值. 一个运算符节点, 必然有两个数值节点.
int compute(BTNode *rootNode) {
    if (!rootNode) { return  -1;}
    if (rootNode->lChild && rootNode->rChild) {// 运算符必然是左右都有子树
        int left = compute(rootNode->lChild);
        int right = compute(rootNode->rChild);
        int result = op(rootNode->data, left, right);
        return result;
    } else {
        return rootNode->data - '0';// 如果不满足上述要求, 那么就是数值节点, 直接取自己的值, 如果还有左, 或者右子树, 不管
    }
}

// 求一个二叉树的深度.
int getDepth(BTNode *root) {
    if (!root) { return 0; }
    int leftDepth = getDepth(root->lChild);
    int rightDepth = getDepth(root->rChild);
    return leftDepth>rightDepth? leftDepth+1: rightDepth+1;
}

// 查找二叉树中, data 为 value 的节点是否存在.
void searchNode(BTNode *root, BTNode *&result, int key) {
    if (result) { return; } // 剪纸操作, 如果 result 已经有值了, 那么直接退出. 因为这是递归函数, 所以可能直接一大支线就没了.
    if (!root) { return; }
    if (root->data == key) { result = root; return; }
    searchNode(root->lChild, result, key);
    searchNode(root->rChild, result, key);
}

/*
 层次遍历
 层次遍历要用到队列, 先取根节点, 入队.
 然后出队, 在访问节点前, 将这个节点的子节点入队. 然后拿当前节点做业务操作, 第一层就遍历完了.
 这个时候, 队内有着第二层的两个节点. 然后出队, 继续上面的节奏. 这个时候 ,第二层第一个节点的两个子节点会入队. 这样循环下去, 每次下一层节点要访问的时候, 上一层节点一定是按照顺序访问完了.
 等到队列为空的时候, 也就是遍历完成的时候.
 */

int const kMaxSize = 100;
void levelIterate(BTNode *root) {
    int head = 0, rear = 0;
    BTNode *array[kMaxSize];
    
    array[rear] = root;
    rear = (rear+1) % kMaxSize;
    while (head != rear) {
        BTNode *current = array[head];
        head = (head+1) % kMaxSize;
        visit(current);
        if (current->lChild) {
            array[rear] = current->lChild;
            rear = (rear+1) % kMaxSize;
        }
        if (current->rChild) {
            array[rear] = current->lChild;
            rear = (rear+1) % kMaxSize;
        }
    }
}


int main(int argc, const char * argv[]) {
    // insert code here...
    std::cout << "Hello, World!\n";
    return 0;
}
