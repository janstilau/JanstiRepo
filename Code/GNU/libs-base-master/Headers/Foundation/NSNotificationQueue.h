#ifndef __NSNotificationQueue_h_GNUSTEP_BASE_INCLUDE
#define __NSNotificationQueue_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

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

/*
 
 Whereas a notification center distributes notifications when posted, notifications placed into the queue can be delayed until the end of the current pass through the run loop or until the run loop is idle.
 Duplicate notifications can be coalesced so that only one notification is sent although multiple notifications are posted.

 A notification queue maintains notifications in first in, first out (FIFO) order.
 When a notification moves to the front of the queue, the queue posts it to the notification center, which in turn dispatches the notification to all objects registered as observers.

 Every thread has a default notification queue, which is associated with the default notification center for the process. You can create your own notification queues and have multiple queues per center and thread.
 
 */

@interface NSNotificationQueue : NSObject
{
@public
    NSNotificationCenter			*_center;
    struct _NSNotificationQueueList	*_asapQueue;
    struct _NSNotificationQueueList	*_idleQueue;
    NSZone				*_zone;
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

#endif /* __NSNotificationQueue_h_GNUSTEP_BASE_INCLUDE */
