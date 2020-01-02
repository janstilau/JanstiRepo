//
//  main.m
//  funcStack
//
//  Created by JustinLau on 2019/12/29.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>

void b() {
    int c = 14;//D
    int d = 15;//E
}

void a() {
    int a = 10;//A
    int B = 11;//B
    b();
    int C = 13;//C
}

int main(int argc, const char * argv[]) {
    a();
    return 0;
}
