//
//  StaticLib.h
//  StaticLib
//
//  Created by JustinLau on 2021/3/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface StaticLib : NSObject

+ (void)log;
+ (UIImage *)getImage;
+ (UIImage *)getImageFromAsset;

@end
