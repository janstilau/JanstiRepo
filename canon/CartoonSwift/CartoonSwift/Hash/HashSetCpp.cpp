//
//  HashSetCpp.cpp
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/8.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#include "HashSetCpp.hpp"
#include <unordered_set>                // 0. include the library

/*
 C++ 中, set 增加了 unordered 的前缀.
 */
int main() {
    // 1. initialize a hash set
    unordered_set<int> hashset;
    // 2. insert a new key
    hashset.insert(3);
    hashset.insert(2);
    hashset.insert(1);
    // 3. delete a key
    hashset.erase(2); // erase 是 c++ 的集合通用写法.
    // 4. check if the key is in the hash set
    /*
     count 一定是额外进行维护的.
     */
    if (hashset.count(2) <= 0) {
        cout << "Key 2 is not in the hash set." << endl;
    }
    // 5. get the size of the hash set
    /*
     size 就是 capacity.
     */
    cout << "The size of hash set is: " << hashset.size() << endl;
    // 6. iterate the hash set
    for (auto it = hashset.begin(); it != hashset.end(); ++it) {
        cout << (*it) << " ";
    }
    cout << "are in the hash set." << endl;
    // 7. clear the hash set
    hashset.clear();
    // 8. check if the hash set is empty
    if (hashset.empty()) {
        cout << "hash set is empty now!" << endl;
    }
}

