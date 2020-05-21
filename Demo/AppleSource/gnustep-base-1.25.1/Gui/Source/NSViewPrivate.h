#ifndef _GNUstep_H_NSViewPrivate
#define _GNUstep_H_NSViewPrivate

#import "AppKit/NSView.h"

@interface NSView (KeyViewLoop)
- (void) _setUpKeyViewLoopWithNextKeyView: (NSView *)nextKeyView;
- (void) _recursiveSetUpKeyViewLoopWithNextKeyView: (NSView *)nextKeyView;
@end

#endif // _GNUstep_H_NSViewPrivate
