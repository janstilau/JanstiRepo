#import "UIAction.h"

@implementation UIAction

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    } else if ([object isKindOfClass:[[self class] class]]) {
        return ([object target] == self.target && [object action] == self.action);
    } else {
        return NO;
    }
}

@end
