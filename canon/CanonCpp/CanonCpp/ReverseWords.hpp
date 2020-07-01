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

class ReplaceSpace {
public:
    static string replaceSpace(string s) {
        int size = (int)s.size();
        int targetSize = 0;
        for (int i = 0; i < size; i++) {
            if (s[i] == ' ') {
                targetSize += 3;
            } else {
                targetSize += 1;
            }
        }
        char result[targetSize+1];
        result[targetSize] = 0;
        // Let's take LeetCode contest
        for (int i = 0, j = 0; i < size; i++, j++) {
            if (s[i] == ' ') {
                result[j++] = '%';
                result[j++] = '2';
                result[j] = '0';
            } else {
                result[j] = s[i];
            }
        }
        return string(result);
    }
};


#endif /* ReverseWords_hpp */
