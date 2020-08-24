//
//  main.cpp
//  StringToSearch
//
//  Created by JustinLau on 2019/3/13.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#include <iostream>

bool isHasSubString(char text[], char search[]) {
    if (!text || !search) { return false; }
    int i;
    for (i = 0; text[i] && search[i]; ++i) {
        if (text[i] != search[i]) {
            return false;
        }
    }
    return true;
}

int bruteSearch(char text[], int n, char search[], int m) {
    if (n < m) { return -1;}
    for (int i = 0; i <= n - m; ++i) {
        if (isHasSubString(text+i, search)) {
            return i;
        }
    }
    return -1;
}


int hashSearch(char text[], int n, char search[], int m) {
    if (n < m) { return -1;}
    int preCharHashTotal = 0;
    int searchHash = 0;
    for (int i = 0; i < m - 1; ++i) {
        preCharHashTotal += text[i];
        searchHash += search[i];
    }
    searchHash += search[m-1];
    
    int length = m - 1;
    for (int i = length; i < n; ++i) {
        preCharHashTotal += text[i];
        if (preCharHashTotal != searchHash) {
            preCharHashTotal -= text[i-length];
            continue;
        }
        if (isHasSubString(text + i-length, search)) {
            return i-length;
        } else {
            preCharHashTotal -= text[i-length];
            continue;
        }
    }
    return -1;
}

int main(int argc, const char * argv[]) {
    
    char primaryText[] = "222123";
    char searchText[] = "123";
    
//    int result = bruteSearch(primaryText, 6, searchText, 3);
    int hashResult = hashSearch(primaryText, 6, searchText, 3);
    return 0;
}
