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

NSString * const NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";

static NSDate	*theFuture = nil;
/*
 *	The GSRunLoopPerformer class is used to hold information about
 *	messages which are due to be sent to objects once each runloop
 *	iteration has passed.
 */
@interface GSRunLoopPerformer: NSObject
{
@public
    SEL		selector;
    id		target;
    id		argument;
    unsigned	order;
}

- (void) fireRunloopPerformer;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  order: (NSUInteger)order;
@end

@implementation GSRunLoopPerformer

- (void) dealloc
{
    [super dealloc];
}

- (void) fireRunloopPerformer
{
    [target performSelector: selector withObject: argument];
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

@interface NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers;
@end

@implementation	NSRunLoop (TimedPerformers)
- (NSMutableArray*) _timedPerformers
{
    return _timedPerformers;
}
@end

@interface GSRunloopDelayerPerformer: NSObject
{
@public
    SEL		selector;
    id		target;
    id		argument;
    NSTimer	*timer;
}

- (void) fire;
- (id) initWithSelector: (SEL)aSelector
                 target: (id)target
               argument: (id)argument
                  delay: (NSTimeInterval)delay;
- (void) invalidate;
@end

@implementation GSRunloopDelayerPerformer

- (void) fireTimer
{
    DESTROY(timer);
    [target performSelector: selector withObject: argument];
    /**
     * Not only invoke method. The runloop timedPerfromer must be updated.
     */
    [[[NSRunLoop currentRunLoop] _timedPerformers]
     removeObjectIdenticalTo: self];
}

- (void) finalize
{
    [self invalidate];
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
                 selector: @selector(fireTimer)
                 userInfo: nil
                 repeats: NO];
    }
    return self;
}

- (void) invalidate
{
    if (timer != nil)
    {
        [timer invalidate];
        DESTROY(timer);
    }
}

@end

static inline NSDate *timerDate(NSTimer *t)
{
    return t->_date;
}
static inline BOOL timerInvalidated(NSTimer *t)
{
    return t->_invalidated;
}

@implementation NSObject (TimedPerformers)

/*
 * Cancels any perform operations set up for the specified target
 * in the current run loop.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
{
    NSMutableArray	*perf = [[NSRunLoop currentRunLoop] _timedPerformers];
    unsigned		count = [perf count];
    
    if (count > 0)
    {
        GSRunloopDelayerPerformer	*array[count];
        [perf getObjects: array];
        while (count-- > 0)
        {
            GSRunloopDelayerPerformer	*p = array[count];
            if (p->target == target)
            {
                [p invalidate];
                [perf removeObjectAtIndex: count]; // Here copy the origin data, and the delete can be made in the origin one.
            }
        }
        RELEASE(target);
    }
}

/*
 * Cancels any perform operations set up for the specified target
 * in the current loop, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)target
                                        selector: (SEL)aSelector
                                          object: (id)arg
{
    NSMutableArray	*perf = [[NSRunLoop currentRunLoop] _timedPerformers];
    unsigned		count = [perf count];
    
    if (count > 0)
    {
        GSRunloopDelayerPerformer	*array[count];
        
        [perf getObjects: array];
        while (count-- > 0)
        {
            /**
             * Except for target, aSelector and arg will be check.
             */
            GSRunloopDelayerPerformer	*p = array[count];
            if (p->target == target && sel_isEqual(p->selector, aSelector)
                && (p->argument == arg || [p->argument isEqual: arg]))
            {
                [p invalidate];
                [perf removeObjectAtIndex: count];
            }
        }
    }
}

- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
{
    NSRunLoop		*loop = [NSRunLoop currentRunLoop];
    GSRunloopDelayerPerformer	*item;
    
    item = [[GSRunloopDelayerPerformer alloc] initWithSelector: aSelector
                                                        target: self
                                                      argument: argument
                                                         delay: seconds];
    [[loop _timedPerformers] addObject: item];
    RELEASE(item);
    // add timer for run.
    [loop addTimer: item->timer forMode: NSDefaultRunLoopMode];
}

- (void) performSelector: (SEL)aSelector
              withObject: (id)argument
              afterDelay: (NSTimeInterval)seconds
                 inModes: (NSArray*)modes
{
    unsigned	count = [modes count];
    
    if (count > 0)
    {
        NSRunLoop		*loop = [NSRunLoop currentRunLoop];
        NSString		*marray[count];
        GSRunloopDelayerPerformer	*item;
        unsigned		i;
        
        item = [[GSRunloopDelayerPerformer alloc] initWithSelector: aSelector
                                                            target: self
                                                          argument: argument
                                                             delay: seconds];
        [[loop _timedPerformers] addObject: item];
        [modes getObjects: marray];
        for (i = 0; i < count; i++)
        {
            [loop addTimer: item->timer forMode: marray[i]];
        }
    }
}

