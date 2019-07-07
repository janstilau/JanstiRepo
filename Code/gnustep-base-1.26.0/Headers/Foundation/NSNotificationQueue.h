#ifndef __NSNotificationQueue_h_GNUSTEP_BASE_INCLUDE
#define __NSNotificationQueue_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif
    
    @class NSArray;
    @class NSNotification;
    @class NSNotificationCenter;
    
    /*
     * Posting styles into notification queue
     */
    
    /**
     *  Enumeration of possible timings for distribution of notifications handed
     *  to an [NSNotificationQueue]:
     <example>
     {
     NSPostWhenIdle,	// post when runloop is idle
     NSPostASAP,		// post soon
     NSPostNow		// post synchronously
     }
     </example>
     */
    enum {
        NSPostWhenIdle = 1,
        NSPostASAP = 2,
        NSPostNow = 3
    };
    typedef NSUInteger NSPostingStyle;
    
    /**
     * Enumeration of possible ways to combine notifications when dealing with
     * [NSNotificationQueue]:
     <example>
     {
     NSNotificationNoCoalescing,       // don't combine
     NSNotificationCoalescingOnName,   // combine all registered with same name
     NSNotificationCoalescingOnSender  // combine all registered with same object
     }
     </example>
     */
    enum {
        NSNotificationNoCoalescing = 0,
        NSNotificationCoalescingOnName = 1,
        NSNotificationCoalescingOnSender = 2
    };
    typedef NSUInteger NSNotificationCoalescing;
    
    /*
     * NSNotificationQueue class
     */
    
    /**
     *  Structure used internally by [NSNotificationQueue].
     */
    struct _NSNotificationQueueList;
    
    @interface NSNotificationQueue : NSObject
{
#if	GS_EXPOSE(NSNotificationQueue)
@public
    NSNotificationCenter			*_center;
    struct _NSNotificationQueueList	*_asapQueue;
    struct _NSNotificationQueueList	*_idleQueue;
    NSZone				*_zone;
#endif
}

/* Creating Notification Queues */

+ (NSNotificationQueue*) defaultQueue;
- (id) initWithNotificationCenter: (NSNotificationCenter*)notificationCenter;

/* Inserting and Removing Notifications From a Queue */

- (void) dequeueNotificationsMatching: (NSNotification*)notification
                         coalesceMask: (NSUInteger)coalesceMask;

- (void) enqueueNotification: (NSNotification*)notification
                postingStyle: (NSPostingStyle)postingStyle;

- (void) enqueueNotification: (NSNotification*)notification
                postingStyle: (NSPostingStyle)postingStyle
                coalesceMask: (NSUInteger)coalesceMask
                    forModes: (NSArray*)modes;

@end
    
#if	defined(__cplusplus)
}
#endif

#endif /* __NSNotificationQueue_h_GNUSTEP_BASE_INCLUDE */
