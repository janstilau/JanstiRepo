//
//  main.cpp
//  CanonCpp
//
//  Created by JustinLau on 2020/6/29.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#include <iostream>
#include "ReverseWords.hpp"
#include "Word.cpp"
#include "CopyNode.hpp"

using namespace std;

int main(int argc, const char * argv[]) {
    
    TreeToDoublyList::Node *node_4 = new TreeToDoublyList::Node(4);
    TreeToDoublyList::Node *node_2 = new TreeToDoublyList::Node(2);
    TreeToDoublyList::Node *node_5 = new TreeToDoublyList::Node(5);
    TreeToDoublyList::Node *node_1 = new TreeToDoublyList::Node(1);
    TreeToDoublyList::Node *node_3 = new TreeToDoublyList::Node(3);
    
    node_4->left = node_2;
    node_2->left = node_1;
    node_2->right = node_3;
    node_4->right = node_5;
    
    TreeToDoublyList list;
    list.treeToDoublyList(node_4);
    
    return 0;
}

/*
 Let's take LeetCode contest
 s'teL ekat edoCteeL tsetnoc
 s'teL ekat edoCteeL tsetnoc
 */
