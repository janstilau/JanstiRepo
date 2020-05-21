#import "common.h"
#define	EXPOSE_NSRunLoop_IVARS	1
#define	EXPOSE_NSTimer_IVARS	1
#import "Foundation/NSMapTable.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSPort.h"
#import "Foundation/NSTimer.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSInvocation.h"
#import "GSRunLoopCtxt.h"
#import "GSRunLoopWatcher.h"
#import "GSStream.h"

#import "GSPrivate.h"

@interface GSRunLoopModeRelatedPerformer: NSObject
{
@public
    SEL       selector;
    id        target;
    id        argument;
    unsigned  order;
}

- (void) modeRelatedPerformerFire;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  order: (NSUInteger)order;
@end


NSString * const NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";

static NSDate	*theFuture = nil;

@interface NSObject (OptionalPortRunLoop)
- (void) getFds: (NSInteger*)fds count: (NSInteger*)count;
@end

#ifndef GSI_ARRAY_TYPES
#define GSI_ARRAY_TYPES       GSUNION_OBJ

#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]

#include "GNUstepBase/GSIArray.h"
#endif

static inline NSDate *timerDate(NSTimer *t)
{
    return t->_date;
}
static inline BOOL timerInvalidated(NSTimer *t)
{
    return t->_invalidated;
}

#ifdef RL_INTEGRATE_DISPATCH
@interface GSMainQueueDrainer : NSObject <RunLoopEvents>
+ (void*) mainQueueFileDescriptor;
@end

@implementation GSMainQueueDrainer
+ (void*) mainQueueFileDescriptor
{
    return (void*)(uintptr_t)dispatch_get_main_queue_handle_np();
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
    dispatch_main_queue_drain_np();
}
@end
#endif

@interface NSRunLoop (Private)

- (void) _addWatcher: (GSRunLoopWatcher*)item
             forMode: (NSString*)mode;
- (BOOL) _checkPerformers: (GSRunLoopCtxt*)context;
- (GSRunLoopWatcher*) _getWatcher: (void*)data
                             type: (RunLoopEventType)type
                          forMode: (NSString*)mode;
- (id) _init;
- (void) _removeWatcher: (void*)data
                   type: (RunLoopEventType)type
                forMode: (NSString*)mode;

@end

@implementation NSRunLoop (Private)

/* Add a watcher to the list for the specified mode.  Keep the list in
 limit-date order. */
- (void) _addWatcher: (GSRunLoopWatcher*) item forMode: (NSString*)mode
{
    GSRunLoopCtxt	*context;
    GSIArray	watchers;
    unsigned	i;
    
    context = NSMapGet(_contextMap, mode);
    if (context == nil)
    {
        context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
        NSMapInsert(_contextMap, context->mode, context);
        RELEASE(context);
    }
    watchers = context->watchers;
    GSIArrayAddItem(watchers, (GSIArrayItem)((id)item));
}


// 吊诡的是, 返回值没有作用.
// 这个函数, 是去执行每一个 context 注册的回调.
- (BOOL) _checkPerformers: (GSRunLoopCtxt*)context
{
    BOOL                  found = NO;
    if (!context) { return found; }
    GSIArray    performers = context->modeRelatedPerformers;
    unsigned    count = GSIArrayCount(performers);
    if (!count) { return NO; }
    
    NSAutoreleasePool    *arp = [NSAutoreleasePool new];
    GSRunLoopModeRelatedPerformer    *array[count];
    NSMapEnumerator    enumerator;
    GSRunLoopCtxt        *originalContext;
    void            *mode;
    unsigned        i;
    
    found = YES;
    
    /* We have to remove the performers before firing, so we copy
     * the pointers without releasing the objects, and then set
     * the performers to be empty.  The copied objects in 'array'
     * will be released later.
     */
    for (i = 0; i < count; i++)
    {
        array[i] = GSIArrayItemAtIndex(performers, i).obj;
    }
    performers->count = 0; // 只要在 context 的 performs , 代表着就是, 只要 context 有机会运行, 里面的内容都要进行.
    
    /* Remove the requests that we are about to fire from all modes.
     */
    originalContext = context;
    enumerator = NSEnumerateMapTable(_contextMap);
    // 下面的意思是, 同样的一个调用, 可能在不同的 mode 里面都进行了注册, 如果一个 mode 里面进行了调用, 要去除另一个 mode 的调用.
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil && context != originalContext)
        {
            GSIArray    performers = context->modeRelatedPerformers;
            unsigned    tmpCount = GSIArrayCount(performers);
            
            while (tmpCount--)
            {
                GSRunLoopModeRelatedPerformer    *p;
                
                p = GSIArrayItemAtIndex(performers, tmpCount).obj;
                for (i = 0; i < count; i++)
                {
                    if (p == array[i])
                    {
                        GSIArrayRemoveItemAtIndex(performers, tmpCount);
                    }
                }
            }
        }
    }
    NSEndMapTableEnumeration(&enumerator);
    
    /* Finally, fire the requests ands release them.
     */
    for (i = 0; i < count; i++)
    {
        [array[i] modeRelatedPerformerFire];
        RELEASE(array[i]);
        IF_NO_GC([arp emptyPool];)
    }// 真正的注册的回调的调用.
    [arp drain];
    return found;
}

