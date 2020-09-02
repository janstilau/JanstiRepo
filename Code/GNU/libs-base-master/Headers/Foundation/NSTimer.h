#ifndef __NSTimer_h_GNUSTEP_BASE_INCLUDE
#define __NSTimer_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSDate.h>

@class NSTimer;
DEFINE_BLOCK_TYPE(GSTimerBlock, void, NSTimer*);

/*
 Timers work in conjunction with run loops.
 */

/*
 NSTime 仅仅是一个数据类, 真正的还是要到 Runloop 里面, 控制触发.
 */
@interface NSTimer : NSObject
{
@public
    NSDate 	 *_date;	/* Must be 1st - for NSRunLoop optimisation */
    BOOL		 _invalidated;	/* Must be 2nd - for NSRunLoop optimisation */
    BOOL		 _repeats;
    NSTimeInterval _interval;
    id		 _target;
    SEL		 _selector;
    id		 _info;
    GSTimerBlock   _block;
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

+ (NSTimer *) scheduledTimerWithTimeInterval: (NSTimeInterval)ti
                                     repeats: (BOOL)f
                                       block: (GSTimerBlock)block;

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

#if	OS_API_VERSION(MAC_OS_X_VERSION_10_12, GS_API_LATEST)  
- (instancetype) initWithFireDate: (NSDate *)date 
                         interval: (NSTimeInterval)interval
                          repeats: (BOOL)repeats
                            block: (GSTimerBlock)block;
#endif

@end

#endif	/* __NSTimer_h_GNUSTEP_BASE_INCLUDE */
