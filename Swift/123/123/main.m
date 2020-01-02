//
//  main.m
//  123
//
//  Created by JustinLau on 2019/12/15.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Person: NSObject

+ (void)sepeak;

@end

@implementation Person

+ (void)sepeak {
    NSLog(@"Person ");
}

@end

@interface Teacher: NSObject


@end

@implementation Teacher

+ (void)sepeak {
    NSLog(@"Teacher ");
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        [Teacher sepeak];
    }
    return 0;
}
