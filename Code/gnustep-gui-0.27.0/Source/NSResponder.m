#include "config.h"
#import <Foundation/NSCoder.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSInvocation.h>
#import "AppKit/NSResponder.h"
#import "AppKit/NSApplication.h"
#import "AppKit/NSMenu.h"
#import "AppKit/NSEvent.h"
#import "AppKit/NSGraphics.h"
#import "AppKit/NSHelpManager.h"
#import "AppKit/NSInputManager.h"

// 所以, 这个类最主要的, 其实就是 _next_responder 这个链表的维护, 而每一个子类, 都要在适当的时机, 维护这个链表

@implementation NSResponder
{
@public
    int            _interface_style;
    NSResponder        *_next_responder;
    
    /*
     Due to interface brain-damage, both NSResponder and NSMenuView have -menu
     and -setMenu: methods, but for different menus. Thus, to prevent (future,
     there have already been some) problems and confusion, this ivar is
     private (iow, it can't be accidentally used in NSMenuView).
     */
    NSMenu                *_menu;
}


/*
 * Class methods
 */
+ (void) initialize
{
    if (self == [NSResponder class])
    {
        [self setVersion: 1];
    }
}

/*
 * Managing the next responder
 */
- (NSResponder*) nextResponder
{
    return _next_responder;
}

- (void) setNextResponder: (NSResponder*)aResponder
{
    _next_responder = aResponder;
}

/**
 * Returns YES if the receiver is able to become the first responder,
 * NO otherwise.
 */
- (BOOL) acceptsFirstResponder
{
    return NO;
}

- (BOOL) becomeFirstResponder
{
    return YES;
}

- (BOOL) resignFirstResponder
{
    return YES;
}

/*
 * Aid event processing
 */
- (BOOL) performKeyEquivalent: (NSEvent*)theEvent
{
    return NO;
}

/**
 * If the receiver responds to anAction, it performs that method with
 * anObject as its argument, discards any return value, and return YES.<br />
 * Otherwise, the next responder in the chain is asked to perform
 * anAction and the result of that is returned.<br />
 * If no responder in the chain is able to respond to anAction, then
 * NO is returned.
 */
- (BOOL) tryToPerform: (SEL)anAction with: (id)anObject
{
    /* Can we perform the action -then do it */
    if ([self respondsToSelector: anAction])
    {
        IMP actionIMP = [self methodForSelector: anAction];
        if (0 != actionIMP)
        {
            return YES;
        }
        return YES;
    }
    else
    {
        /* If we cannot perform then try the next responder */
        if (!_next_responder)
            return NO;
        else
            return [_next_responder tryToPerform: anAction with: anObject];
    }
}

- (void) flushBufferedKeyEvents
{
}

- (void) doCommandBySelector:(SEL)aSelector
{
    if (![self tryToPerform: aSelector with: nil])
    {
        NSBeep();
    }
}

- (void) insertText: (id)aString
{
    if (_next_responder)
        [_next_responder insertText: aString];
    else
    {
        NSBeep ();
    }
}


/*
 这里, 应该就是事件处理的所有的默认实现. 就是进行简单的传递过程.
 */
- (void) flagsChanged: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder flagsChanged: theEvent];
    else
        [self noResponderFor: @selector(flagsChanged:)];
}

- (void) helpRequested: (NSEvent*)theEvent
{
    if ([[NSHelpManager sharedHelpManager]
         showContextHelpForObject: self
         locationHint: [theEvent locationInWindow]] == NO)
    {
        if (_next_responder)
        {
            [_next_responder helpRequested: theEvent];
            return;
        }
    }
    [NSHelpManager setContextHelpModeActive: NO];
}

- (void) keyDown: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder keyDown: theEvent];
    else
        [self noResponderFor: @selector(keyDown:)];
}

- (void) keyUp: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder keyUp: theEvent];
    else
        [self noResponderFor: @selector(keyUp:)];
}