/**
 * Locates a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (GSRunLoopWatcher*) _getWatcher: (void*)data
                             type: (RunLoopEventType)type
                          forMode: (NSString*)mode
{
    GSRunLoopCtxt	*context;
    
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    
    context = NSMapGet(_contextMap, mode);
    if (context != nil)
    {
        GSIArray	watchers = context->watchers;
        unsigned	i = GSIArrayCount(watchers);
        
        while (i-- > 0)
        {
            GSRunLoopWatcher	*info;
            
            info = GSIArrayItemAtIndex(watchers, i).obj;
            if (info->type == type && info->data == data)
            {
                return info;
            }
        }
    }
    return nil;
}

- (id) _init
{
    self = [super init];
    if (self != nil)
    {
        _contextStack = [NSMutableArray new];
        _contextMap = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
                                        NSObjectMapValueCallBacks, 0);
        _timedPerformers = [[NSMutableArray alloc] initWithCapacity: 8];
    }
    return self;
}

/**
 * Removes a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.
 */
- (void) _removeWatcher: (void*)data
                   type: (RunLoopEventType)type
                forMode: (NSString*)mode
{
    GSRunLoopCtxt	*context;
    
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    
    context = NSMapGet(_contextMap, mode);
    if (context != nil)
    {
        GSIArray	watchers = context->watchers;
        unsigned	i = GSIArrayCount(watchers);
        
        while (i-- > 0)
        {
            GSRunLoopWatcher	*info;
            
            info = GSIArrayItemAtIndex(watchers, i).obj;
            if (info->type == type && info->data == data)
            {
                info->_invalidated = YES;
                GSIArrayRemoveItemAtIndex(watchers, i);
            }
        }
    }
}

@end


@implementation NSRunLoop(GNUstepExtensions)

- (void) addEvent: (void*)data
             type: (RunLoopEventType)type
          watcher: (id<RunLoopEvents>)watcher
          forMode: (NSString*)mode
{
    GSRunLoopWatcher	*info;
    
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    
    info = [self _getWatcher: data type: type forMode: mode];
    
    if (info != nil && (id)info->receiver == (id)watcher)
    {
        /* Increment usage count for this watcher. */
        info->count++;
    } else {
        /* Remove any existing handler for another watcher. */
        [self _removeWatcher: data type: type forMode: mode];
        
        /* Create new object to hold information. */
        info = [[GSRunLoopWatcher alloc] initWithType: type
                                             receiver: watcher
                                                 data: data];
        /* Add the object to the array for the mode. */
        [self _addWatcher: info forMode: mode];
        RELEASE(info);		/* Now held in array.	*/
    }
}

- (void) removeEvent: (void*)data
                type: (RunLoopEventType)type
             forMode: (NSString*)mode
                 all: (BOOL)removeAll
{
    if (mode == nil)
    {
        mode = [self currentMode];
        if (mode == nil)
        {
            mode = NSDefaultRunLoopMode;
        }
    }
    if (removeAll)
    {
        [self _removeWatcher: data type: type forMode: mode];
    }
    else
    {
        GSRunLoopWatcher	*info;
        
        info = [self _getWatcher: data type: type forMode: mode];
        
        if (info)
        {
            if (info->count == 0)
            {
                [self _removeWatcher: data type: type forMode: mode];
            }
            else
            {
                info->count--;
            }
        }
    }
}

@end

/**
 *  <p><code>NSRunLoop</code> instances handle various utility tasks that must
 *  be performed repetitively in an application, such as processing input
 *  events, listening for distributed objects communications, firing
 *  [NSTimer]s, and sending notifications and other messages
 *  asynchronously.</p>
 *
 * <p>There is one run loop per thread in an application, which
 *  may always be obtained through the <code>+currentRunLoop</code> method
 *  (you cannot use -init or +new),
 *  however unless you are using the AppKit and the [NSApplication] class, the
 *  run loop will not be started unless you explicitly send it a
 *  <code>-run</code> message.</p>
 *
 * <p>At any given point, a run loop operates in a single <em>mode</em>, usually
 * <code>NSDefaultRunLoopMode</code>.  Other options include
 * <code>NSConnectionReplyMode</code>, and certain modes used by the AppKit.</p>
 */
