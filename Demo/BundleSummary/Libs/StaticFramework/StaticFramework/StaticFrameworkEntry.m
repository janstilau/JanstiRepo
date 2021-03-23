//
//  StaticFrameworkEntry.m
//  StaticFramework
//
//  Created by JustinLau on 2021/3/23.
//

#import "StaticFrameworkEntry.h"

@interface StaticFrameworkEntry ()

@end

@implementation StaticFrameworkEntry

+ (void)log {
    NSLog(@"StaticLib Log");
    NSLog(@"mainBundle: %@", [NSBundle mainBundle]);
    NSLog(@"selfBundle: %@", [NSBundle bundleForClass:[self class]]);
}

+ (UIImage *)getImage {
    NSString *imgPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"cover" ofType:@"png"];
    NSLog(@"imagePath %@", imgPath);
    return [UIImage imageWithContentsOfFile:imgPath];
}

+ (UIImage *)getImageFromAsset {
    return [UIImage imageNamed:@"btn_red_hl"];
}

+ (UIImage *)getImageFromBundle {
    NSBundle *resBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"StaticFrameRes" ofType: @"bundle"]];
    return [UIImage imageWithContentsOfFile:[resBundle pathForResource:@"cover" ofType:@"png"]];
}


@end
