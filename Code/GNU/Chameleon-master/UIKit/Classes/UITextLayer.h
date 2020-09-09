#import <QuartzCore/CALayer.h>
#import <Foundation/Foundation.h>
#import "UIStringDrawing.h"

@class UICustomNSClipView, UICustomNSTextView, UIColor, UIFont, UIScrollView, UIWindow, UIView;

@protocol UITextLayerContainerViewProtocol <NSObject>
@required
- (UIWindow *)window;
- (CALayer *)layer;
- (BOOL)isHidden;
- (BOOL)isDescendantOfView:(UIView *)view;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;

// if any one of these doesn't exist, then scrolling of the NSClipView is disabled
@optional
- (BOOL)isScrollEnabled;
- (void)setContentOffset:(CGPoint)offset;
- (CGPoint)contentOffset;
- (void)setContentSize:(CGSize)size;
- (CGSize)contentSize;
@end

@protocol UITextLayerTextDelegate <NSObject>
@required
- (BOOL)_textShouldBeginEditing;
- (BOOL)_textShouldEndEditing;
- (void)_textDidEndEditing;
- (BOOL)_textShouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;

@optional
- (void)_textDidChange;
- (void)_textDidChangeSelection;
- (void)_textDidReceiveReturnKey;
@end

@interface UITextLayer : CALayer

- (id)initWithContainer:(UIView <UITextLayerContainerViewProtocol,UITextLayerTextDelegate> *)aView isField:(BOOL)isField;
- (void)setContentOffset:(CGPoint)contentOffset;
- (void)scrollRangeToVisible:(NSRange)range;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (CGSize)sizeThatFits:(CGSize)size;

@property (nonatomic, assign) NSRange selectedRange;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, assign) BOOL editable;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property (nonatomic, assign) UITextAlignment textAlignment;

@end
