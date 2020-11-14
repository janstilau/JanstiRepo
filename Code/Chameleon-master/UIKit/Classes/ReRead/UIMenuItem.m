#import "UIMenuItem.h"

@implementation UIMenuItem

- (id)initWithTitle:(NSString *)title action:(SEL)action
{
    if ((self=[super init])) {
        self.title = title;
        self.action = action;
    }
    return self;
}

@end
