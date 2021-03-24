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

+ (UIImage *)getImageFromBundle {
    /*
     将静态库打包的时候，只能打包代码资源，图片、本地json文件和xib等资源文件无法打包进去，使用.a静态库的时候需要三个组成部分：
     .a文件+需要暴露的头文件+资源文件；
     */
    NSBundle *resBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"StaticLibRes" ofType: @"bundle"]];
    return [UIImage imageWithContentsOfFile:[resBundle pathForResource:@"cover" ofType:@"png"]];
}

@end
