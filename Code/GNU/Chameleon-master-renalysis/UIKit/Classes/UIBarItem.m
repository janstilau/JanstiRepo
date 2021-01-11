#import "UIBarItem.h"
#import "UIImage.h"
#import "UIAppearanceInstance.h"

@implementation UIBarItem

- (id)init
{
    if ((self = [super init])) {
        self.enabled = YES;
        self.imageInsets = UIEdgeInsetsZero;
    }
    return self;
}


- (void)setTitleTextAttributes:(NSDictionary *)attributes forState:(UIControlState)state
{
}

- (NSDictionary *)titleTextAttributesForState:(UIControlState)state
{
    return nil;
}

@end
