#import "UIViewController.h"

@protocol UISplitViewControllerDelegate;

@interface UISplitViewController : UIViewController
@property (nonatomic, assign) id <UISplitViewControllerDelegate> delegate;
@property (nonatomic, copy) NSArray *viewControllers;
@end

@class UIPopoverController;

@protocol UISplitViewControllerDelegate <NSObject>
@optional
- (void)splitViewController:(UISplitViewController*)svc popoverController:(UIPopoverController*)pc willPresentViewController:(UIViewController *)aViewController;
- (void)splitViewController:(UISplitViewController*)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem*)barButtonItem forPopoverController:(UIPopoverController*)pc;
- (void)splitViewController:(UISplitViewController*)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)button;
@end
