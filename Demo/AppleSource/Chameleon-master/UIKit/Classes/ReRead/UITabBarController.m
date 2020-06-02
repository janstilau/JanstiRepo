#import "UITabBarController.h"
#import "UITabBar.h"

@implementation UITabBarController

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    if ((self = [super initWithNibName:nibName bundle:nibBundle])) {
        _tabBar = [[UITabBar alloc] initWithFrame:CGRectZero];
    }
    return self;
}


- (void)setViewControllers:(NSArray *)viewController animated:(BOOL)animated
{
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; selectedViewController = %@; viewControllers = %@; selectedIndex = %lu; tabBar = %@>", [self className], self, self.selectedViewController, self.viewControllers, (unsigned long)self.selectedIndex, self.tabBar];
}

@end