@implementation NSRunLoop

+ (void) initialize
{
    if (self == [NSRunLoop class])
    {
        [self currentRunLoop];
        theFuture = RETAIN([NSDate distantFuture]);
        RELEASE([NSObject leakAt: &theFuture]);
    }
}

+ (NSRunLoop*) _runLoopForThread: (NSThread*) aThread
{
    GSThreadRelatedTaskContainer	*info = GSThreadCacheTasks(aThread);
    NSRunLoop             *current = info->loop; // runloop 是记录在 aThread 的 dictionary 里面的
    
    if (nil == current)
    {
        current = info->loop = [[self alloc] _init];
        /* If this is the main thread, set up a housekeeping timer.
         */
        if (nil != current && [GSCurrentThread() isMainThread] == YES) // 如果, 是主线程, 则增加了一个特殊的定时器, 具体干嘛的不清楚.
        {
            NSAutoreleasePool		*arp = [NSAutoreleasePool new];
            NSNotificationCenter	        *ctr;
            NSNotification		*not;
            NSInvocation		        *inv;
            NSTimer                       *timer;
            SEL			        sel;
            
            ctr = [NSNotificationCenter defaultCenter];
            not = [NSNotification notificationWithName: @"GSHousekeeping"
                                                object: nil
                                              userInfo: nil];
            sel = @selector(postNotification:);
            inv = [NSInvocation invocationWithMethodSignature:
                   [ctr methodSignatureForSelector: sel]];
            [inv setTarget: ctr];
            [inv setSelector: sel];
            [inv setArgument: &not atIndex: 2];
            [inv retainArguments];
            
            timer = [[NSTimer alloc] initWithFireDate: nil
                                             interval: 30.0
                                               target: inv
                                             selector: NULL
                                             userInfo: nil
                                              repeats: YES];
            [current addTimer: timer forMode: NSDefaultRunLoopMode];
            [arp drain];
        }
    }
    return current;
}

+ (NSRunLoop*) currentRunLoop
{
    return [self _runLoopForThread: nil];
}

+ (NSRunLoop*) mainRunLoop
{
    return [self _runLoopForThread: [NSThread mainThread]];
}

- (id) init
{
    DESTROY(self);
    return nil;
}

- (void) dealloc
{
#ifdef	HAVE_POLL_F
    if (_extra != 0)
    {
        pollextra	*e = (pollextra*)_extra;
        if (e->index != 0)
            NSZoneFree(NSDefaultMallocZone(), e->index);
        NSZoneFree(NSDefaultMallocZone(), e);
    }
#endif
    RELEASE(_contextStack);
    if (_contextMap != 0)
    {
        NSFreeMapTable(_contextMap);
    }
    RELEASE(_timedPerformers);
    [super dealloc];
}

/**
 * Returns the current mode of this runloop.  If the runloop is not running
 * then this method returns nil.
 */
- (NSString*) currentMode
{
    return _currentMode;
}


/**
 所以, timer 其实就是一个数据类, 他会在 runloop 的运行过程中不断地更新自己的时间. runloop 在每次运行的时候, 也会根据 timer 的 target, action 进行相应的调用.
 */
- (void) addTimer: (NSTimer*)timer
          forMode: (NSString*)mode
{
    GSRunLoopCtxt	*context;
    GSIArray	timers;
    unsigned      i;
    
    context = NSMapGet(_contextMap, mode);
    if (context == nil)
    {
        context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
        NSMapInsert(_contextMap, context->mode, context);
        RELEASE(context);
    }
    timers = context->timers;
    i = GSIArrayCount(timers);
    while (i-- > 0)
    {
        if (timer == GSIArrayItemAtIndex(timers, i).obj)
        {
            return;       /* Timer already present */
        }
    }
    GSIArrayAddItem(timers, (GSIArrayItem)((id)timer));
    i = GSIArrayCount(timers);
    if (i % 1000 == 0 && i > context->maxTimers)
    {
        context->maxTimers = i;
        NSLog(@"WARNING ... there are %u timers scheduled in mode %@ of %@",
              i, mode, self);
    }
}



/* Ensure that the fire date has been updated either by the timeout handler
 * updating it or by incrementing it ourselves.<br />
 * Return YES if it was updated, NO if it was invalidated.
 */
