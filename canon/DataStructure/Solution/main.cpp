//
//  main.cpp
//  Solution
//
//  Created by JustinLau on 2019/3/17.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

using namespace std;


class Solution {
public:
    char maxInt[20];
    char minInt[20];
    char originInt[20];
    char reversInt[20];
    
    bool isLarge(char compareL[], char compareR[]) {
        int index = 0;
        while (compareL[index] && compareR[index]) {
            if (compareL[index] == compareR[index]) { index++; continue; }
            return compareL[index] - compareR[index];
        }
        return true;
    }
    void reversString(char string[]) {
        int index = 0;
        while (string[index]) {
            index++;
        }
        for (int begin = 0, last = index-1; begin<=last; ++begin, --last) {
            char stash = string[begin];
            string[begin] = string[last];
            string[last] = stash;
        }
        int prefixZeroCount = 0;
        while (string[prefixZeroCount] == '0') {
            ++prefixZeroCount;
        }
        int notZeroIndex = prefixZeroCount;
        while (string[notZeroIndex] != 0) {
            string[notZeroIndex - prefixZeroCount] = string[notZeroIndex];
            notZeroIndex++;
        }
    }
    void makeIntToString(char string[], int length, int value) {
        int index = 0;
        while (value) {
            int lastValeue = value%10;
            value /= 10;
            string[index++] = '0' + lastValeue;
        }
        reversString(string);
    }
    
    int makeStringToInt(char string[]) {
        int result = 0;
        int index = 0;
        while (string[index]) {
            result *= 10;
            result += string[index] - '0';
            ++index;
        }
        return result;
    }
    
    int reverse(int x) {
        if (x == 0) { return 0; }
        makeIntToString(maxInt, 20, INT32_MAX);
        makeIntToString(minInt, 20, INT32_MIN);
        makeIntToString(originInt, 20, x);
        memcpy(reversInt, originInt, 20);
        reversString(reversInt);
        if (x > 0) {
            if (this->isLarge(reversInt, maxInt)) {
                return 0; }
        } else {
            if (this->isLarge(reversInt, minInt)) {
                return 0; }
        }
        int result = makeStringToInt(reversInt);
        if (x < 0) { result = -result; }
        return result;
    }
};

int main(int argc, const char * argv[]) {
    // insert code here...
    Solution calculator;
    int result = calculator.reverse(198);
    
    return 0;
}
