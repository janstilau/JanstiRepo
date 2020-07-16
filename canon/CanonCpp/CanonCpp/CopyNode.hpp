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

using namespace std;

class Node {
public:
    int val;
    Node* next;
    Node* random;
    
    Node(int _val) {
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
        int val;
        Node* left;
        Node* right;

        Node() {}

        Node(int _val) {
            val = _val;
            left = NULL;
            right = NULL;
        }

        Node(int _val, Node* _left, Node* _right) {
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


#endif /* CopyNode_hpp */