static BOOL
updateTimer(NSTimer *t, NSDate *d, NSTimeInterval now)
{
    if (timerInvalidated(t) == YES)
    {
        return NO;
    }
    if (timerDate(t) == d)
    {
        NSTimeInterval	ti = [d timeIntervalSinceReferenceDate];
        NSTimeInterval	increment = [t timeInterval];
        
        if (increment <= 0.0)
        {
            /* Should never get here ... unless a subclass is returning
             * a bad interval ... we return NO so that the timer gets
             * removed from the loop.
             */
            NSLog(@"WARNING timer %@ had bad interval ... removed", t);
            return NO;
        }
        
        ti += increment;	// Hopefully a single increment will do.
        
        if (ti < now)
        {
            NSTimeInterval	add;
            
            /* Just incrementing the date was insufficieint to bring it to
             * the current time, so we must have missed one or more fire
             * opportunities, or the fire date has been set on the timer.
             * If a fire date long ago has been set and the increment value
             * is really small, we might need to increment very many times
             * to get the new fire date.  To avoid looping for ages, we
             * calculate the number of increments needed and do them in one
             * go.
             */
            add = floor((now - ti) / increment);
            ti += (increment * add);
            if (ti < now)
            {
                ti += increment;
            }
        }
        RELEASE(t->_date);
        t->_date = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: ti]; // 更新 timer 的下一次触发的时间.
    }
    return YES;
}

// 通过 context 找到下一次定时器的出发点, 并且执行触发的 timer
- (NSDate*) _limitDateForContext: (GSRunLoopCtxt *)context
{
    NSDate		*when = nil;
    NSAutoreleasePool     *arp = [NSAutoreleasePool new];
    GSIArray		timers = context->timers;
    NSTimeInterval	now;
    NSDate                *earliest;
    NSDate		*timerNextDate;
    NSTimer		*aTimer;
    NSTimeInterval	ti;
    NSTimeInterval	ei;
    unsigned              c;
    unsigned              i;
    
    ei = 0.0;	// Only needed to avoid compiler warning
    now = SystemTimeInterval();
    
    /* Fire the oldest/first valid timer whose fire date has passed
     * and fire it.
     * We fire timers in the order in which they were added to the
     * run loop rather than in date order.  This prevents code
     * from blocking other timers by adding timers whose fire date
     * is some time in the past... we guarantee fair handling.
     */
    c = GSIArrayCount(timers);
    for (i = 0; i < c; i++)
    {
        aTimer = GSIArrayItemAtIndex(timers, i).obj;
        if (timerInvalidated(aTimer) == NO) // 如果 timer 没有被取消才执行, 因为 timer 很有可能自己取消了, 所以这里要进行判断.
        {
            timerNextDate = timerDate(aTimer);
            ti = [timerNextDate timeIntervalSinceReferenceDate];
            if (ti < now) // 已经到了触发的时间了.
            {
                GSIArrayRemoveItemAtIndexNoRelease(timers, i); // 删除正在等待的 tiemr.
                [aTimer fire];
                GSPrivateNotifyASAP(_currentMode);
                if (updateTimer(aTimer, timerNextDate, now) == YES) // 更新这个 timer 的下一次的触发实际.
                {
                    /* Updated ... replace in array.
                     */
                    GSIArrayAddItemNoRetain(timers,
                                            (GSIArrayItem)((id)aTimer));
                }
                else
                {
                    /* The timer was invalidated, so we can
                     * release it as we aren't putting it back
                     * in the array.
                     */
                    RELEASE(aTimer);
                }
                break;
            }
        }
    }
    
    /* Now, find the earliest remaining timer date while removing
     * any invalidated timers.  We iterate from the end of the
     * array to minimise the amount of array alteration needed.
     */
    // 更新所有失效的 timer 移除存储.
    earliest = nil;
    i = GSIArrayCount(timers);
    while (i-- > 0)
    {
        aTimer = GSIArrayItemAtIndex(timers, i).obj;
        if (timerInvalidated(aTimer) == YES)
        {
            GSIArrayRemoveItemAtIndex(timers, i);
        }
        else
        {
            timerNextDate = timerDate(aTimer);
            ti = [timerNextDate timeIntervalSinceReferenceDate];
            if (earliest == nil || ti < ei)
            {
                earliest = timerNextDate;
                ei = ti;
            }
        }
    }
    [arp drain];
    
    /* The earliest date of a valid timeout is retained in 'when'
     * and used as our limit date.
     */
    if (earliest != nil)
    {
        when = AUTORELEASE(RETAIN(earliest));
    }
    else
    {
        GSIArray		watchers = context->watchers;
        unsigned		i = GSIArrayCount(watchers);
        
        while (i-- > 0)
        {
            GSRunLoopWatcher	*w = GSIArrayItemAtIndex(watchers, i).obj;
            
            if (w->_invalidated == YES)
            {
                GSIArrayRemoveItemAtIndex(watchers, i);
            }
        }
        if (GSIArrayCount(context->watchers) > 0) // 如果还有 watcher, runloop 继续进行
        {
            when = theFuture;
        }
    }
    
    return when;
}

