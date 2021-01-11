#import "UIToolbar.h"
#import "UIBarButtonItem.h"
#import "UIToolbarButton.h"
#import "UIColor.h"
#import "UIGraphics.h"

static const CGFloat kBarHeight = 28;

@interface UIToolbarItem : NSObject

- (id)initWithBarButtonItem:(UIBarButtonItem *)anItem;

@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) UIBarButtonItem *item;
@property (nonatomic, readonly) CGFloat width;

@end

@implementation UIToolbarItem

- (id)initWithBarButtonItem:(UIBarButtonItem *)anItem
{
    if ((self=[super init])) {
        NSAssert((anItem != nil), @"the bar button item must not be nil");
        
        _item = anItem;
        
        if (!_item->_isSystemItem && _item.customView) {
            _view = _item.customView;
        } else if (!_item->_isSystemItem || (_item->_systemItem != UIBarButtonSystemItemFixedSpace && _item->_systemItem != UIBarButtonSystemItemFlexibleSpace)) {
            _view = [[UIToolbarButton alloc] initWithBarButtonItem:_item];
        }
    }
    return self;
}


- (CGFloat)width
{
    if (_view) {
        return _view.frame.size.width;
    } else if (_item->_isSystemItem && _item->_systemItem == UIBarButtonSystemItemFixedSpace) {
        return _item.width;
    } else {
        return -1;
    }
}

@end








@implementation UIToolbar {
    NSMutableArray *_toolbarItems;
}

- (id)initWithFrame:(CGRect)frame
{
    frame.size.height = kBarHeight;
    
    if ((self=[super initWithFrame:frame])) {
        _toolbarItems = [[NSMutableArray alloc] init];
        self.barStyle = UIBarStyleDefault;
        self.translucent = NO;
        self.tintColor = nil;
    }
    return self;
}

- (void)setBarStyle:(UIBarStyle)newStyle
{
    _barStyle = newStyle;

    // this is for backward compatibility - UIBarStyleBlackTranslucent is deprecated 
    if (_barStyle == UIBarStyleBlackTranslucent) {
        self.translucent = YES;
    }
}

/*
- (void)_updateItemViews
{
    [_itemViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_itemViews removeAllObjects];

    NSUInteger numberOfFlexibleItems = 0;
    
    for (UIBarButtonItem *item in _items) {
        if ((item->_isSystemItem) && (item->_systemItem == UIBarButtonSystemItemFlexibleSpace)) {
            numberOfFlexibleItems++;
        }
    }

    const CGSize size = self.bounds.size;
    const CGFloat flexibleSpaceWidth = (numberOfFlexibleItems > 0)? MAX(0, size.width/numberOfFlexibleItems) : 0;
    CGFloat left = 0;
    
    for (UIBarButtonItem *item in _items) {
        UIView *view = item.customView;

        if (!view) {
            if (item->_isSystemItem && item->_systemItem == UIBarButtonSystemItemFlexibleSpace) {
                left += flexibleSpaceWidth;
            } else if (item->_isSystemItem && item->_systemItem == UIBarButtonSystemItemFixedSpace) {
                left += item.width;
            } else {
                view = [[[UIToolbarButton alloc] initWithBarButtonItem:item] autorelease];
            }
        }
        
        if (view) {
            CGRect frame = view.frame;
            frame.origin.x = left;
            frame.origin.y = (size.height / 2.f) - (frame.size.height / 2.f);
            frame = CGRectStandardize(frame);
            
            view.frame = frame;
            left += frame.size.width;
            
            [self addSubview:view];
        }
    }
}
*/

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat itemWidth = 0;
    NSUInteger numberOfFlexibleItems = 0;
    
    for (UIToolbarItem *toolbarItem in _toolbarItems) {
        const CGFloat width = toolbarItem.width;
        if (width >= 0) {
            itemWidth += width;
        } else {
            numberOfFlexibleItems++;
        }
    }
    
    const CGSize size = self.bounds.size;
    const CGFloat flexibleSpaceWidth = (numberOfFlexibleItems > 0)? ((size.width - itemWidth) / numberOfFlexibleItems) : 0;
    const CGFloat centerY = size.height / 2.f;

    CGFloat x = 0;
    
    for (UIToolbarItem *toolbarItem in _toolbarItems) {
        UIView *view = toolbarItem.view;
        const CGFloat width = toolbarItem.width;
        
        if (view) {
            CGRect frame = view.frame;
            frame.origin.x = x;
            frame.origin.y = floorf(centerY - (frame.size.height / 2.f));
            view.frame = frame;
        }

        if (width < 0) {
            x += flexibleSpaceWidth;
        } else {
            x += width;
        }
    }
}

- (void)setItems:(NSArray *)newItems animated:(BOOL)animated
{
    if (![self.items isEqualToArray:newItems]) {
        // if animated, fade old item views out, otherwise just remove them
        for (UIToolbarItem *toolbarItem in _toolbarItems) {
            UIView *view = toolbarItem.view;
            if (view) {
                [UIView animateWithDuration:animated? 0.2 : 0
                                 animations:^(void) {
                                     view.alpha = 0;
                                 }
                                 completion:^(BOOL finished) {
                                     [view removeFromSuperview];
                                 }];
            }
        }
        
        [_toolbarItems removeAllObjects];
        
        for (UIBarButtonItem *item in newItems) {
            UIToolbarItem *toolbarItem = [[UIToolbarItem alloc] initWithBarButtonItem:item];
            [_toolbarItems addObject:toolbarItem];
            [self addSubview:toolbarItem.view];
        }
                
        // if animated, fade them in
        if (animated) {
            for (UIToolbarItem *toolbarItem in _toolbarItems) {
                UIView *view = toolbarItem.view;
                if (view) {
                    view.alpha = 0;
                    
                    [UIView animateWithDuration:0.2
                                     animations:^(void) {
                                         view.alpha = 1;
                                     }];
                }
            }
        }
    }
}

- (void)setItems:(NSArray *)items
{
    [self setItems:items animated:NO];
}

- (NSArray *)items
{
    return [_toolbarItems valueForKey:@"item"];
}

- (void)drawRect:(CGRect)rect
{
    const CGRect bounds = self.bounds;
    
    UIColor *color = _tintColor ?: [UIColor colorWithRed:21/255.f green:21/255.f blue:25/255.f alpha:1];

    [color setFill];
    UIRectFill(bounds);
    
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0,0,bounds.size.width,1));
}

- (NSString *)description
{
    NSString *barStyle = @"";
    switch (self.barStyle) {
        case UIBarStyleDefault:
            barStyle = @"Default";
            break;
        case UIBarStyleBlack:
            barStyle = @"Black";
            break;
        case UIBarStyleBlackTranslucent:
            barStyle = @"Black Translucent (Deprecated)";
            break;
    }
    return [NSString stringWithFormat:@"<%@: %p; barStyle = %@; tintColor = %@, isTranslucent = %@>", [self className], self, barStyle, ([self.tintColor description] ?: @"Default"), (self.translucent ? @"YES" : @"NO")];
}

- (UIImage *)backgroundImageForToolbarPosition:(UIToolbarPosition)topOrBottom barMetrics:(UIBarMetrics)barMetrics
{
    return nil;
}

- (void)setBackgroundImage:(UIImage *)backgroundImage forToolbarPosition:(UIToolbarPosition)topOrBottom barMetrics:(UIBarMetrics)barMetrics
{
}

- (CGSize)sizeThatFits:(CGSize)size
{
    size.height = kBarHeight;
    return size;
}

@end