- (void) otherMouseDown: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder otherMouseDown: theEvent];
    else
        [self noResponderFor: @selector(otherMouseDown:)];
}

- (void) otherMouseDragged: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder otherMouseDragged: theEvent];
    else
        [self noResponderFor: @selector(otherMouseDragged:)];
}

- (void) otherMouseUp: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder otherMouseUp: theEvent];
    else
        [self noResponderFor: @selector(otherMouseUp:)];
}

- (void) mouseDown: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder mouseDown: theEvent];
    else
        [self noResponderFor: @selector(mouseDown:)];
}

- (void) mouseDragged: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder mouseDragged: theEvent];
    else
        [self noResponderFor: @selector(mouseDragged:)];
}

- (void) mouseEntered: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder mouseEntered: theEvent];
    else
        [self noResponderFor: @selector(mouseEntered:)];
}

- (void) mouseExited: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder mouseExited: theEvent];
    else
        [self noResponderFor: @selector(mouseExited:)];
}

- (void) mouseMoved: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder mouseMoved: theEvent];
    else
        [self noResponderFor: @selector(mouseMoved:)];
}

- (void) mouseUp: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder mouseUp: theEvent];
    else
        [self noResponderFor: @selector(mouseUp:)];
}

- (void) noResponderFor: (SEL)eventSelector
{
    /* Only beep for key down events */
    if (sel_isEqual(eventSelector, @selector(keyDown:)))
        NSBeep();
}

- (void) rightMouseDown: (NSEvent*)theEvent
{
    if (_next_responder != nil)
        [_next_responder rightMouseDown: theEvent];
    else
        [self noResponderFor: @selector(rightMouseDown:)];
}

- (void) rightMouseDragged: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder rightMouseDragged: theEvent];
    else
        [self noResponderFor: @selector(rightMouseDragged:)];
}

- (void) rightMouseUp: (NSEvent*)theEvent
{
    if (_next_responder)
        [_next_responder rightMouseUp: theEvent];
    else
        [self noResponderFor: @selector(rightMouseUp:)];
}

- (void) scrollWheel: (NSEvent *)theEvent
{
    if (_next_responder)
        [_next_responder scrollWheel: theEvent];
    else
        [self noResponderFor: @selector(scrollWheel:)];
}

/*
 * Services menu support
 */
- (id) validRequestorForSendType: (NSString*)typeSent
                      returnType: (NSString*)typeReturned
{
    if (_next_responder)
        return [_next_responder validRequestorForSendType: typeSent
                                               returnType: typeReturned];
    else
        return nil;
}

- (NSMenu*) menu
{
    return _menu;
}

- (void) setMenu: (NSMenu*)aMenu
{
    ASSIGN(_menu, aMenu);
}

- (NSUndoManager*) undoManager
{
    if (_next_responder)
        return [_next_responder undoManager];
    else
        return nil;
}

- (BOOL) shouldBeTreatedAsInkEvent: (NSEvent *)theEvent
{
    return NO;
}

- (BOOL)presentError:(NSError *)error
{
    error = [self willPresentError: error];
    
    if (_next_responder)
    {
        return [_next_responder presentError: error];
    }
    else
    {
        return [NSApp presentError: error];
    }
}

- (void)presentError:(NSError *)error
      modalForWindow:(NSWindow *)window
            delegate:(id)delegate 
  didPresentSelector:(SEL)sel
         contextInfo:(void *)context
{
    error = [self willPresentError: error];
    if (_next_responder)
    {
        [_next_responder presentError: error
                       modalForWindow: window
                             delegate: delegate
                   didPresentSelector: sel
                          contextInfo: context];
    }
    else
    {
        [NSApp presentError: error
             modalForWindow: window
                   delegate: delegate
         didPresentSelector: sel
                contextInfo: context];
    }
}

- (NSError *) willPresentError: (NSError *)error
{
    return error;
}

@end
