#import "UINavigationItem+UIPrivate.h"

NSString *const UINavigationItemDidChange = @"UINavigationItemDidChange";

@implementation UINavigationItem

- (id)initWithTitle:(NSString *)theTitle
{
    if ((self=[super init])) {
        _title = [theTitle copy];
    }
    return self;
}

- (void)setBackBarButtonItem:(UIBarButtonItem *)backBarButtonItem
{
    if (_backBarButtonItem != backBarButtonItem) {
        _backBarButtonItem = backBarButtonItem;
        [[NSNotificationCenter defaultCenter] postNotificationName:UINavigationItemDidChange object:self];
    }
}

- (void)setLeftBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated
{
    if (_leftBarButtonItem != item) {
        _leftBarButtonItem = item;
        [[NSNotificationCenter defaultCenter] postNotificationName:UINavigationItemDidChange object:self];
    }
}

- (void)setLeftBarButtonItem:(UIBarButtonItem *)item
{
    [self setLeftBarButtonItem:item animated:NO];
}

- (void)setRightBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated
{
    if (_rightBarButtonItem != item) {
        _rightBarButtonItem = item;
        [[NSNotificationCenter defaultCenter] postNotificationName:UINavigationItemDidChange object:self];
    }
}

- (void)setRightBarButtonItem:(UIBarButtonItem *)item
{
    [self setRightBarButtonItem:item animated:NO];
}

- (void)setHidesBackButton:(BOOL)hidesBackButton animated:(BOOL)animated
{
    if (_hidesBackButton != hidesBackButton) {
        _hidesBackButton = hidesBackButton;
        [[NSNotificationCenter defaultCenter] postNotificationName:UINavigationItemDidChange object:self];
    }
}

- (void)setHidesBackButton:(BOOL)hidesBackButton
{
    [self setHidesBackButton:hidesBackButton animated:NO];
}

- (void)setTitle:(NSString *)title
{
    if (![_title isEqual:title]) {
        _title = [title copy];
        [[NSNotificationCenter defaultCenter] postNotificationName:UINavigationItemDidChange object:self];
    }
}

- (void)setPrompt:(NSString *)prompt
{
    if (![_prompt isEqual:prompt]) {
        _prompt = [prompt copy];
        [[NSNotificationCenter defaultCenter] postNotificationName:UINavigationItemDidChange object:self];
    }
}

- (void)setTitleView:(UIView *)titleView
{
    if (_titleView != titleView) {
        _titleView = titleView;
        [[NSNotificationCenter defaultCenter] postNotificationName:UINavigationItemDidChange object:self];
    }
}

@end
