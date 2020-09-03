//
//  GSRunLoopPerformer.h
//  Foundation
//
//  Created by JustinLau on 2020/9/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GSTimedPerformer: NSObject
{
@public
    SEL        selector;
    id        target;
    id        argument;
    NSTimer    *timer;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  delay: (NSTimeInterval)delay;
- (void) invalidate;

@end

/*
 GSRunLoopPerformer 里面, 包装的是下一次 runloop 应该调用方法.
 */
@interface GSRunLoopPerformer: NSObject
{
@public
    SEL        selector;
    id        target;
    id        argument;
    unsigned    order;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  order: (NSUInteger)order;
@end


/**
 * This class performs a dual function ...
 * <p>
 *   As a class, it is responsible for handling incoming events from
 *   the main runloop on a special inputFd.  This consumes any bytes
 *   written to wake the main runloop.<br />
 *   During initialisation, the default runloop is set up to watch
 *   for data arriving on inputFd.
 * </p>
 * <p>
 *   As instances, each  instance retains perform receiver and argument
 *   values as long as they are needed, and handles locking to support
 *   methods which want to block until an action has been performed.
 * </p>
 * <p>
 *   The initialize method of this class is called before any new threads
 *   run.
 * </p>
 */
@interface GSPerformHolder : NSObject
{
    id            receiver;
    id            argument;
    SEL            selector;
    NSConditionLock    *lock;        // Not retained.
    NSArray        *modes;
    BOOL                  invalidated;
@public
    NSException           *exception;
}
+ (GSPerformHolder*) newForReceiver: (id)r
                           argument: (id)a
                           selector: (SEL)s
                              modes: (NSArray*)m
                               lock: (NSConditionLock*)l;
- (void) fire;
- (void) invalidate;
- (BOOL) isInvalidated;
- (NSArray*) modes;
@end

NS_ASSUME_NONNULL_END
