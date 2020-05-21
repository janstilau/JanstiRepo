#import <Foundation/Foundation.h>

// 一个简简单单对于 target, action 的封装.
@interface UIAction : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
@end
