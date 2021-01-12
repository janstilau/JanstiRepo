#import "UITabBar.h"
#import "UIImageView.h"
#import "UIImage+UIPrivate.h"
#import <QuartzCore/QuartzCore.h>

#define TABBAR_HEIGHT 60.0

@implementation UITabBar {
    NSInteger _selectedItemIndex;
}

- (id)initWithFrame:(CGRect)rect
{
    if ((self = [super initWithFrame:rect])) {
        rect.size.height = TABBAR_HEIGHT; // tabbar is always fixed
        _selectedItemIndex = -1;
        UIImage *backgroundImage = [UIImage _popoverBackgroundImage];
        UIImageView *backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        backgroundView.frame = rect;
        [self addSubview:backgroundView];
    }
    return self;
}

- (UITabBarItem *)selectedItem
{
    if (_selectedItemIndex >= 0) {
        return [_items objectAtIndex:_selectedItemIndex];
    }
    return nil;
}

- (void)setSelectedItem:(UITabBarItem *)selectedItem
{
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
}

- (void)beginCustomizingItems:(NSArray *)items
{
}

- (BOOL)endCustomizingAnimated:(BOOL)animated
{
    return YES;
}

- (BOOL)isCustomizing
{
    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; selectedItem = %@; items = %@; delegate = %@>", [self className], self, self.selectedItem, self.items, self.delegate];
}

@end
