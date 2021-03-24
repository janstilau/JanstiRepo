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
    NSLog(@"StaticFramework Log");
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
    /*
     使用库中的资源, 以下的写法, 是标准的写法.
     如果是 lib.a 的形式, 那么 .a 文件, header 文件,  bundle 文件, 要同时暴露给用户.
     使用 framework 文件, 那么应该将 framework 里面的 bundle, 转移到可执行文件的目录下.
     cocoapods 在构建过程中, 会使用脚本进行复制的这一个过程.
     */
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:@"StaticFrameRes" withExtension:@"bundle"];
    NSBundle *resBundle = [NSBundle bundleWithURL:url];
    return [UIImage imageWithContentsOfFile:[resBundle pathForResource:@"cover" ofType:@"png"]];
}


@end
