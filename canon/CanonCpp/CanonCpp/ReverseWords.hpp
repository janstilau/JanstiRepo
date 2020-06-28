//
//  ReverseWords.hpp
//  CanonCpp
//
//  Created by JustinLau on 2020/6/29.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#ifndef ReverseWords_hpp
#define ReverseWords_hpp

#include <iostream>

using namespace std;

class ReverseWords {
public:
    static string reverseWords(string s) {
        string result = s;
        int left = 0;
        int right = 0;
        for (int i = 0; i < result.length(); ++i) {
            char item = result[i];
            if (item == ' ') {
                ReverseWords::reverseSegment(result, left, right);
                left = i+1;
                right = i+1;
            } else {
                right += 1;
            }
        }
        if (left != right) {
            ReverseWords::reverseSegment(result, left, right);
        }
        return result;
    }
    
    static void reverseSegment(string &txt, int left, int right) {
        right -= 1;
        while (left <= right) {
            char temp = txt[right];
            txt[right] = txt[left];
            txt[left] = temp;
            left++;
            right--;
        }
    }
};

#endif /* ReverseWords_hpp */
