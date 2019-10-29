#ifndef _GNUstep_H_NSGestureRecognizer
#define _GNUstep_H_NSGestureRecognizer

#import <Foundation/Foundation.h>
#import <AppKit/NSEvent.h>

@class NSView;

@interface NSGestureRecognizer : NSObject <NSCoding>
- (NSPoint)locationInView:(NSView *)view;
@end

@protocol NSGestureRecognizerDelegate <NSObject>
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSGestureRecognizer (NSGestureRecognizerDelegate)
#endif
- (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
- (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
- (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
- (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
- (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
@end

#endif
