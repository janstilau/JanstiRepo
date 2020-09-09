#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

extern NSString *const UIScreenDidConnectNotification;
extern NSString *const UIScreenDidDisconnectNotification;
extern NSString *const UIScreenModeDidChangeNotification;

@class UIKitView, UIScreenMode, UIWindow;

/*
 An object that defines the properties associated with a hardware-based display.
 */

@interface UIScreen : NSObject // 原来 UIScreen 不是 UIView 的子类.
+ (UIScreen *)mainScreen;
+ (NSArray *)screens;

@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) CGRect applicationFrame;
@property (nonatomic, readonly, copy) NSArray *availableModes;      // only ever returns the currentMode
@property (nonatomic, strong) UIScreenMode *currentMode;            // ignores any attempt to set this
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic) CGFloat brightness;                           // not implemented, of course
@end
