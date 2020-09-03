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

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif
#ifdef HAVE_POLL_F
#include <poll.h>
#endif
#include <math.h>
#include <time.h>

#if GS_USE_LIBDISPATCH_RUNLOOP
#  define RL_INTEGRATE_DISPATCH 1
#  ifdef HAVE_DISPATCH_H
#    include <dispatch.h>
#  elif HAVE_DISPATCH_PRIVATE_H
#    include <dispatch/private.h>
#  elif HAVE_DISPATCH_DISPATCH_H
#    include <dispatch/dispatch.h>
#  endif
#endif


NSString * const NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";

static NSDate	*theFuture = nil;

@interface NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers;
@end

@implementation	NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers
{
    return _timedPerformers;
}
@end


/*
 *      Setup for inline operation of arrays.
 */

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
#if HAVE_DISPATCH_GET_MAIN_QUEUE_HANDLE_NP
    return (void*)(uintptr_t)dispatch_get_main_queue_handle_np();
#elif HAVE__DISPATCH_GET_MAIN_QUEUE_HANDLE_4CF
    return (void*)(uintptr_t)_dispatch_get_main_queue_handle_4CF();
#else
#error libdispatch missing main queue handle function
#endif
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
#if HAVE_DISPATCH_MAIN_QUEUE_DRAIN_NP
    dispatch_main_queue_drain_np();
#elif HAVE__DISPATCH_MAIN_QUEUE_CALLBACK_4CF
    _dispatch_main_queue_callback_4CF(NULL);
#else
#error libdispatch missing main queue callback function
#endif
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
    i = GSIArrayCount(watchers);
    if (i % 1000 == 0 && i > context->maxWatchers)
    {
        context->maxWatchers = i;
        NSLog(@"WARNING ... there are %u watchers scheduled in mode %@ of %@",
              i, mode, self);
    }
}