/**
 * Fires timers whose fire date has passed, and checks timers and limit dates
 * for input sources, determining the earliest time that any future timeout
 * becomes due.  Returns that date/time.<br />
 * Returns distant future if the loop contains no timers, just input sources
 * without timeouts.<br />
 * Returns nil if the loop contains neither timers nor input sources.
 *
 * Performs one pass through the run loop in the specified mode and returns the date at which the next timer is scheduled to fire.
 * return
 * The date at which the next timer is scheduled to fire, or nil if there are no input sources for this mode.
 */
- (NSDate*) limitDateForMode: (NSString*)mode
{
    GSRunLoopCtxt		*context;
    NSDate		*when = nil;
    
    context = NSMapGet(_contextMap, mode);
    if (context != nil)
    {
        NSString		*savedMode = _currentMode;
        
        _currentMode = mode;
        when = [self _limitDateForContext: context];
        _currentMode = savedMode;
    }
    return when;
}

/**
 * Listen for events from input sources.<br />
 * If limit_date is nil or in the past, then don't wait;
 * just fire timers, poll inputs and return, otherwise block
 * (firing timers when they are due) until input is available
 * or until the earliest limit date has passed (whichever comes first).<br />
 * If the supplied mode is nil, uses NSDefaultRunLoopMode.<br />
 * If there are no input sources or timers in the mode, returns immediately.
 *
 * Runs the loop once or until the specified date, accepting input only for the specified mode.

 // 这里应该会有 runloop 等待事件的机制.
 */
- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)limit_date
{
    GSRunLoopCtxt		*context;
    NSTimeInterval	ti = 0;
    int			timeout_ms;
    NSString		*savedMode = _currentMode;
    NSAutoreleasePool	*autoPool = [NSAutoreleasePool new];
    if (mode == nil)
    {
        mode = NSDefaultRunLoopMode;
    }
    context = NSMapGet(_contextMap, mode);
    if (nil == context)
    {
        return;
    }
    _currentMode = mode;
    
    [self _checkPerformers: context];
    
    BOOL      done = NO;
    NSDate    *when;
    while (NO == done)
    {
       [autoPool emptyPool];
       when = [self _limitDateForContext: context];
       if (nil == when) // 没有输入源,
       {
           GSPrivateNotifyASAP(_currentMode);
           GSPrivateNotifyIdle(_currentMode);
           /* Pause until the limit date or until we might have
            * a method to perform in this thread.
            */
           [GSRunLoopCtxt awakenedBefore: nil];
           [self _checkPerformers: context];
           GSPrivateNotifyASAP(_currentMode);
           [_contextStack removeObjectIdenticalTo: context];
           _currentMode = savedMode;
           [autoPool drain];
           return;
       }
       else
       {
           if (nil == limit_date)
           {
               when = nil;
           }
           else
           {
               when = [when earlierDate: limit_date];
           }
       }
       
       /* Find out how much time we should wait, and set SELECT_TIMEOUT. */
       if (nil == when || (ti = [when timeIntervalSinceNow]) <= 0.0)
       {
           /* Don't wait at all. */
           timeout_ms = 0;
       }
       else
       {
           /* Wait until the LIMIT_DATE. */
           if (ti >= INT_MAX / 1000.0)
           {
               timeout_ms = INT_MAX;    // Far future.
           }
           else
           {
               timeout_ms = (int)(ti * 1000.0);
           }
       }
       
       NSDebugMLLog(@"NSRunLoop",
                    @"accept I/P before %d millisec from now in %@",
                    timeout_ms, mode);
       
       if ([_contextStack indexOfObjectIdenticalTo: context] == NSNotFound)
       {
           [_contextStack addObject: context];
       }
       done = [context pollUntil: timeout_ms within: _contextStack];
       if (NO == done)
       {
           GSPrivateNotifyIdle(_currentMode);
           if (nil == limit_date || [limit_date timeIntervalSinceNow] <= 0.0)
           {
               done = YES;
           }
       }
       [self _checkPerformers: context];
       GSPrivateNotifyASAP(_currentMode);
       [context endPoll];
       
       /* Once a poll has been completed on a context, we can remove that
        * context from the stack even if it is actually polling at an outer
        * level of re-entrancy ... since the poll we have just done will
        * have handled any events that the outer levels would have wanted
        * to handle, and the polling for this context will be marked as
        * ended.
        */
       [_contextStack removeObjectIdenticalTo: context];
    }

    _currentMode = savedMode;
       
    [autoPool drain];
}


