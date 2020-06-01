#import <Foundation/Foundation.h>

@interface UIMenuItem : NSObject
- (id)initWithTitle:(NSString *)title action:(SEL)action;

@property SEL action;
@property (copy) NSString *title;
@end
