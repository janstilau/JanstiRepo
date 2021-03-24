//
//  StaticFrameworkEntry.h
//  StaticFramework
//
//  Created by JustinLau on 2021/3/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface StaticFrameworkEntry : NSObject

+ (void)log;
+ (UIImage *)getImage;
+ (UIImage *)getImageFromAsset;
+ (UIImage *)getImageFromBundle;


@end

NS_ASSUME_NONNULL_END
