//
//  main.m
//  MCPriorityQueue
//
//  Created by JustinLau on 2019/6/27.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCPriorityQueue.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int count = 100;
        NSMutableArray *nums = [NSMutableArray arrayWithCapacity:count];
        for (int i = 0; i < count; ++i) {
            int aNum = arc4random_uniform(2000);
            [nums addObject:@(aNum)];
        }
        NSLog(@"original - %@", nums);
        
        MCPriorityQueue *aQeueue = [[MCPriorityQueue alloc] initWithCategory:MCPriorityQueueCategoryMin];
        for (NSNumber *num in nums) {
            [aQeueue push:num];
             NSLog(@"push remain - %@", [aQeueue allElements]);
        }
        
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
        while (aQeueue.size > 50) {
            id popValue = [aQeueue pop];
            [result addObject:popValue];
            NSLog(@"pop - %@", popValue);
            NSLog(@"remain - %@", [aQeueue allElements]);
            NSLog(@"remainCount - %@", @(aQeueue.size));
        }
        NSLog(@"result - %@", result);
        
        [result removeAllObjects];
        for (int i = 0; i < count; ++i) {
            int aNum = arc4random_uniform(2000);
            [nums addObject:@(aNum)];
        }
        for (NSNumber *num in nums) {
            [aQeueue push:num];
            NSLog(@"push remain - %@", [aQeueue allElements]);
        }
        while (!aQeueue.empty) {
            id popValue = [aQeueue pop];
            [result addObject:popValue];
            NSLog(@"pop - %@", popValue);
            NSLog(@"remain - %@", [aQeueue allElements]);
        }
        NSLog(@"result - %@", result);
    }
    return 0;
}
