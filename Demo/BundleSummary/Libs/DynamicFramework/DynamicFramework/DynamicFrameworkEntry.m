//
//  DynamicFrameworkEntry.m
//  DynamicFramework
//
//  Created by JustinLau on 2021/3/23.
//

#import "DynamicFrameworkEntry.h"

@implementation DynamicFrameworkEntry


+ (void)log {
    // 使用了动态库, 两个 Bundle 就分离了.
    NSLog(@"DynamicFrameworkEntry Log");
    NSLog(@"mainBundle: %@", [NSBundle mainBundle]);
    NSLog(@"selfBundle: %@", [NSBundle bundleForClass:[self class]]);
}

+ (UIImage *)getImage {
    // 先是查找到自己的 bundle, 然后获取里面的图片, 有值.
    NSString *imgPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"cover" ofType:@"png"];
    NSLog(@"imagePath %@", imgPath);
    return [UIImage imageWithContentsOfFile:imgPath];
}

+ (UIImage *)getImageFromAsset {
    // 没有值
    return [UIImage imageNamed:@"btn_red_hl"];
}

+ (UIImage *)getImageFromBundle {
    // 先是查找到自己的 bundle, 然后获取里面的图片, 有值.
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:@"DynamicFrameRes" withExtension:@"bundle"];
    NSBundle *resBundle = [NSBundle bundleWithURL:url];
    return [UIImage imageWithContentsOfFile:[resBundle pathForResource:@"cover" ofType:@"png"]];
}


@end