//  it returns after either the first input source is processed or limitDate is reached.
// A timer is not considered an input source and may fire multiple times while waiting for this method to return
- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)limitDate
{
    NSAutoreleasePool	*thisRunLoopPool = [NSAutoreleasePool new]; // 这里开启了一个新的自动释放池.
    NSString              *savedMode = _currentMode;
    GSRunLoopCtxt		*context;
    NSDate		*d;
    
    /* Process any pending notifications.
     */
    GSPrivateNotifyASAP(mode); // runloop 会在固定的时间调用, 通知中心会执行对应的通知方法.
    
    /* And process any performers scheduled in the loop (eg something from
     * another thread.
     */
    _currentMode = mode;
    context = NSMapGet(_contextMap, mode);
    [self _checkPerformers: context]; // 执行之前注册的回调.
    _currentMode = savedMode;
    
    /* Find out how long we can wait before first limit date.
     * If there are no input sources or timers, return immediately.
     */
    d = [self limitDateForMode: mode];// 这个函数会触发timer, 并且返回下一次的 timer.
    if (nil == d)
    {
        [thisRunLoopPool drain]; // 如果 d = nil, 就是没有定时器了, 自己原来注册的回调也都执行完了, 也没有观察者了
        // gun 的观察者的概念, 应该是包含了输入源.
        return NO;
    }
    
    /* Use the earlier of the two dates we have (nil date is like distant past).
     
     Runs the loop once or until the specified date, accepting input only for the specified mode.

     */
    if (nil == limitDate)
    {
        [self acceptInputForMode: mode beforeDate: nil];
    } else
    {
        /* Retain the date in case the firing of a timer (or some other event)
         * releases it.
         */
        d = [[d earlierDate: limitDate] copy];
        [self acceptInputForMode: mode beforeDate: d];
        RELEASE(d);
    }
    
    [thisRunLoopPool drain];
    return YES;
}

/**
 * Runs the loop in <code>NSDefaultRunLoopMode</code> by repeated calls to
 * -runMode:beforeDate: while there are still input sources.  Exits when no
 * more input sources remain.
 */
- (void) run
{
    [self runUntilDate: theFuture]; // theFutrue 导致, 时间不是退出的原因了.
}

/**
 Runs the loop once, blocking for input in the specified mode until a given date.
 */
- (void) runUntilDate: (NSDate*)date
{
    BOOL		mayDoMore = YES;
    
    /* Positive values are in the future. */
    while (YES == mayDoMore)
    {
        mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date]; // 如果 input source 没了
        if (nil == date || [date timeIntervalSinceNow] <= 0.0)
        {
            mayDoMore = NO; // 如果时间超过了, 退出循环.
        }
    }
}

@end






// ----------------------------  command 的包装  ----------------------------


/*
 *    The GSRunLoopPerformer class is used to hold information about
 *    messages which are due to be sent to objects once each runloop
 *    iteration has passed.
 // 为了封装 mode 相关的调用.
 */

@implementation GSRunLoopModeRelatedPerformer

- (void) dealloc
{
    RELEASE(target);
    RELEASE(argument);
    [super dealloc];
}

- (void) modeRelatedPerformerFire
{
    NS_DURING
    {
        [target performSelector: selector withObject: argument];
    }
    NS_HANDLER
    {
        NSLog(@"*** NSRunLoop ignoring exception '%@' (reason '%@') "
              @"raised during performSelector... with target %s(%s) "
              @"and selector '%s'",
              [localException name], [localException reason],
              GSClassNameFromObject(target),
              GSObjCIsInstance(target) ? "instance" : "class",
              sel_getName(selector));
    }
    NS_ENDHANDLER
}

- (id) initWithSelector: (SEL)aSelector
                 target: (id)aTarget
               argument: (id)anArgument
                  order: (NSUInteger)theOrder
{
    self = [super init];
    if (self)
    {
        selector = aSelector;
        target = RETAIN(aTarget);
        argument = RETAIN(anArgument);
        order = theOrder;
    }
    return self;
}

@end

/**
 * OpenStep-compatibility methods for [NSRunLoop].  These methods are also
 * all in OS X.
 */
@implementation	NSRunLoop (OPENSTEP)

