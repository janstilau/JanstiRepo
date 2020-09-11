#import "UIMenuController.h"
#import "UIApplicationAppKitIntegration.h"
#import "UIWindow+UIPrivate.h"
#import "UIScreenAppKitIntegration.h"
#import "UIKitView.h"
#import "UIMenuItem.h"
#import <AppKit/NSMenu.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSApplication.h>

NSString *const UIMenuControllerWillShowMenuNotification = @"UIMenuControllerWillShowMenuNotification";
NSString *const UIMenuControllerDidShowMenuNotification = @"UIMenuControllerDidShowMenuNotification";
NSString *const UIMenuControllerWillHideMenuNotification = @"UIMenuControllerWillHideMenuNotification";
NSString *const UIMenuControllerDidHideMenuNotification = @"UIMenuControllerDidHideMenuNotification";
NSString *const UIMenuControllerMenuFrameDidChangeNotification = @"UIMenuControllerMenuFrameDidChangeNotification";

@interface UIMenuController () <NSMenuDelegate>
@end

@implementation UIMenuController {
    NSMutableArray *_enabledMenuItems;
    NSMenu *_menu;
    CGPoint _menuLocation;
    BOOL _rightAlignMenu;
    UIWindow *_window;
}

+ (UIMenuController *)sharedMenuController
{
    static UIMenuController *controller = nil;
    return controller ?: (controller = [[UIMenuController alloc] init]);
}

+ (NSArray *)_defaultMenuItems
{
    static NSArray *items = nil;

    if (!items) {
        items = [[NSArray alloc] initWithObjects:
                 [[UIMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:)],
                 [[UIMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:)],
                 [[UIMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:)],
                 [[UIMenuItem alloc] initWithTitle:@"Delete" action:@selector(delete:)],
                 [[UIMenuItem alloc] initWithTitle:@"Select" action:@selector(select:)],
                 [[UIMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:)],
                 nil];
    }
    return items;
}


- (id)init
{
    if ((self=[super init])) {
        _enabledMenuItems = [[NSMutableArray alloc] init];
    }
    return self;
}

- (BOOL)isMenuVisible
{
    return (_menu != nil);
}

- (void)setMenuVisible:(BOOL)menuVisible animated:(BOOL)animated
{
    const BOOL wasVisible = [self isMenuVisible];

    if (menuVisible && !wasVisible) {
        [self update];

        if ([_enabledMenuItems count] > 0) {
            _menu = [[NSMenu alloc] initWithTitle:@""];
            [_menu setDelegate:self];
            [_menu setAutoenablesItems:NO];
            [_menu setAllowsContextMenuPlugIns:NO];
            
            for (UIMenuItem *item in _enabledMenuItems) {
                NSMenuItem *theItem = [[NSMenuItem alloc] initWithTitle:item.title action:@selector(_didSelectMenuItem:) keyEquivalent:@""];
                [theItem setTarget:self];
                [theItem setRepresentedObject:item];
                [_menu addItem:theItem];
            }

            _menuFrame.size = NSSizeToCGSize([_menu size]);
            _menuFrame.origin = _menuLocation;

            // this is offset so that it seems to be aligned on the right of the initial rect given to setTargetRect:inView:
            // I don't know if this is the best behavior yet or not.
            if (_rightAlignMenu) {
                _menuFrame.origin.x -= _menuFrame.size.width;
            }
            
            // note that presenting an NSMenu is apparently modal. so, to pretend that it isn't, exactly, I'll delay the presentation
            // of the menu to the start of a new runloop. At least that way, code that may be expecting to run right after setting the
            // menu to visible would still run before the menu itself shows up on screen. Of course behavior is going to be pretty different
            // after that point since if the app is assuming it can keep on doing normal runloop stuff, it ain't gonna happen.
            // but since clicks outside of an NSMenu dismiss it, there's not a lot a user can do to an app to change state when a menu
            // is up in the first place.
            [self performSelector:@selector(_presentMenu) withObject:nil afterDelay:0];
        }
    } else if (!menuVisible && wasVisible) {
        // make it unhappen
        if (animated) {
            [_menu cancelTracking];
        } else {
            [_menu cancelTrackingWithoutAnimation];
        }
        _menu = nil;
    }
}

- (void)setMenuVisible:(BOOL)visible
{
    [self setMenuVisible:visible animated:NO];
}

