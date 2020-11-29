//
//  main.m
//  tool
//
//  Created by 刘国强 on 2020/11/29.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSFileManager.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSURL *url = [NSURL fileURLWithPath:@"/Users/liugq01/Downloads/libc"];
        NSError *error;
        NSArray *info = [NSFileManager.defaultManager contentsOfDirectoryAtPath:@" /Users/liugq01/Downloads/libc/assert" error:&error];
        NSLog(@"%@", info);
        NSLog(@"%@", error);
    }
    return 0;
}
