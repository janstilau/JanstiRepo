#import "UITabBar.h"
#import "UIImageView.h"
#import "UIImage+UIPrivate.h"
#import <QuartzCore/QuartzCore.h>

#define TABBAR_HEIGHT 60.0
/*
 选中这个状态, 永远是计算选中的 id, 而不是将选中这件事, 交给被管理的对象.
    首先, 如果有重用机制的话, 那么这个对象被重用状态状态会更新.
    再者, 作为管理者, 应该知道管理的数据的状态. 选中这个数据, 就应该是管理者负责维护的.
 */
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