/**
 * Sets up sending of aSelector to target with argument.<br />
 * The selector is sent before the next runloop iteration (unless
 * cancelled before then) in any of the specified modes.<br />
 * The target and argument objects are retained.<br />
 * The order value is used to determine the order in which messages
 * are sent if multiple messages have been set up. Messages with a lower
 * order value are sent first.<br />
 * If the modes array is empty, this method has no effect.
 */
- (void) performSelector: (SEL)aSelector
                  target: (id)target
                argument: (id)argument
                   order: (NSUInteger)order
                   modes: (NSArray*)modes
{
    unsigned        count = [modes count];
    if (!count) { return; }
    NSString *array[count];
    
    GSRunLoopModeRelatedPerformer *item =
    [[GSRunLoopModeRelatedPerformer alloc] initWithSelector: aSelector
                                                     target: target
                                                   argument: argument
                                                      order: order];
    [modes getObjects: array];
    while (count-- > 0)
    {
        NSString    *mode = array[count];
        unsigned    end;
        unsigned    i;
        GSRunLoopCtxt    *context;
        GSIArray    performers;
        
        context = NSMapGet(_contextMap, mode);
        if (context == nil)
        { //  如果没有懒加载, 那么这种判断插入的操作, 就会有很多. 或者, 如果有一个可以明显可以确定的初始化的时机, 可以将对应的代码写到那个位置.
            context = [[GSRunLoopCtxt alloc] initWithMode: mode
                                                    extra: _extra];
            NSMapInsert(_contextMap, context->mode, context);
            RELEASE(context);
        }
        performers = context->modeRelatedPerformers;
        
        end = GSIArrayCount(performers);
        for (i = 0; i < end; i++)
        {
            GSRunLoopModeRelatedPerformer    *p;
            
            p = GSIArrayItemAtIndex(performers, i).obj;
            if (p->order > order)
            {
                GSIArrayInsertItem(performers, (GSIArrayItem)((id)item), i);
                break;
            }
        }
        if (i == end)
        {
            GSIArrayInsertItem(performers, (GSIArrayItem)((id)item), i);
        }
        // 根据 order 插入到相应的位置.
    }
    RELEASE(item);
}

/**
 * Adds port to be monitored in given mode.
 */
- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode
{
    [self addEvent: (void*)port
              type: ET_RPORT
           watcher: (id<RunLoopEvents>)port
           forMode: (NSString*)mode];
}

/**
 * Cancels any perform operations set up for the specified target
 * in the receiver.
 */