@end

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

@interface NSRunLoop (Private)

- (id) _init;
- (BOOL) runContextCachedPerformers: (GSRunLoopCtxt*)context;
- (void) _addWatcher: (GSRunLoopWatcher*)item
             forMode: (NSString*)mode;
- (GSRunLoopWatcher*) _getWatcher: (void*)data
                             type: (RunLoopEventType)type
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

- (BOOL) runContextCachedPerformers: (GSRunLoopCtxt*)context
{
    BOOL                  found = NO;
    
    if (context == nil) { return found; }
    
    GSIArray    performers = context->cachedPerformers;
    unsigned    count = GSIArrayCount(performers);
    if (!count) { return NO; }
    NSAutoreleasePool    *arp = [NSAutoreleasePool new]; // a new autoreleasePool
    
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
     
     So a task register into two modes will not be invoked in both modes.
     */
    original = context;
    enumerator = NSEnumerateMapTable(_contextMap);
    while (NSNextMapEnumeratorPair(&enumerator, &mode, (void**)&context))
    {
        if (context != nil && context != original)
        {
            GSIArray    performers = context->cachedPerformers;
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
    
    /* Finally, fire the requests ands release them.
     */
    for (i = 0; i < count; i++)
    {
        [array[i] fireRunloopPerformer];
        RELEASE(array[i]);
    }
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
    }
}

+ (NSRunLoop*) _runLoopForThread: (NSThread*) aThread
{
    GSRunLoopThreadRelatedInfo	*info = GSRunLoopInfoForThread(aThread);
    NSRunLoop             *current = info->loop;
    
    if (nil == current)
    {
        
        // Create runloop when get from a thread.
        current = info->loop = [[self alloc] _init];
        
        if (nil != current && [GSCurrentThread() isMainThread] == YES)
        {
            // do sth. Don't konw function, delete it.
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
 * Adds a timer to the loop in the specified mode.<br />
 * Timers are removed automatically when they are invalid.<br />
 */

/**
 * GSRunLoopCtxt is for dividing the mode realted tasks.
 */
- (void) addTimer: (NSTimer*)timer
          forMode: (NSString*)mode
{
    GSIArray	timers;
    unsigned      i;
    GSRunLoopCtxt *context = NSMapGet(_contextMap, mode);
    if (context == nil)
    {
        context = [[GSRunLoopCtxt alloc] initWithMode: mode extra: _extra];
        NSMapInsert(_contextMap, context->mode, context);
    }
    timers = context->cachedTimers;
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
        t->_date = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: ti];
    }
    return YES;
}

- (NSDate*) tryRunCachedTimers: (GSRunLoopCtxt *)context
{
    NSDate		*when = nil;
    NSAutoreleasePool     *arp = [NSAutoreleasePool new];
    GSIArray		timers = context->cachedTimers;
    NSTimeInterval	now;
    NSDate                *earliest;
    NSDate		*timeDate;
    NSTimer		*aTimer;
    NSTimeInterval	ti;
    NSTimeInterval	ei;
    unsigned              timerCount;
    unsigned              i;
    
    ei = 0.0;	// Only needed to avoid compiler warning
    now = GSPrivateTimeNow();
    
    /* Fire the oldest/first valid timer whose fire date has passed
     * and fire it.
     * We fire timers in the order in which they were added to the
     * run loop rather than in date order.  This prevents code
     * from blocking other timers by adding timers whose fire date
     * is some time in the past... we guarantee fair handling.
     */
    timerCount = GSIArrayCount(timers);
    for (i = 0; i < timerCount; i++)
    {
        aTimer = GSIArrayItemAtIndex(timers, i).obj;
        if (timerInvalidated(aTimer)) { continue; }
        
        timeDate = timerDate(aTimer);
        ti = [timeDate timeIntervalSinceReferenceDate];
        if (ti < now) // OK, the time has passed, so timer should fire here.
        {
            GSIArrayRemoveItemAtIndexNoRelease(timers, i);
            [aTimer fire];
            GSPrivateNotifyASAP(_currentMode);
            if (updateTimer(aTimer, timeDate, now) == YES)
            {
                /**
                * Timer should be fire because it's repeated
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
    
    /* Now, find the earliest remaining timer date while removing
     * any invalidated timers.  We iterate from the end of the
     * array to minimise the amount of array alteration needed.
     */
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
            timeDate = timerDate(aTimer);
            ti = [timeDate timeIntervalSinceReferenceDate];
            if (earliest == nil || ti < ei)
            {
                earliest = timeDate;
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
            when = [self tryRunCachedTimers: context];
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
    
    [self runContextCachedPerformers: context];
    
    NS_DURING
    {
        BOOL      done = NO;
        NSDate    *when;
        
        while (NO == done)
        {
            [arp emptyPool];
            
            when = [self tryRunCachedTimers: context]; // Here, all timer related code is run.
            
            if (nil == when)
            {
                GSPrivateNotifyASAP(_currentMode);
                GSPrivateNotifyIdle(_currentMode);
                /* Pause until the limit date or until we might have
                 * a method to perform in this thread.
                 */
                [GSRunLoopCtxt awakenedBefore: nil];
                [self runContextCachedPerformers: context];
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
            if ([_contextStack indexOfObjectIdenticalTo: context] == NSNotFound)
            {
                [_contextStack addObject: context];
            }
            done = [context pollUntil: timeout_ms within: _contextStack]; // Here should be sleep code.
            if (NO == done)
            {
                GSPrivateNotifyIdle(_currentMode);
                if (nil == limit_date || [limit_date timeIntervalSinceNow] <= 0.0)
                {
                    done = YES;
                }
            }
            [self runContextCachedPerformers: context];
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

- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)date
{
    NSAutoreleasePool	*releasePool = [NSAutoreleasePool new]; // every time, runloop create a autorelease pool.
    NSString              *savedMode = _currentMode;
    NSDate		*d;
    /* Process any pending notifications.
     */
    GSPrivateNotifyASAP(mode); // Notify related. It's a mechanism for notification.
    
    /* And process any performers scheduled in the loop (eg something from
     * another thread.
     */
    
    _currentMode = mode;
    
    GSRunLoopCtxt        *context;
    context = NSMapGet(_contextMap, mode);
    [self runContextCachedPerformers: context]; // If mode related ctx has tasks, perform those tasks first.
    
    _currentMode = savedMode;
    
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
    
    [releasePool drain];
    return YES;
}

/**
 * Runs the loop in <code>NSDefaultRunLoopMode</code> by repeated calls to
 * -runMode:beforeDate: while there are still input sources.  Exits when no
 * more input sources remain.
 */
- (void) run
{
    [self runUntilDate: theFuture];
}

/**
 * Runs the loop in <code>NSDefaultRunLoopMode</code> by repeated calls to
 * -runMode:beforeDate: while there are still input sources.  Exits when no
 * more input sources remain, or date is reached, whichever occurs first.
 */
- (void) runUntilDate: (NSDate*)date
{
    BOOL		mayDoMore = YES;
    
    /* Positive values are in the future. */
    while (YES == mayDoMore)
    {
        mayDoMore = [self runMode: NSDefaultRunLoopMode beforeDate: date];
        if (nil == date || [date timeIntervalSinceNow] <= 0.0)
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
            GSIArray	performers = context->cachedPerformers;
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
            GSIArray	performers = context->cachedPerformers;
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
    unsigned		count = [modes count];
    
    if (count <=  0) { return; }
    
    NSString            *array[count];
    GSRunLoopPerformer    *performer;
    performer = [[GSRunLoopPerformer alloc] initWithSelector: aSelector
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
        {
            context = [[GSRunLoopCtxt alloc] initWithMode: mode
                                                    extra: _extra];
            NSMapInsert(_contextMap, context->mode, context);
            RELEASE(context);
        }
        performers = context->cachedPerformers;
        
        end = GSIArrayCount(performers);
        for (i = 0; i < end; i++)
        {
            GSRunLoopPerformer    *p;
            
            p = GSIArrayItemAtIndex(performers, i).obj;
            if (p->order > order)
            {
                GSIArrayInsertItem(performers, (GSIArrayItem)((id)performer), i);
                break;
            }
        }
        if (i == end)
        {
            GSIArrayInsertItem(performers, (GSIArrayItem)((id)performer), i);
        }
        i = GSIArrayCount(performers);
        if (i % 1000 == 0 && i > context->maxPerformers)
        {
            context->maxPerformers = i;
            NSLog(@"WARNING ... there are %u performers scheduled"
                  @" in mode %@ of %@\n(Latest: [%@ %@])",
                  i, mode, self, NSStringFromClass([target class]),
                  NSStringFromSelector(aSelector));
        }
    }
    RELEASE(performer);
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
