#import "UIToolbarButton.h"
#import "UIBarButtonItem.h"
#import "UIImage+UIPrivate.h"
#import "UILabel.h"
#import "UIFont.h"

static UIEdgeInsets UIToolbarButtonInset = {0,4,0,4};

@implementation UIToolbarButton

- (id)initWithBarButtonItem:(UIBarButtonItem *)item
{
    NSAssert(item != nil, @"bar button item must not be nil");
    CGRect frame = CGRectMake(0,0,24,24);
    
    if ((self=[super initWithFrame:frame])) {
        UIImage *image = nil;
        NSString *title = nil;
        
        // 如果, 是系统的 Item, 那么使用系统提供的默认图.
        if (item->_isSystemItem) {
            switch (item->_systemItem) {
                case UIBarButtonSystemItemAdd:
                    image = [UIImage _buttonBarSystemItemAdd];
                    break;
                case UIBarButtonSystemItemReply:
                    image = [UIImage _buttonBarSystemItemReply];
                    break;
                default:
                    break;
            }
        } else {
            image = [item.image _toolbarImage];
            title = item.title;

            if (item.style == UIBarButtonItemStyleBordered) {
                self.titleLabel.font = [UIFont systemFontOfSize:11];
                [self setBackgroundImage:[UIImage _toolbarButtonImage] forState:UIControlStateNormal];
                [self setBackgroundImage:[UIImage _highlightedToolbarButtonImage] forState:UIControlStateHighlighted];
                self.contentEdgeInsets = UIEdgeInsetsMake(0,7,0,7);
                self.titleEdgeInsets = UIEdgeInsetsMake(4,0,0,0);
                self.clipsToBounds = YES;
                self.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
            }
        }
        
        // 这是一个 Button, 最后就是拿到 Item 里面配置的一些信息, 进行信息的设置.
        [self setImage:image forState:UIControlStateNormal];
        [self setTitle:title forState:UIControlStateNormal];
        [self addTarget:item.target action:item.action forControlEvents:UIControlEventTouchUpInside];
        
        // resize the view to fit according to the rules, which appear to be that if the width is set directly in the item, use that
        // value, otherwise size to fit - but cap the total height, I guess?
        CGSize fitToSize = frame.size;

        if (item.width > 0) {
            frame.size.width = item.width;
        } else {
            frame.size.width = [self sizeThatFits:fitToSize].width;
        }
        
        self.frame = frame;
    }
    return self;
}

- (CGRect)backgroundRectForBounds:(CGRect)bounds
{
    return UIEdgeInsetsInsetRect(bounds, UIToolbarButtonInset);
}

- (CGRect)contentRectForBounds:(CGRect)bounds
{
    return UIEdgeInsetsInsetRect(bounds, UIToolbarButtonInset);
}

- (CGSize)sizeThatFits:(CGSize)fitSize
{
    fitSize = [super sizeThatFits:fitSize];
    fitSize.width += UIToolbarButtonInset.left + UIToolbarButtonInset.right;
    fitSize.height += UIToolbarButtonInset.top + UIToolbarButtonInset.bottom;
    return fitSize;
}

@end
