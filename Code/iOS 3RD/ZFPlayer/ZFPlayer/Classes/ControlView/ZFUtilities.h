#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// iPhoneX  iPhoneXS  iPhoneXS Max  iPhoneXR 机型判断
#define iPhoneX ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? ((NSInteger)(([[UIScreen mainScreen] currentMode].size.height/[[UIScreen mainScreen] currentMode].size.width)*100) == 216) : NO)

#define ZFPlayer_Image(file)                 [ZFUtilities imageNamed:file]

// 屏幕的宽
#define ZFPlayer_ScreenWidth                 [[UIScreen mainScreen] bounds].size.width
// 屏幕的高
#define ZFPlayer_ScreenHeight                [[UIScreen mainScreen] bounds].size.height

@interface ZFUtilities : NSObject

+ (NSString *)convertTimeSecond:(NSInteger)timeSecond;

+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;

+ (UIImage *)imageNamed:(NSString *)name;

@end

