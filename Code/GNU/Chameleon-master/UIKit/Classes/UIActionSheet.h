#import "UIView.h"
#import "UIInterface.h"

@class UIActionSheet, UITabBar, UIToolbar, UIBarButtonItem;

@protocol UIActionSheetDelegate <NSObject>
@optional
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)willPresentActionSheet:(UIActionSheet *)actionSheet;
- (void)didPresentActionSheet:(UIActionSheet *)actionSheet;
- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex;
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex;
- (void)actionSheetCancel:(UIActionSheet *)actionSheet;
@end

typedef NS_ENUM(NSInteger, UIActionSheetStyle) {
  UIActionSheetStyleAutomatic        = -1,
  UIActionSheetStyleDefault          = UIBarStyleDefault,
  UIActionSheetStyleBlackTranslucent = UIBarStyleBlackTranslucent,
  UIActionSheetStyleBlackOpaque      = UIBarStyleBlackOpaque,
};

@interface UIActionSheet : UIView
- (id)initWithTitle:(NSString *)title delegate:(id<UIActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;
- (NSInteger)addButtonWithTitle:(NSString *)title;

- (void)showInView:(UIView *)view;														// menu will appear wherever the mouse cursor is
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;		// if rect is CGRectNull, the menu will appear wherever the mouse cursor is
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated;

// these are not yet implemented:
- (void)showFromToolbar:(UIToolbar *)view;
- (void)showFromTabBar:(UITabBar *)view;
- (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) id<UIActionSheetDelegate> delegate;
@property (nonatomic, assign) UIActionSheetStyle actionSheetStyle;
@property (nonatomic, readonly, getter=isVisible) BOOL visible;
@property (nonatomic) NSInteger destructiveButtonIndex;
@property (nonatomic) NSInteger cancelButtonIndex;
@property (nonatomic, readonly) NSInteger firstOtherButtonIndex;
@property (nonatomic, readonly) NSInteger numberOfButtons;
@end
