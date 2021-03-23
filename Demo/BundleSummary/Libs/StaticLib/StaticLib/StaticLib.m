//
//  StaticLib.m
//  StaticLib
//
//  Created by JustinLau on 2021/3/23.
//

#import "StaticLib.h"

@implementation StaticLib

+ (void)log {
    /*
     静态库, 代码会和主工程的可执行文件合并到一起, 所以 MainBundle 和 [NSBundle bundleForClass:[self class]] 是一样的
     在主工程的 App 里面, 没有 StaticLib 的 mach-o 文件. 以及 StaticLib 工程的资源文件.
     */
    NSLog(@"StaticLib Log");
    NSLog(@"mainBundle: %@", [NSBundle mainBundle]);
    NSLog(@"selfBundle: %@", [NSBundle bundleForClass:[self class]]);
}

+ (UIImage *)getImage {
    /*
     StaticLib 的资源文件, 不会复制到主工程内, 所以, 该函数返回 null
     */
    NSString *imgPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"cover" ofType:@"png"];
    NSLog(@"imagePath %@", imgPath);
    return [UIImage imageWithContentsOfFile:imgPath];
}

+ (UIImage *)getImageFromAsset {
    /*
     StaticLib 的资源文件, 不会复制到主工程内, 所以, 该函数返回 null
     */
    return [UIImage imageNamed:@"btn_red_hl"];
}

@end
