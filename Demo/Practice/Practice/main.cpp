//
//  main.cpp
//  Practice
//
//  Created by JustinLau on 2019/8/4.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>
#include "common.h"

bool isUniqueChar(char *text, int length) {
    char *container = (char *)malloc(sizeof(char) * 256);
    memset(container, 256, sizeof(char));
    for (int i = 0; i < length; ++i) {
        if (container[i]) { return false; }
        container[i] = 1;
    }
    return false;
}

void reverse(char *str) {
    if (!str) { return; }
    if (!str[0]) { return; }
    int end = 0;
    while (str[end]) {
        ++end;
    }
    int left = 0;
    int right = end - 1;
    char temp;
    while (right > left) {
        temp = str[right];
        str[right] = str[left];
        str[left] = temp;
        --right;
        ++left;
    }
}

bool isCompatible(string left, string right) {
    if (left.length() != right.length()) { return false; }
    char *leftContainer = (char*)calloc(left.length(), sizeof(char));
    char *rightContainer = (char*)calloc(right.length(), sizeof(char));
    for (int i = 0; i < left.length(); ++i) {
        leftContainer[left.at(i)]++;
    }
    for (int i = 0; i < left.length(); ++i) {
        rightContainer[left.at(i)]++;
    }
    for (int i = 0; i < 256; ++i) {
        if (leftContainer[i] != rightContainer[i]) {
            return false;
        }
    }
    return true;
}

void expandStr(string& text) {
    if (!text.length()) { return; }
    int originEnd = (int)text.length() - 1;
    int spaceNum = 0;
    for (int i = 0; i < text.length(); ++i) {
        if (text[i] == ' ') { ++spaceNum; }
    }
    if (!spaceNum) { return; }
    int expandEnd = originEnd + 2*spaceNum;
    text.resize(expandEnd + 1, sizeof(char));
    for (int i = originEnd; i > 0; --i) {
        char item = text[i];
        if (item != ' ') {
            text[expandEnd] = item;
            --expandEnd;
        } else {
            text[expandEnd] = '0';
            text[expandEnd - 1] = '2';
            text[expandEnd - 2] = '%';
            expandEnd -= 3;
        }
    }
}


int main(int argc, const char * argv[]) {
    string text = "hehe woai ni .";
    cout<< text << '\n';
    expandStr(text);
    cout<< text << '\n';
    return 0;
}
