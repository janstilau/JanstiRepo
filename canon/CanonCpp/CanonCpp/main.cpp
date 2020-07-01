//
//  main.cpp
//  CanonCpp
//
//  Created by JustinLau on 2020/6/29.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#include <iostream>
#include "ReverseWords.hpp"

using namespace std;

int main(int argc, const char * argv[]) {
    
    string txt = "Let's take LeetCode contest";
    auto result = ReplaceSpace::replaceSpace(txt);
    cout << result;
    return 0;
}

/*
 Let's take LeetCode contest
 s'teL ekat edoCteeL tsetnoc
 s'teL ekat edoCteeL tsetnoc
 */
