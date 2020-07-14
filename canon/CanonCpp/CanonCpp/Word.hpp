//
//  Word.hpp
//  CanonCpp
//
//  Created by JustinLau on 2020/7/8.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#ifndef Word_hpp
#define Word_hpp

#include <iostream>
#include <set>
#include <map>

using namespace std;

class BuddyStrings {
public:
    bool buddyStrings(string A, string B) {
        if (A.length() != B.length()) { return false; }
        if (A.length() < 2) { return false; }
        set<int> difference = set<int>();
        set<int> values = set<int>();
        bool hasRepeation = false;
        for (int i = 0 ; i < A.length(); ++i) {
            if (values.find(A[i]) != values.end()) {
                hasRepeation = true;
            }
            if (A[i] - B[i] != 0) {
                difference.insert(i);
            }
            values.insert(A[i]);
        }
        if (difference.size() == 0 && hasRepeation) { return true; }
        if (difference.size() != 2) { return false; }
        auto begin = difference.cbegin();
        auto end = difference.cend();
        end = --end;
        if (A[*begin] != B[*end] || A[*end] != B[*begin]) {
            return false;
        }
        return true;
    }
};

class IsIsomorphic {
public:
    bool isIsomorphic(string s, string t) {
        if (s.length() != t.length()) { return false; }
        if (s.length() == 1) { return true; }
        auto charMap = map<int, int>();
        for (int i = 0; i < s.length(); ++i) {
            auto iter = charMap.find(s[i]);
            if (iter == charMap.end()) {
                charMap[s[i]] = t[i];
            } else {
                auto currentChar = (*iter).second;
                if (currentChar != t[i]) { return false; }
            }
        }
        return true;
    }
};



class MinWindow {
public:
    
    bool isMatch(const map<char, int> &map) {
        auto begin = map.cbegin();
        while (begin != map.cend()) {
            auto value = *begin;
            if (value.second == 0) { return false; }
            begin++;
        }
        return true;
    }
    string minWindow(string s, string t) {
        auto charTimes = map<char, int>();
        auto targetTiems = map<char, int>();
        for (int i = 0; i < t.length(); ++i) {
            charTimes[t[i]] = 0;
            targetTiems[t[i]] += 1;
        }
        int left = 0;
        int right = 0;
        int resultLeft = 0;
        int resultRight = 0;
        int minLength = s.length() + 1;
        while (left < s.length() || right < s.length()) {
            if (charTimes == targetTiems && left < s.length()) {
                if (charTimes.find(s[left]) != charTimes.end()) {
                    charTimes[s[left]] -= 1;
                }
                left += 1;
            } else if (charTimes != targetTiems && right < s.length()) {
                if (charTimes.find(s[right]) != charTimes.end()) {
                    charTimes[s[right]] += 1;
                }
                right += 1;
            } else {
                break;
            }
            if (charTimes == targetTiems) {
                if (right - left < minLength) {
                    resultLeft = left;
                    resultRight = right;
                    minLength = right - left;
                }
            }
        }
        
        if (resultLeft == resultRight) {
            return "";
        } else {
            char* values = (char*)malloc(resultRight-resultLeft+1);
            for (int i = resultLeft; i <= resultRight; ++i) {
                values[i-resultLeft] = s[i];
            }
            values[resultRight-resultLeft] = 0;
            return string(values);
        }
    }
};

/*
 ADOBECODEB ANC
 ABC
 */

#endif /* Word_hpp */
