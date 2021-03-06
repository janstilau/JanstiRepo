#import "UITableViewCell+UIPrivate.h"
#import "UITableViewCellSeparator.h"
#import "UIColor.h"
#import "UILabel.h"
#import "UIImageView.h"
#import "UIFont.h"

extern CGFloat _UITableViewDefaultRowHeight;

/*
 之所以, 会有 ContentView, 是因为 UITableView 设计了下面的这些 View, 也就是为使用者预先设计了一些模式来用.
 虽然没什么人来真的这样做.
 */

@implementation UITableViewCell {
    // 系统添加的一些预定义的子控件.
    UITableViewCellStyle _style;
    UITableViewCellSeparator *_seperatorView;
    UIView *_contentView;
    UIImageView *_imageView;
    UILabel *_textLabel;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self=[super initWithFrame:frame])) {
        _indentationWidth = 10;
        _style = UITableViewCellStyleDefault;
        _selectionStyle = UITableViewCellSelectionStyleBlue;
        _seperatorView = [[UITableViewCellSeparator alloc] init];
        [self addSubview:_seperatorView];
        self.accessoryType = UITableViewCellAccessoryNone;
        self.editingAccessoryType = UITableViewCellAccessoryNone;
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self=[self initWithFrame:CGRectMake(0,0,320,_UITableViewDefaultRowHeight)])) {
        _style = style;
        _reuseIdentifier = [reuseIdentifier copy];
    }
    return self;
}

// 核心方法, 根据各个属性的配置, 将不同的子 View 的位置和次序进行调整. 
- (void)layoutSubviews
{
    [super layoutSubviews];
    
    const CGRect bounds = self.bounds;
    BOOL showingSeperator = !_seperatorView.hidden;
    
    CGRect contentFrame = CGRectMake(0,0,bounds.size.width,bounds.size.height-(showingSeperator? 1 : 0));
    CGRect accessoryRect = CGRectMake(bounds.size.width,0,0,0);
    
    if(_accessoryView) {
        accessoryRect.size = [_accessoryView sizeThatFits: bounds.size];
        accessoryRect.origin.x = bounds.size.width - accessoryRect.size.width;
        accessoryRect.origin.y = round(0.5*(bounds.size.height - accessoryRect.size.height));
        _accessoryView.frame = accessoryRect;
        [self addSubview: _accessoryView];
        contentFrame.size.width = accessoryRect.origin.x - 1;
    }
    
    _backgroundView.frame = contentFrame;
    _selectedBackgroundView.frame = contentFrame;
    _contentView.frame = contentFrame;
    
    [self sendSubviewToBack:_selectedBackgroundView];
    [self sendSubviewToBack:_backgroundView];
    [self bringSubviewToFront:_contentView];
    [self bringSubviewToFront:_accessoryView];
    
    if (showingSeperator) {
        _seperatorView.frame = CGRectMake(0,bounds.size.height-1,bounds.size.width,1);
        [self bringSubviewToFront:_seperatorView];
    }
    
    if (_style == UITableViewCellStyleDefault) {
        const CGFloat padding = 5;
        
        const BOOL showImage = (_imageView.image != nil);
        const CGFloat imageWidth = (showImage? 30:0);
        
        _imageView.frame = CGRectMake(padding,0,imageWidth,contentFrame.size.height);
        
        CGRect textRect;
        textRect.origin = CGPointMake(padding+imageWidth+padding,0);
        textRect.size = CGSizeMake(MAX(0,contentFrame.size.width-textRect.origin.x-padding),contentFrame.size.height);
        _textLabel.frame = textRect;
    }
}

/*
 这些都是懒加载, 是因为, 不同的 Style, 其实是展示不同的东西.
 并且, 实际上, 一般使用者很少使用这些玩意. 都是自己生成 View 添加上去.
 */
- (UIView *)contentView
{
    if (!_contentView) {
        _contentView = [[UIView alloc] init];
        [self addSubview:_contentView];
        [self layoutIfNeeded];
    }
    
    return _contentView;
}

- (UIImageView *)imageView
{
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeCenter;
        [self.contentView addSubview:_imageView];
        [self layoutIfNeeded];
    }
    
    return _imageView;
}

- (UILabel *)textLabel
{
    if (!_textLabel) {
        _textLabel = [[UILabel alloc] init];
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.textColor = [UIColor blackColor];
        _textLabel.highlightedTextColor = [UIColor whiteColor];
        _textLabel.font = [UIFont boldSystemFontOfSize:17];
        [self.contentView addSubview:_textLabel];
        [self layoutIfNeeded];
    }
    
    return _textLabel;
}

- (void)_setSeparatorStyle:(UITableViewCellSeparatorStyle)theStyle color:(UIColor *)theColor
{
    [_seperatorView setSeparatorStyle:theStyle color:theColor];
}

- (void)_setHighlighted:(BOOL)highlighted forViews:(id)subviews
{
    for (id view in subviews) {
        if ([view respondsToSelector:@selector(setHighlighted:)]) {
            [view setHighlighted:highlighted];
        }
        [self _setHighlighted:highlighted forViews:[view subviews]];
    }
}

- (void)_updateSelectionState
{
    BOOL shouldHighlight = (_highlighted || _selected);
    _selectedBackgroundView.hidden = !shouldHighlight;
    [self _setHighlighted:shouldHighlight forViews:[self subviews]];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    if (selected != _selected && _selectionStyle != UITableViewCellSelectionStyleNone) {
        _selected = selected;
        [self _updateSelectionState];
    }
}

- (void)setSelected:(BOOL)selected
{
    [self setSelected:selected animated:NO];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if (_highlighted != highlighted && _selectionStyle != UITableViewCellSelectionStyleNone) {
        _highlighted = highlighted;
        [self _updateSelectionState];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [self setHighlighted:highlighted animated:NO];
}

- (void)setBackgroundView:(UIView *)theBackgroundView
{
    if (theBackgroundView != _backgroundView) {
        [_backgroundView removeFromSuperview];
        _backgroundView = theBackgroundView;
        [self addSubview:_backgroundView];
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)setSelectedBackgroundView:(UIView *)theSelectedBackgroundView
{
    if (theSelectedBackgroundView != _selectedBackgroundView) {
        [_selectedBackgroundView removeFromSuperview];
        _selectedBackgroundView = theSelectedBackgroundView;
        _selectedBackgroundView.hidden = !_selected;
        [self addSubview:_selectedBackgroundView];
    }
}

// 切口, 自定义的时候使用.
- (void)prepareForReuse
{
}

@end
