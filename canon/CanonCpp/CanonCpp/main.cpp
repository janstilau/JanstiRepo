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
    
    Permutation aValue;
    auto result = aValue.permutation("Abc");
    for (int i = 0; i < result.size(); ++i) {
        std::cout << result[i] << '\n';
    }
    
    return 0;
}

/*
 Let's take LeetCode contest
 s'teL ekat edoCteeL tsetnoc
 s'teL ekat edoCteeL tsetnoc
 */
