#ifndef __NSTimer_h_GNUSTEP_BASE_INCLUDE
#define __NSTimer_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>
#import	<Foundation/NSDate.h>


/**
 * NSTimer is just a data class.It record the target and selector, If it's added into runloop, runloop is responsible to fire the timer in correct time.
 */
@interface NSTimer : NSObject
{
@public
    NSDate 	*_date;		/* Must be first - for NSRunLoop optimisation */
    BOOL		_invalidated;	/* Must be 2nd - for NSRunLoop optimisation */
    BOOL		_repeats;
    NSTimeInterval _interval;
    id		_target;
    SEL		_selector;
    id		_info;
}

/* Creating timer objects. */

+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
                                 invocation: (NSInvocation*)invocation
                                    repeats: (BOOL)f;
+ (NSTimer*) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
                                     target: (id)object
                                   selector: (SEL)selector
                                   userInfo: (id)info
                                    repeats: (BOOL)f;

+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
                        invocation: (NSInvocation*)invocation
                           repeats: (BOOL)f;
+ (NSTimer*) timerWithTimeInterval: (NSTimeInterval)ti
                            target: (id)object
                          selector: (SEL)selector
                          userInfo: (id)info
                           repeats: (BOOL)f;

- (void) fire;
- (NSDate*) fireDate;
- (void) invalidate;
- (id) userInfo;

#if	OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL) isValid;
- (NSTimeInterval) timeInterval;
#endif

#if	OS_API_VERSION(MAC_OS_X_VERSION_10_2, GS_API_LATEST)
- (id) initWithFireDate: (NSDate*)fd
               interval: (NSTimeInterval)ti
                 target: (id)object
               selector: (SEL)selector
               userInfo: (id)info
                repeats: (BOOL)f;
- (void) setFireDate: (NSDate*)fireDate;
#endif

@end


#endif	/* __NSTimer_h_GNUSTEP_BASE_INCLUDE */
