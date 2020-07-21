//
//  CopyNode.hpp
//  CanonCpp
//
//  Created by JustinLau on 2020/7/16.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#ifndef CopyNode_hpp
#define CopyNode_hpp

#include <stdio.h>
#include <iostream>
#include <set>
#include <map>
#include <vector>
#include <math.h>

using namespace std;

class Node {
public:
    long val;
    Node* next;
    Node* random;
    
    Node(long _val) {
        val = _val;
        next = NULL;
        random = NULL;
    }
};

/*
 [[7,null],[13,0],[11,4],[10,2],[1,0]]
 */
class Solution {
public:
    Node* copyRandomList(Node* head) {
        if (head == nullptr) { return nullptr; }
        
        Node *current = head;
        while (current) {
            Node *nextNode = current->next;
            Node *copiedNode = new Node(current->val);
            current->next = copiedNode;
            copiedNode->next = nextNode;
            current = nextNode;
        }
        
        Node *result = head->next;
        
        current = head;
        while (current) {
            Node *srcCurrent = current;
            Node *copiedCurrent = current->next;
            current = copiedCurrent->next;
            if (srcCurrent->random) {
                copiedCurrent->random = srcCurrent->random->next;
            }
            
            srcCurrent->next = copiedCurrent->next;
            if (copiedCurrent->next) {
                copiedCurrent->next = copiedCurrent->next->next;
            }
            
        }
        
        current = head;
        while (head) {
            std::cout << current->val;
            current = current->next;
        }
        
        return result;
    }
    
    Node* copyRandomListUseMap(Node* head) {
        if (head == nullptr) { return nullptr; }
        map<Node*, Node*> nodeMapper;
        
        Node sentinelNode = Node(-1);
        Node *copiedHead = new Node(head->val);
        sentinelNode.next = copiedHead;
        nodeMapper[head] = copiedHead;
        
        Node *nextNode = head->next;
        Node *copiedCurrent = sentinelNode.next;
        
        while (nextNode) {
            Node *copiedNode = new Node(nextNode->val);
            copiedCurrent->next = copiedNode;
            nodeMapper[nextNode] = copiedNode;
            
            nextNode = nextNode->next;
            copiedCurrent = copiedCurrent->next;
        }
        
        nextNode = head;
        copiedCurrent = sentinelNode.next;
        while (nextNode) {
            copiedCurrent->random = nodeMapper[nextNode->random];
            nextNode = nextNode->next;
            copiedCurrent = copiedCurrent->next;
        }
        
        return sentinelNode.next;
    }
};


class TreeToDoublyList {
public:
    class Node {
    public:
        long val;
        Node* left;
        Node* right;

        Node() {}

        Node(long _val) {
            val = _val;
            left = NULL;
            right = NULL;
        }

        Node(long _val, Node* _left, Node* _right) {
            val = _val;
            left = _left;
            right = _right;
        }
    };
public:
    
    
    Node* treeToDoublyList(Node* root) {
        if (root == nullptr) { return nullptr; }
        
        vector<Node*> stack;
        
        Node *resultHead = nullptr;
        Node *preNode = nullptr;
        Node *current = root;
        Node *resultTail = nullptr;
        while (current || stack.size()) {
            if (current) {
                stack.push_back(current);
                current = current->left;
                continue;
            }
            Node *topNode = stack.back();
            stack.pop_back();
            current = topNode->right;

            if (!resultHead) {
                resultHead = topNode;
                resultHead->left = nullptr;
            } else {
                topNode->left = preNode;
                preNode->right = topNode;
            }
            preNode = topNode;
            if (!stack.size() && !current) {
                resultTail = topNode;
            }
        }
        resultTail->right = resultHead;
        resultHead->left = resultTail;
    
        return resultHead;
    }
};

class Permutation {
public:
    vector<string> permutation(string txt) {
        long length = txt.size();
        auto result = vector<string>();
        auto hashResult = set<string>();
        if (length == 0) { return result; }
        getPermutaion(txt, 0, result, hashResult);
        return result;
    }
    
    void getPermutaion(string &txt, long begin, vector<string>& result, set<string> &hashSet) {
        if (begin >= txt.length()) {
            if (hashSet.find(txt) == hashSet.end()) {
                result.push_back(txt);
                hashSet.insert(txt);
            }
        } else {
            /*
             只用考虑, 开始做了什么, 最后做了什么, 不要尝试去理解所有的细节.
             */
            for (long i = begin; i < txt.length(); ++i) {
                char temp = txt[begin];
                txt[begin] = txt[i];
                txt[i] = temp;
                
                getPermutaion(txt, begin+1, result, hashSet);
                
                temp = txt[begin];
                txt[begin] = txt[i];
                txt[i] = temp;
            }
        }
    }
};

/*
 数字以0123456789101112131415…的格式序列化到一个字符序列中。在这个序列中，第5位（从下标0开始计数）是5，第13位是1，第19位是4，等等。

 请写一个函数，求任意第n位对应的数字。
 */

class FindNthDigit {
public:
    int findNthDigit(int n) {
        if (n < 0) { return -1; }
        long digitCount = 1;
        long left = 0;
        long right = 0;
        while (true) {
            long leftNum = (long)pow(10, digitCount-1);
            if (leftNum == 1) { leftNum = 0; }
            long rightNum = (long)(pow(10, digitCount) - 1);
            const long numCount = rightNum - leftNum + 1;
            right = left + numCount*digitCount;
            if (left <= n && n < right) { break;}
            digitCount += 1;
            left = right;
        }
        
        long numStart = (long)pow(10, digitCount-1);
        if (numStart == 1) { numStart = 0; }
        long space = (n - left) / digitCount;
        long num = numStart + space;
        long digitTarget = n - left - digitCount*space;
        for (long i = 0; i < digitCount; ++i) {
            long value = num % 10;
            if (i+digitTarget+1 == digitCount) {
                return value;
            }
            num /= 10;
        }
        return -1;
    }
};


class MinNumber {
public:
    string minNumber(vector<int>& nums) {
        return "";
    }
};

#endif /* CopyNode_hpp */