- (void)setTargetRect:(CGRect)targetRect inView:(UIView *)targetView
{
    // we have to have some window somewhere to use as a basis, so if there isn't a view, we'll just use the
    // keyWindow and go from there.
    _window = targetView.window ?: [UIApplication sharedApplication].keyWindow;

    // if the rect is CGRectNull, this is a fancy trigger in my OSX version to use the mouse position as the location for
    // the menu instead of the requiring a given rect. this is often a much better feel on OSX than the usual UIKit way is.
    if (CGRectIsNull(targetRect)) {
        _rightAlignMenu = NO;

        // get the mouse position and use that as the origin of our target rect
        NSPoint mouseLocation = [NSEvent mouseLocation];
        CGPoint screenPoint = [_window.screen convertPoint:NSPointToCGPoint(mouseLocation) fromScreen:nil];

        targetRect.origin = screenPoint;
        targetRect.size = CGSizeZero;
    } else {
        _rightAlignMenu = YES;

        // this will ultimately position the menu under the lower right of the given rectangle.
        // but it is then shifted in setMenuVisible:animated: so that the menu is right-aligned with the given rect.
        // this is all rather strange, perhaps, but it made sense at the time. we'll see if it does in practice.
        targetRect.origin.x += targetRect.size.width;
        targetRect.origin.y += targetRect.size.height;
        
        // first convert to screen coord, otherwise assume it already is, I guess, only the catch with targetView being nil
        // is that the assumed screen might not be the keyWindow's screen, which is what I'm going to be assuming here.
        // but bah - who cares? :)
        if (targetView) {
            targetRect = [_window convertRect:[_window convertRect:targetRect fromView:targetView] toWindow:nil];
        }
    }
    
    // only the origin is being set here. the size isn't known until the menu is created, which happens in setMenuVisible:animated:
    // so that's where _menuFrame will actually be configured for now.
    _menuLocation = targetRect.origin;
}

- (void)update
{
    UIApplication *app = [UIApplication sharedApplication];
    UIResponder *firstResponder = [app.keyWindow _firstResponder];
    NSArray *allItems = [[[self class] _defaultMenuItems] arrayByAddingObjectsFromArray:_menuItems];

    [_enabledMenuItems removeAllObjects];

    if (firstResponder) {
        for (UIMenuItem *item in allItems) {
            if ([firstResponder canPerformAction:item.action withSender:app]) {
                [_enabledMenuItems addObject:item];
            }
        }
    }
}

- (void)_presentMenu
{
    if (_menu && _window) {
        NSView *theNSView = _window.screen.UIKitView;
        if (theNSView) {
            [_menu popUpMenuPositioningItem:nil atLocation:NSPointFromCGPoint(_menuFrame.origin) inView:theNSView];
            UIApplicationInterruptTouchesInView(nil);
        }
    }
}

/*
 当 MenuItem 被点下之后, UIApplicaiton 会将对应的 SEL 发送到 Windown 的 FirstResponder. 这就是 _firstResponder 的意义所在, 一个特定的值, 在特定的时刻, 被获取然后处理事件.
 并且, UIKit 保证, 在一个 View 成为了 FirstResponder 只会, 会弹出它的 InputView.
 */
- (void)_didSelectMenuItem:(NSMenuItem *)sender
{
    // the docs say that it calls -update when it detects a touch in the menu, so I assume it does this to try to prevent actions being sent
    // that perhaps have just been un-enabled due to something else that happened since the menu first appeared. To replicate that, I'll just
    // call update again here to rebuild the list of allowed actions and then do one final check to make sure that the requested action has
    // not been disabled out from under us.
    [self update];
    
    UIApplication *app = [UIApplication sharedApplication];
    UIResponder *firstResponder = [app.keyWindow _firstResponder];
    UIMenuItem *selectedItem = [sender representedObject];

    // now spin through the enabled actions, make sure the selected one is still in there, and then send it if it is.
    if (firstResponder && selectedItem) {
        for (UIMenuItem *item in _enabledMenuItems) {
            if (item.action == selectedItem.action) {
                [app sendAction:item.action to:firstResponder from:app forEvent:nil];
                break;
            }
        }
    }
}

- (void)menuDidClose:(NSMenu *)menu
{
    if (menu == _menu) {
        _menu = nil;
    }
}


@end
