//
//  main.m
//  JSONParser
//
//  Created by JustinLau on 2019/10/13.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSArray* array = @[@"&<>", @"124",@(213), @(23.23), @(0x00A1)];
        [array writeToFile:@"/Users/justinlau/Temp/plistcontent.plist" atomically:YES];
        
    }
    return 0;
}