- (void) cancelPerformSelectorsWithTarget: (id) target
{
    NSMapEnumerator	enumerator;
    GSRunLoopCtxt		*context;
    void			*mode;
    
    enumerator = NSEnumerateMapTable(_contextMap);
    
    
    // 遍历所有 mode 对应下的 ModeRelatedPerformer, 然后移除这个请求.
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil)
        {
            GSIArray	performers = context->modeRelatedPerformers;
            unsigned	count = GSIArrayCount(performers);
            
            while (count--)
            {
                GSRunLoopModeRelatedPerformer	*p;
                
                p = GSIArrayItemAtIndex(performers, count).obj;
                if (p->target == target)
                {
                    GSIArrayRemoveItemAtIndex(performers, count);
                }
            }
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

/**
 * Cancels any perform operations set up for the specified target
 * in the receiver, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
    cancelPerformSelector target 的升级版本, 这个和 timeRelatedPerformer 是类似的功能.
 */
- (void) cancelPerformSelector: (SEL)aSelector
                        target: (id) target
                      argument: (id) argument
{
    NSMapEnumerator	enumerator;
    GSRunLoopCtxt		*context;
    void			*mode;
    
    enumerator = NSEnumerateMapTable(_contextMap);
    
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil)
        {
            GSIArray	performers = context->modeRelatedPerformers;
            unsigned	count = GSIArrayCount(performers);
            
            while (count--)
            {
                GSRunLoopModeRelatedPerformer	*p;
                
                p = GSIArrayItemAtIndex(performers, count).obj;
                if (p->target == target &&
                    sel_isEqual(p->selector, aSelector) &&
                    (p->argument == argument || [p->argument isEqual: argument]))
                {
                    GSIArrayRemoveItemAtIndex(performers, count);
                }
            }
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

/**
 * Removes port to be monitored from given mode.
 * Ports are also removed if they are detected to be invalid.
 */
- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
    [self removeEvent: (void*)port type: ET_RPORT forMode: mode all: NO];
}

@end

@interface NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers;
@end

@implementation    NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers
{
    return _timedPerformers;
}
@end

/*
 * The GSTimedPerformer class is used to hold information about
 * messages which are due to be sent to objects at a particular time.
 */
@interface GSRunLoopTimeRelatedPerformer: NSObject
{
@public
    SEL        selector;
    id        target;
    id        argument;
    NSTimer    *timer;
}

- (void) timerPerformFire;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  delay: (NSTimeInterval)delay;
- (void) timerPerformerInvalidate;
@end

@implementation GSRunLoopTimeRelatedPerformer

- (void) dealloc
{
    [self finalize];
    TEST_RELEASE(timer);
    RELEASE(target);
    RELEASE(argument);
    [super dealloc];
}

- (void) timerPerformFire
{
    DESTROY(timer);
    [target performSelector: selector withObject: argument];
    [[[NSRunLoop currentRunLoop] _timedPerformers] removeObjectIdenticalTo: self];
}

- (void) finalize
{
    [self timerPerformerInvalidate];
}

- (id) initWithSelector: (SEL)aSelector
                 target: (id)aTarget
               argument: (id)anArgument
                  delay: (NSTimeInterval)delay
{
    self = [super init];
    if (self != nil)
    {
        selector = aSelector;
        target = RETAIN(aTarget);
        argument = RETAIN(anArgument);
        timer = [[NSTimer allocWithZone: NSDefaultMallocZone()]
                 initWithFireDate: nil
                 interval: delay
                 target: self
                 selector: @selector(timerPerformFire)
                 userInfo: nil
                 repeats: NO];
    }
    return self;
}

- (void) timerPerformerInvalidate
{
    if (timer != nil)
    {
        [timer invalidate];
        DESTROY(timer);
    }
}

@end

@implementation NSObject (TimedPerformers)

/*
 所以, cancelPreviousPerformRequestsWithTarget 这个方法, 就是在操作队列.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
{
    NSMutableArray    *perf = [[NSRunLoop currentRunLoop] _timedPerformers];
    unsigned        count = [perf count];
    
    if (count > 0)
    {
        GSRunLoopTimeRelatedPerformer    *array[count];
        [perf getObjects: array];
        while (count-- > 0)
        {
            GSRunLoopTimeRelatedPerformer    *p = array[count];
            if (p->target == target)
            {
                [p timerPerformerInvalidate];
                [perf removeObjectAtIndex: count];
            }
        }
        RELEASE(target);
    }
}

/*
 操作队列, 比上面仅仅进行 target 的比较, 还多了对于 target 和 sel 的比较.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
                                        selector: (SEL)aSelector
                                          object: (id)arg
{
    NSMutableArray    *perf = [[NSRunLoop currentRunLoop] _timedPerformers];
    unsigned        count = [perf count];
    
    if (count > 0)
    {
        GSRunLoopTimeRelatedPerformer    *array[count];
        [perf getObjects: array];
        while (count-- > 0)
        {
            GSRunLoopTimeRelatedPerformer    *p = array[count];
            
            if (p->target == target &&
                sel_isEqual(p->selector, aSelector) &&
                (p->argument == arg || [p->argument isEqual: arg]))
            {
                [p timerPerformerInvalidate];
                [perf removeObjectAtIndex: count];
            }
        }
    }
}


// 对于 afterDelay, 没有线程的调用. 直接是构造一个 NSTimer. GSTimedPerformer 是对于 timer 的一个包装.
// 之所以不直接进行 timer, 而是包装一个新的结构, 是因为上面有一个队列, 可以给使用者取消的权利.
- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
{
    NSRunLoop        *loop = [NSRunLoop currentRunLoop];
    GSRunLoopTimeRelatedPerformer    *item;
    
    item = [[GSRunLoopTimeRelatedPerformer alloc] initWithSelector: aSelector
                                               target: self
                                             argument: argument
                                                delay: seconds];
    [[loop _timedPerformers] addObject: item];
    RELEASE(item);
    [loop addTimer: item->timer forMode: NSDefaultRunLoopMode];
}

// 同样的, 这里也是一个简单的 Timer 的封装.

- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
                 inModes: (NSArray*)modes
{
    unsigned    count = [modes count];
    
    if (count > 0)
    {
        NSRunLoop        *loop = [NSRunLoop currentRunLoop];
        NSString        *marray[count];
        GSRunLoopTimeRelatedPerformer    *item;
        unsigned        i;
        
        item = [[GSRunLoopTimeRelatedPerformer alloc] initWithSelector: aSelector
                                                   target: self
                                                 argument: argument
                                                    delay: seconds];
        [[loop _timedPerformers] addObject: item];
        RELEASE(item);
        [modes getObjects: marray];
        for (i = 0; i < count; i++)
        {
            [loop addTimer: item->timer forMode: marray[i]];
        }
    }
}

@end