- (BOOL) _checkPerformers: (GSRunLoopCtxt*)context
{
    BOOL                  found = NO;
    
    if (context == nil) { return found;}
    
    GSIArray    performers = context->performers;
    unsigned    count = GSIArrayCount(performers);
    
    if (count > 0)
    {
        NSAutoreleasePool    *autoReleasePool = [NSAutoreleasePool new];
        GSRunLoopPerformer    *array[count];
        NSMapEnumerator    enumerator;
        GSRunLoopCtxt        *original;
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
        performers->count = 0;
        
        /* Remove the requests that we are about to fire from all modes.
         */
        original = context;
        enumerator = NSEnumerateMapTable(_contextMap);
        while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
        {
            /*
             如果, 这个 performer 被添加到了多个 Mode 里面, 那么这里要做一次数据的同步操作, 将他们都进行删除.
             因为接下来, 这个 performer 就要被调用了.
             */
            if (context != nil && context != original)
            {
                GSIArray    performers = context->performers;
                unsigned    tmpCount = GSIArrayCount(performers);
                
                while (tmpCount--)
                {
                    GSRunLoopPerformer    *p;
                    
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
        
        /*
         最后, 进行 performer 的 fire 调用.
         */
        for (i = 0; i < count; i++)
        {
            [array[i] fire];
            RELEASE(array[i]);
            IF_NO_GC([autoReleasePool emptyPool];)
        }
        [autoReleasePool drain];
    }
    
    /*
     found 可以理解为, 检查当前 runloop 有没有注册方法的调用. 可以理解为 src0, src1.
     */
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
#ifdef	HAVE_POLL_F
        _extra = NSZoneMalloc(NSDefaultMallocZone(), sizeof(pollextra));
        memset(_extra, '\0', sizeof(pollextra));
#endif
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
    }
    else
    {
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

/*
 处理触摸事件.
 进程间线程间通信.
 定时器处理.
 通知的异步发送.
 消息的异步发送.
 */
/**
 *  <p><code>NSRunLoop</code> instances handle various utility tasks that must
 *  be performed repetitively in an application, such as processing input
 *  events, listening for distributed objects communications, firing
 *  [NSTimer]s, and sending notifications and other messages
 *  asynchronously.</p>
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
    GSRunLoopThreadInfo	*info = GSRunLoopInfoForThread(aThread);
    NSRunLoop             *current = info->loop;
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

/*
 因为, Alloc 是真正的内存分配, 到了 Init, 一定是已经有了对象的内存存在了.
 这里将自身的引用计数进行--, 然后返回 nil 就可以了.
 */
- (id) init
{
    DESTROY(self);
    return nil;
}

- (NSString*) currentMode
{
    return _currentMode;
}

/*
 将 Timer 添加到 runloop, 只有添加到 runloop 的定时器才能发挥真正的作用.
 */
- (void) addTimer: (NSTimer*)timer forMode: (NSString*)mode
{
    /*
     首先做一下防卫式的检测工作.
     */
    if ([timer isKindOfClass: [NSTimer class]] == NO ||
        [timer isProxy] == YES) {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] not a valid timer",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if ([mode isKindOfClass: [NSString class]] == NO)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] not a valid mode",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    
    
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
    while (i-- > 0) {
        /*
         如果, 已经把 Timer 添加到了当前的 Mode 的 timer 数组里面了, 就不在做处理了.
         */
        if (timer == GSIArrayItemAtIndex(timers, i).obj)
        {
            return;
        }
    }
    /*
     addTimer 仅仅是把 timer 放到了 Mode 相关的数组里面, 到底这个 timer 什么时候开始 fire, 是在每个 runloop 的运营过程中处理的.
     */
    GSIArrayAddItem(timers, (GSIArrayItem)((id)timer));
    i = GSIArrayCount(timers);
    if (i % 1000 == 0 && i > context->maxTimers)
    {
        context->maxTimers = i;
    }
}



/* Ensure that the fire date has been updated either by the timeout handler
 * updating it or by incrementing it ourselves.<br />
 * Return YES if it was updated, NO if it was invalidated.
 
 将 timer 的 fireDate 更新为最新的触发时间.
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
            
            /* Just incrementing the date was insufficient to bring it to
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
        t->_date = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: ti];
    }
    return YES;
}

/*
 这里, 会进行时间源事件的触发操作.
 */
- (NSDate*) _limitDateForContext: (GSRunLoopCtxt *)context
{
    NSDate		*when = nil;
    NSAutoreleasePool     *arp = [NSAutoreleasePool new];
    GSIArray		timers = context->timers;
    NSTimeInterval	now;
    NSDate                *earliest;
    NSDate		*timerFireDate;
    NSTimer		*registeredTimer;
    NSTimeInterval	ti;
    NSTimeInterval	ei;
    unsigned              c;
    unsigned              i;
    
    ei = 0.0;	// Only needed to avoid compiler warning
    
    /*
     * Save current time so we don't keep redoing system call to
     * get it and so that we check timer fire dates against a known
     * value at the point when the method was called.
     * If we refetched the date after firing each timer, the time
     * taken in firing the timer could be large enough so we would
     * just keep firing the timer repeatedly and never return from
     * this method.
     */
    now = GSPrivateTimeNow();
    
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
        registeredTimer = GSIArrayItemAtIndex(timers, i).obj;
        if (timerInvalidated(registeredTimer) == NO)
        {
            timerFireDate = timerDate(registeredTimer);
            ti = [timerFireDate timeIntervalSinceReferenceDate];
            if (ti < now)
            {
                GSIArrayRemoveItemAtIndexNoRelease(timers, i);
                [registeredTimer fire]; // 时间源的真正的调用操作.
                GSPrivateNotifyASAP(_currentMode);
                IF_NO_GC([arp emptyPool];)
                if (updateTimer(registeredTimer, timerFireDate, now) == YES)
                {
                    /* Updated ... replace in array.
                     */
                    GSIArrayAddItemNoRetain(timers,
                                            (GSIArrayItem)((id)registeredTimer));
                }
                else
                {
                    /* The timer was invalidated, so we can
                     * release it as we aren't putting it back
                     * in the array.
                     */
                    RELEASE(registeredTimer);
                }
                break;
            }
        }
    }
    
    /* Now, find the earliest remaining timer date while removing
     * any invalidated timers.  We iterate from the end of the
     * array to minimise the amount of array alteration needed.
     */
    earliest = nil;
    i = GSIArrayCount(timers);
    while (i-- > 0)
    {
        registeredTimer = GSIArrayItemAtIndex(timers, i).obj;
        if (timerInvalidated(registeredTimer) == YES)
        {
            GSIArrayRemoveItemAtIndex(timers, i);
        }
        else
        {
            timerFireDate = timerDate(registeredTimer);
            ti = [timerFireDate timeIntervalSinceReferenceDate];
            if (earliest == nil || ti < ei)
            {
                earliest = timerFireDate;
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
        if (GSIArrayCount(context->watchers) > 0)
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
        NS_DURING
        {
            when = [self _limitDateForContext: context];
            _currentMode = savedMode;
        }
        NS_HANDLER
        {
            _currentMode = savedMode;
            [localException raise];
        }
        NS_ENDHANDLER
        
        NSDebugMLLog(@"NSRunLoop", @"limit date %f in %@",
                     nil == when ? 0.0 : [when timeIntervalSinceReferenceDate], mode);
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
 */
- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)limit_date
{
    GSRunLoopCtxt		*context;
    NSTimeInterval	ti = 0;
    int			timeout_ms;
    NSString		*savedMode = _currentMode;
    NSAutoreleasePool	*arp = [NSAutoreleasePool new];
    
    NSAssert(mode, NSInvalidArgumentException);
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
    
    NS_DURING
    {
        BOOL      done = NO;
        NSDate    *when;
        
        while (NO == done)
        {
            [arp emptyPool];
            when = [self _limitDateForContext: context];
            if (nil == when)
            {
                NSDebugMLLog(@"NSRunLoop",
                             @"no inputs or timers in mode %@", mode);
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
                [arp drain];
                NS_VOIDRETURN;
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
                    timeout_ms = INT_MAX;	// Far future.
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
    }
    NS_HANDLER
    {
        _currentMode = savedMode;
        [context endPoll];
        [_contextStack removeObjectIdenticalTo: context];
        [localException raise];
    }
    NS_ENDHANDLER
    NSDebugMLLog(@"NSRunLoop", @"accept I/P completed in %@", mode);
    [arp drain];
}

- (BOOL)runMode: (NSString*)mode beforeDate: (NSDate*)date {
    
    NSAutoreleasePool	*autoReleasePool = [NSAutoreleasePool new];
    NSString              *savedMode = _currentMode;
    GSRunLoopCtxt		*context;
    NSDate		*d;
    
    /*
     首先, 把 Notification 系统里面的通知进行异步发送.
     */
    GSPrivateNotifyASAP(mode);
    
    /* And process any performers scheduled in the loop (eg something from
     * another thread.
     */
    _currentMode = mode;
    context = NSMapGet(_contextMap, mode);
    [self _checkPerformers: context];
    _currentMode = savedMode;
    
    /* Find out how long we can wait before first limit date.
     * If there are no input sources or timers, return immediately.
     */
    d = [self limitDateForMode: mode];
    if (nil == d)
    {
        [autoReleasePool drain];
        return NO;
    }
    
    /* Use the earlier of the two dates we have (nil date is like distant past).
     */
    if (nil == date)
    {
        [self acceptInputForMode: mode beforeDate: nil];
    }
    else
    {
        /* Retain the date in case the firing of a timer (or some other event)
         * releases it.
         */
        d = [[d earlierDate: date] copy];
        [self acceptInputForMode: mode beforeDate: d];
        RELEASE(d);
    }
    
    [autoReleasePool drain];
    return YES;
}

- (void) run
{
    [self runUntilDate: theFuture];
}

- (void) runUntilDate: (NSDate*)date
{
    BOOL		mayDoMore = YES;
    
    /*
     runUntilDate 这个函数, 就是不断的调用 runMode beforeData 而已.
     */
    while (YES == mayDoMore) {
        mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date];
        if (nil == date ||
            [date timeIntervalSinceNow] <= 0.0)
        {
            mayDoMore = NO;
        }
    }
}

@end



/**
 * OpenStep-compatibility methods for [NSRunLoop].  These methods are also
 * all in OS X.
 */
@implementation	NSRunLoop (OPENSTEP)

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
    
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil)
        {
            GSIArray	performers = context->performers;
            unsigned	count = GSIArrayCount(performers);
            
            while (count--)
            {
                GSRunLoopPerformer	*p;
                
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
            GSIArray	performers = context->performers;
            unsigned	count = GSIArrayCount(performers);
            
            while (count--)
            {
                GSRunLoopPerformer	*p;
                
                p = GSIArrayItemAtIndex(performers, count).obj;
                if (p->target == target && sel_isEqual(p->selector, aSelector)
                    && (p->argument == argument || [p->argument isEqual: argument]))
                {
                    GSIArrayRemoveItemAtIndex(performers, count);
                }
            }
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

/**
 *  Configure event processing for acting as a server process for distributed
 *  objects.  (In the current implementation this is a no-op.)
 */
- (void) configureAsServer
{
    return;	/* Nothing to do here */
}

/*
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
    unsigned		modeCount = [modes count];
    
    if (modeCount > 0)
    {
        NSString			*modesArray[modeCount];
        GSRunLoopPerformer	*item;
        
        item = [[GSRunLoopPerformer alloc] initWithSelector: aSelector
                                                     target: target
                                                   argument: argument
                                                      order: order];
        if ([modes isProxy])
        {
            unsigned	i;
            
            for (i = 0; i < modeCount; i++)
            {
                modesArray[i] = [modes objectAtIndex: i];
            }
        }
        else
        {
            [modes getObjects: modesArray];
        }
        
        while (modeCount-- > 0)
        {
            NSString	*mode = modesArray[modeCount];
            unsigned	end;
            unsigned	i;
            GSRunLoopCtxt	*context;
            GSIArray	performers;
            
            context = NSMapGet(_contextMap, mode);
            if (context == nil)
            {
                context = [[GSRunLoopCtxt alloc] initWithMode: mode
                                                        extra: _extra];
                NSMapInsert(_contextMap, context->mode, context);
                RELEASE(context);
            }
            performers = context->performers;
            
            end = GSIArrayCount(performers);
            for (i = 0; i < end; i++)
            {
                GSRunLoopPerformer	*p;
                
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
        }
        RELEASE(item);
    }
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
