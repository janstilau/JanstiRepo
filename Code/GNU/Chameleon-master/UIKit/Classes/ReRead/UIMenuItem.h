#import <Foundation/Foundation.h>

@interface UIMenuItem : NSObject

@property SEL action;
@property (copy) NSString *title;

- (id)initWithTitle:(NSString *)title action:(SEL)action;

@end
