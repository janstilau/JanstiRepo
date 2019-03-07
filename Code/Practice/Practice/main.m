//
//  main.m
//  Practice
//
//  Created by JustinLau on 2019/3/4.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "A.h"



int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        A *aValue = [[A alloc] init];
        for (int i = 0; i < 100000; ++i) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                aValue.value++;
                NSLog(@"%@", @(aValue.value));
            });
        }
    }
    return 0;
}
