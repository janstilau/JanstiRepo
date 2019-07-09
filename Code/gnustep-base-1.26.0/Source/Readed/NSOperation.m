#import "common.h"

#import "Foundation/NSLock.h"


#import "Foundation/NSOperation.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSThread.h"
#import "GNUstepBase/NSArray+GNUstepBase.h"
#import "GSPrivate.h"

#define	GSInternal	NSOperationInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSOperation)

static void     *isFinishedCtxt = (void*)"isFinished";
static void     *isReadyCtxt = (void*)"isReady";
static void     *queuePriorityCtxt = (void*)"queuePriority";

/* The pool of threads for 'non-concurrent' operations in a queue.
 */
#define	POOL	8

static NSArray	*empty = nil;

@interface	NSOperation (Private)
- (void) _finish;
@end

@implementation NSOperation

/* Handle all KVO manually
 */
+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
    return NO;
}

+ (void) initialize
{
    empty = [NSArray new];
}

/**
 The dependency is stored in operation, and the data
 */
- (void) addDependency: (NSOperation *)otherOperation
{
    /**
     * Guard firstly.
     */
    if (NO == [otherOperation isKindOfClass: [NSOperation class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] dependency is not an NSOperation",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (otherOperation == self)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] attempt to add dependency on self",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    [lock lock];
    if (dependencies == nil)
    {
        dependencies = [[NSMutableArray alloc] initWithCapacity: 5]; // have the default capacity for more efficient.
    }
    if (NSNotFound == [dependencies indexOfObjectIdenticalTo: otherOperation])
    {
        [self willChangeValueForKey: @"dependencies"]; // KVO manual
        [dependencies addObject: otherOperation];
        /* We only need to watch for changes if it's possible for them to
         * happen and make a difference.
         */
        if (NO == [otherOperation isFinished]
            && NO == [self isCancelled]
            && NO == [self isExecuting]
            && NO == [self isFinished])
        {
            /* Can change readiness if we are neither cancelled nor
             * executing nor finished.  So we need to observe for the
             * finish of the dependency.
             */
            /**
             * Opertaion observe the isFinished property of other operation.
             */
            [otherOperation addObserver: self
                             forKeyPath: @"isFinished"
                                options: NSKeyValueObservingOptionNew
                                context: isFinishedCtxt];
            if (ready == YES)
            {
                /* The new dependency stops us being ready ...
                 * change state.
                 */
                [self willChangeValueForKey: @"isReady"];
                ready = NO;
                [self didChangeValueForKey: @"isReady"];
            }
        }
        [self didChangeValueForKey: @"dependencies"];
    }
    [lock unlock];
}

- (void) cancel
{
    if (NO == cancelled && NO == [self isFinished])
    {
        [lock lock]; // double check
        if (NO == cancelled && NO == [self isFinished])
        {
            NS_DURING
            {
                [self willChangeValueForKey: @"isCancelled"];
                cancelled = YES;
                if (NO == ready)
                {
                    [self willChangeValueForKey: @"isReady"];
                    ready = YES;
                    [self didChangeValueForKey: @"isReady"];
                }
                [self didChangeValueForKey: @"isCancelled"];
            }
            NS_HANDLER
            {
                [lock unlock];
                NSLog(@"Problem cancelling operation: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [lock unlock];
    }
}

- (GSOperationCompletionBlock) completionBlock
{
    return completionBlock;
}

- (void) dealloc
{
    if (internal != nil)
    {
        NSOperation	*op;
        
        [self removeObserver: self forKeyPath: @"isFinished"];
        while ((op = [dependencies lastObject]) != nil)
        {
            [self removeDependency: op];
        }
        RELEASE(dependencies);
        RELEASE(cond);
        RELEASE(lock);
        GS_DESTROY_INTERNAL(NSOperation);
    }
    [super dealloc];
}

- (NSArray *) dependencies
{
    NSArray	*a;
    
    if (dependencies == nil)
    {
        a = empty;	// OSX return an empty array
    }
    else
    {
        [lock lock];
        a = [NSArray arrayWithArray: dependencies];
        [lock unlock];
    }
    return a;
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        GS_CREATE_INTERNAL(NSOperation);
        priority = NSOperationQueuePriorityNormal;
        threadPriority = 0.5;
        ready = YES;
        lock = [NSRecursiveLock new];
        [lock setName:
         [NSString stringWithFormat: @"lock-for-opqueue-%p", self]];
        cond = [[NSConditionLock alloc] initWithCondition: 0];
        [cond setName:
         [NSString stringWithFormat: @"cond-for-opqueue-%p", self]];
        // add observer self for self property. So the logic will be in one place
        [self addObserver: self
               forKeyPath: @"isFinished"
                  options: NSKeyValueObservingOptionNew
                  context: isFinishedCtxt];
    }
    return self;
}

- (BOOL) isCancelled
{
    return cancelled;
}

- (BOOL) isExecuting
{
    return executing;
}

- (BOOL) isFinished
{
    return finished;
}

- (BOOL) isConcurrent
{
    return concurrent;
}

- (BOOL) isReady
{
    return ready;
}

- (void) main;
{
    return;	// OSX default implementation does nothing
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    [lock lock];
    
    /* We only observe isFinished changes, and we can remove self as an
     * observer once we know the operation has finished since it can never
     * become unfinished.
     */
    [object removeObserver: self forKeyPath: @"isFinished"];
    
    if (object == self)
    {
        /* We have finished and need to unlock the condition lock so that
         * any waiting thread can continue.
         */
        [cond lock];
        [cond unlockWithCondition: 1];
        [lock unlock];
        return;
    }
    
    if (NO == ready)
    {
        NSEnumerator	*en;
        NSOperation	*op;
        
        /* Some dependency has finished (or been removed) ...
         * so we need to check to see if we are now ready unless we know we are.
         * This is protected by locks so that an update due to an observed
         * change in one thread won't interrupt anything in another thread.
         */
        en = [dependencies objectEnumerator];
        while ((op = [en nextObject]) != nil)
        {
            if (NO == [op isFinished])
                break;
        }
        /**
         * All dependency is finished, so change the ready state.
         */
        if (op == nil)
        {
            [self willChangeValueForKey: @"isReady"];
            ready = YES;
            [self didChangeValueForKey: @"isReady"];
        }
    }
    [lock unlock];
}

- (NSOperationQueuePriority) queuePriority
{
    return priority;
}

- (void) removeDependency: (NSOperation *)op
{
    [lock lock];
    NS_DURING
    {
        if (NSNotFound != [dependencies indexOfObjectIdenticalTo: op])
        {
            [op removeObserver: self forKeyPath: @"isFinished"];
            [self willChangeValueForKey: @"dependencies"];
            [dependencies removeObject: op];
            if (NO == ready)
            {
                /* The dependency may cause us to become ready ...
                 * fake an observation so we can deal with that.
                 */
                [self observeValueForKeyPath: @"isFinished"
                                    ofObject: op
                                      change: nil
                                     context: isFinishedCtxt];
            }
            [self didChangeValueForKey: @"dependencies"];
        }
    }
    NS_HANDLER
    {
        [lock unlock];
        NSLog(@"Problem removing dependency: %@", localException);
        return;
    }
    NS_ENDHANDLER
    [lock unlock];
}

- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock
{
    completionBlock = aBlock;
}

- (void) setQueuePriority: (NSOperationQueuePriority)pri
{
    if (pri <= NSOperationQueuePriorityVeryLow)
        pri = NSOperationQueuePriorityVeryLow;
    else if (pri <= NSOperationQueuePriorityLow)
        pri = NSOperationQueuePriorityLow;
    else if (pri < NSOperationQueuePriorityHigh)
        pri = NSOperationQueuePriorityNormal;
    else if (pri < NSOperationQueuePriorityVeryHigh)
        pri = NSOperationQueuePriorityHigh;
    else
        pri = NSOperationQueuePriorityVeryHigh;
    
    if (pri != priority)
    {
        [lock lock];
        if (pri != priority)
        {
            NS_DURING
            {
                [self willChangeValueForKey: @"queuePriority"];
                priority = pri;
                [self didChangeValueForKey: @"queuePriority"];
            }
            NS_HANDLER
            {
                [lock unlock];
                NSLog(@"Problem setting priority: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [lock unlock];
    }
}

- (void) setThreadPriority: (double)pri
{
    if (pri > 1) pri = 1;
    else if (pri < 0) pri = 0;
    threadPriority = pri;
}

- (void) start
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    double		prio = [NSThread  threadPriority];
    
    AUTORELEASE(RETAIN(self));	// Make sure we exist while running.
    [lock lock];
    NS_DURING
    {
        // guard check.
        if (YES == [self isExecuting])
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on executing operation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (YES == [self isFinished])
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on finished operation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (NO == [self isReady])
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on operation which is not ready",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (NO == executing)
        {
            [self willChangeValueForKey: @"isExecuting"];
            executing = YES;
            [self didChangeValueForKey: @"isExecuting"];
        }
    }
    NS_HANDLER
    {
        [lock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [lock unlock];
    
    NS_DURING
    {
        if (NO == [self isCancelled])
        {
            [NSThread setThreadPriority: threadPriority];
            [self main]; // here call main funcion for the business logic.
        }
    }
    NS_HANDLER
    {
        [NSThread setThreadPriority:  prio];
        [localException raise];
    }
    NS_ENDHANDLER;
    
    [self _finish];
    [pool release];
}

- (double) threadPriority
{
    return threadPriority;
}

- (void) waitUntilFinished
{
    [cond lockWhenCondition: 1];	// Wait for finish
    [cond unlockWithCondition: 1];	// Signal any other watchers
}
@end

@implementation	NSOperation (Private)
- (void) _finish
{
    /* retain while finishing so that we don't get deallocated when our
     * queue removes and releases us.
     */
    [self retain];
    [lock lock];
    if (NO == finished)
    {
        if (YES == executing)
        {
            [self willChangeValueForKey: @"isExecuting"];
            [self willChangeValueForKey: @"isFinished"];
            executing = NO;
            finished = YES;
            [self didChangeValueForKey: @"isFinished"];
            [self didChangeValueForKey: @"isExecuting"];
        }
        else
        {
            [self willChangeValueForKey: @"isFinished"];
            finished = YES;
            [self didChangeValueForKey: @"isFinished"];
        }
        if (NULL != completionBlock)
        {
            CALL_BLOCK_NO_ARGS(completionBlock);
        }
    }
    [lock unlock];
    [self release];
}

@end

#undef	GSInternal
#define	GSInternal	NSOperationQueueInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSOperationQueue)


@interface	NSOperationQueue (Private)
- (void) _execute;
- (void) _thread;
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context;
@end

static NSInteger	maxConcurrent = 200;	// Thread pool size

static NSComparisonResult
sortFunc(id o1, id o2, void *ctxt)
{
    NSOperationQueuePriority p1 = [o1 queuePriority];
    NSOperationQueuePriority p2 = [o2 queuePriority];
    
    if (p1 < p2) return NSOrderedDescending;
    if (p1 > p2) return NSOrderedAscending;
    return NSOrderedSame;
}

static NSString	*operationQueueKey = @"NSOperationQueue";
static NSOperationQueue *mainQueue = nil;

@implementation NSOperationQueue

+ (id) currentQueue
{
    if ([NSThread isMainThread])
    {
        return mainQueue;
    }
    return [[[NSThread currentThread] threadDictionary] objectForKey: operationQueueKey];
}

+ (void) initialize
{
    if (nil == mainQueue)
    {
        mainQueue = [self new];
    }
}

+ (id) mainQueue
{
    return mainQueue;
}

- (void) addOperation: (NSOperation *)op
{
    if (op == nil || NO == [op isKindOfClass: [NSOperation class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] object is not an NSOperation",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    [lock lock];
    if (NSNotFound == [operations indexOfObjectIdenticalTo: op]
        && NO == [op isFinished])
    {
        /**
         Operation Queue observe the opertion isReadyState to start a new operation.
         */
        [op addObserver: self
             forKeyPath: @"isReady"
                options: NSKeyValueObservingOptionNew
                context: isReadyCtxt];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [operations addObject: op];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
        if (YES == [op isReady])
        {
            /**
             Invoke observe mannuly.
             */
            [self observeValueForKeyPath: @"isReady"
                                ofObject: op
                                  change: nil
                                 context: isReadyCtxt];
        }
    }
    [lock unlock];
}

- (void) addOperations: (NSArray *)ops
     waitUntilFinished: (BOOL)shouldWait
{
    NSUInteger	total;
    NSUInteger	index;
    
    if (ops == nil || NO == [ops isKindOfClass: [NSArray class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] object is not an NSArray",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    total = [ops count];
    if (total > 0)
    {
        BOOL		invalidArg = NO;
        NSUInteger	toAdd = total;
        GS_BEGINITEMBUF(buf, total, id)
        
        [ops getObjects: buf];
        for (index = 0; index < total; index++)
        {
            NSOperation	*op = buf[index];
            
            if (NO == [op isKindOfClass: [NSOperation class]])
            {
                invalidArg = YES;
                toAdd = 0;
                break;
            }
            if (YES == [op isFinished])
            {
                buf[index] = nil;
                toAdd--;
            }
        }
        if (toAdd > 0)
        {
            [lock lock];
            [self willChangeValueForKey: @"operationCount"];
            [self willChangeValueForKey: @"operations"];
            for (index = 0; index < total; index++)
            {
                NSOperation	*op = buf[index];
                
                if (op == nil)
                {
                    continue;		// Not added
                }
                if (NSNotFound
                    != [operations indexOfObjectIdenticalTo: op])
                {
                    buf[index] = nil;	// Not added
                    toAdd--;
                    continue;
                }
                [op addObserver: self
                     forKeyPath: @"isReady"
                        options: NSKeyValueObservingOptionNew
                        context: isReadyCtxt];
                [operations addObject: op];
                if (NO == [op isReady])
                {
                    buf[index] = nil;	// Not yet ready
                }
            }
            [self didChangeValueForKey: @"operationCount"];
            [self didChangeValueForKey: @"operations"];
            for (index = 0; index < total; index++)
            {
                NSOperation	*op = buf[index];
                
                if (op != nil)
                {
                    [self observeValueForKeyPath: @"isReady"
                                        ofObject: op
                                          change: nil
                                         context: isReadyCtxt];
                }
            }
            [lock unlock];
        }
        GS_ENDITEMBUF()
        if (YES == invalidArg)
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] object at index %"PRIuPTR" is not an NSOperation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd),
             index];
        }
    }
    if (YES == shouldWait)
    {
        [self waitUntilAllOperationsAreFinished];
    }
}

- (void) cancelAllOperations
{
    [[self operations] makeObjectsPerformSelector: @selector(cancel)];
}

- (void) dealloc
{
    [self cancelAllOperations];
    DESTROY(operations);
    DESTROY(starting);
    DESTROY(waiting);
    DESTROY(name);
    DESTROY(cond);
    DESTROY(lock);
    GS_DESTROY_INTERNAL(NSOperationQueue);
    [super dealloc];
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        GS_CREATE_INTERNAL(NSOperationQueue);
        suspended = NO;
        count = NSOperationQueueDefaultMaxConcurrentOperationCount;
        operations = [NSMutableArray new];
        starting = [NSMutableArray new];
        waiting = [NSMutableArray new];
        lock = [NSRecursiveLock new];
        [lock setName:
         [NSString stringWithFormat: @"lock-for-op-%p", self]];
        cond = [[NSConditionLock alloc] initWithCondition: 0];
        [cond setName:
         [NSString stringWithFormat: @"cond-for-op-%p", self]];
    }
    return self;
}

- (BOOL) isSuspended
{
    return suspended;
}

- (NSInteger) maxConcurrentOperationCount
{
    return count;
}

- (NSString*) name
{
    NSString	*s;
    
    [lock lock];
    if (name == nil)
    {
        name
        = [[NSString alloc] initWithFormat: @"NSOperation %p", self];
    }
    s = [name retain];
    [lock unlock];
    return [s autorelease];
}

- (NSUInteger) operationCount
{
    NSUInteger	c;
    
    [lock lock];
    c = [operations count];
    [lock unlock];
    return c;
}

- (NSArray *) operations
{
    NSArray	*a;
    
    [lock lock];
    a = [NSArray arrayWithArray: operations];
    [lock unlock];
    return a;
}

- (void) setMaxConcurrentOperationCount: (NSInteger)cnt
{
    if (cnt < 0
        && cnt != NSOperationQueueDefaultMaxConcurrentOperationCount)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] cannot set negative (%"PRIdPTR") count",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd), cnt];
    }
    [lock lock];
    if (cnt != count)
    {
        [self willChangeValueForKey: @"maxConcurrentOperationCount"];
        count = cnt;
        [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
    [lock unlock];
    [self _execute];
}

- (void) setName: (NSString*)s
{
    if (s == nil) s = @"";
    [lock lock];
    if (NO == [name isEqual: s])
    {
        [self willChangeValueForKey: @"name"];
        [name release];
        name = [s copy];
        [self didChangeValueForKey: @"name"];
    }
    [lock unlock];
}

- (void) setSuspended: (BOOL)flag
{
    [lock lock];
    if (flag != suspended)
    {
        [self willChangeValueForKey: @"suspended"];
        suspended = flag;
        [self didChangeValueForKey: @"suspended"];
    }
    [lock unlock];
    [self _execute];
}

- (void) waitUntilAllOperationsAreFinished
{
    NSOperation	*op;
    
    [lock lock];
    while ((op = [operations lastObject]) != nil)
    {
        [op retain];
        [lock unlock];
        [op waitUntilFinished];
        [op release];
        [lock lock];
    }
    [lock unlock];
}
@end

@implementation	NSOperationQueue (Private)

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    /* We observe three properties in sequence ...
     * isReady (while we wait for an operation to be ready)
     * queuePriority (when priority of a ready operation may change)
     * isFinished (to see if an executing operation is over).
     */
    if (context == isFinishedCtxt)
    {
        [lock lock];
        executing--;
        [object removeObserver: self forKeyPath: @"isFinished"];
        [lock unlock];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [lock lock];
        [operations removeObjectIdenticalTo: object];
        [lock unlock];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
    }
    else if (context == queuePriorityCtxt || context == isReadyCtxt)
    {
        NSInteger pos;
        
        [lock lock];
        if (context == queuePriorityCtxt)
        {
            [waiting removeObjectIdenticalTo: object];
        }
        if (context == isReadyCtxt)
        {
            [object removeObserver: self forKeyPath: @"isReady"];
            [object addObserver: self
                     forKeyPath: @"queuePriority"
                        options: NSKeyValueObservingOptionNew
                        context: queuePriorityCtxt];
        }
        pos = [waiting insertionPosition: object
                           usingFunction: sortFunc
                                 context: 0];
        [waiting insertObject: object atIndex: pos];
        [lock unlock];
    }
    [self _execute];
}

- (void) _thread
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    
    [[[NSThread currentThread] threadDictionary] setObject: self
                                                    forKey: operationQueueKey];
    for (;;)
    {
        NSOperation	*op;
        NSDate		*when;
        BOOL		found;
        
        when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0];
        found = [cond lockWhenCondition: 1 beforeDate: when];
        RELEASE(when);
        if (NO == found)
        {
            break;	// Idle for 5 seconds ... exit thread.
        }
        
        if ([starting count] > 0)
        {
            op = RETAIN([starting objectAtIndex: 0]);
            [starting removeObjectAtIndex: 0];
        }
        else
        {
            op = nil;
        }
        
        if ([starting count] > 0)
        {
            // Signal any other idle threads,
            [cond unlockWithCondition: 1];
        }
        else
        {
            // There are no more operations starting.
            [cond unlockWithCondition: 0];
        }
        
        if (nil != op)
        {
            NS_DURING
            {
                NSAutoreleasePool	*opPool = [NSAutoreleasePool new];
                
                [NSThread setThreadPriority: [op threadPriority]];
                [op start];
                RELEASE(opPool);
            }
            NS_HANDLER
            {
                NSLog(@"Problem running operation %@ ... %@",
                      op, localException);
            }
            NS_ENDHANDLER
            [op _finish];
            RELEASE(op);
        }
    }
    
    [[[NSThread currentThread] threadDictionary] removeObjectForKey: operationQueueKey];
    [lock lock];
    threadCount--;
    [lock unlock];
    RELEASE(pool);
    [NSThread exit];
}

/* Check for operations which can be executed and start them.
 */
- (void) _execute
{
    NSInteger	max;
    
    [lock lock];
    
    max = [self maxConcurrentOperationCount];
    if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
        max = maxConcurrent;
    }
    
    // maxConcurrentOperationCount control whether to deque a opertioan to run. and opertion isConcurrent control should run in another thread.
    while (NO == [self isSuspended]
           && max > executing
           && [waiting count] > 0)
    {
        NSOperation	*op;
        
        /* Take the first operation from the queue and start it executing.
         * We set ourselves up as an observer for the operating finishing
         * and we keep track of the count of operations we have started,
         * but the actual startup is left to the NSOperation -start method.
         */
        op = [waiting objectAtIndex: 0];
        [waiting removeObjectAtIndex: 0];
        [op removeObserver: self forKeyPath: @"queuePriority"];
        [op addObserver: self
             forKeyPath: @"isFinished"
                options: NSKeyValueObservingOptionNew
                context: isFinishedCtxt];
        executing++;
        if (YES == [op isConcurrent])
        {
            [op start];
        }
        else
        {
            NSUInteger	pending;
            
            [cond lock];
            pending = [starting count];
            [starting addObject: op];
            
            /* Create a new thread if all existing threads are busy and
             * we haven't reached the pool limit.
             */
            if (0 == threadCount
                || (pending > 0 && threadCount < POOL))
            {
                threadCount++;
                [NSThread detachNewThreadSelector: @selector(_thread)
                                         toTarget: self
                                       withObject: nil];
            }
            /* Tell the thread pool that there is an operation to start.
             */
            [cond unlockWithCondition: 1];
        }
    }
    [lock unlock];
}

@end

