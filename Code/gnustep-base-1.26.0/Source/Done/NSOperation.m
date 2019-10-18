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

static void     *isFinishedCtxt = (void*)"isFinished";
static void     *isReadyCtxt = (void*)"isReady";
static void     *queuePriorityCtxt = (void*)"queuePriority";

/* The pool of threads for 'non-concurrent' operations in a queue.
 */
#define	POOL	8

static NSArray	*emptyDependcy = nil;

@interface	NSOperation (Private)
- (void) _finish;
@end

@implementation NSOperation

// 因为这个类的操作, 会在各个线程里面运行, 所以这个类的操作都进行了加锁.

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
    /* Handle all KVO manually
     */
    return NO;
}

+ (void) initialize
{
    emptyDependcy = [NSArray new];
}

- (void) addDependency: (NSOperation *)target
{
    // 先是一些防卫式的判断.
    if (NO == [target isKindOfClass: [NSOperation class]])
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] dependency is not an NSOperation",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (target == self)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@] attempt to add dependency on self",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    // 在前面的防卫式判断之后, 后面的操作都要进行加锁的处理.
    [self->operationLock lock];
    if (self->dependencies == nil)
    {
        self->dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
    }
    NS_DURING
    {
        // 自己的依赖会变, 这里手动的通知给外界, 如果依赖对象还没有执行, 并且可执行, 自己的 ready 状态也会为 NO, 通知给外界.
        // operation 本身要检查依赖对象的 isFinished 的值, 用来更新自己的 isReady 的状态.
        if (NSNotFound == [self->dependencies indexOfObjectIdenticalTo: target])
        {
            [self willChangeValueForKey:@"dependencies"];
            [self->dependencies addObject: target];
            /* We only need to watch for changes if it's possible for them to
             * happen and make a difference.
             */
            if (NO == [target isFinished]
                && NO == [self isCancelled]
                && NO == [self isExecuting]
                && NO == [self isFinished])
            {
                /* Can change readiness if we are neither cancelled nor
                 * executing nor finished.  So we need to observe for the
                 * finish of the dependency.
                 */
                [target addObserver: self
                     forKeyPath: @"isFinished"
                        options: NSKeyValueObservingOptionNew
                        context: isFinishedCtxt]; // 如果依赖一个 opertaion, 那么应该监听它的finish的状态, 然后更改自己的 ready 的状态.
                if (self->ready == YES)
                {
                    /* The new dependency stops us being ready ...
                     * change state.
                     */
                    [self willChangeValueForKey: @"isReady"];
                    self->ready = NO; // 有了新的依赖, 然后自己的 ready 就改为 NO, 在依赖finish完成之后再改变.
                    [self didChangeValueForKey: @"isReady"];
                }
            }
            [self didChangeValueForKey: @"dependencies"];
        }
    }
    NS_HANDLER
    {
        [self->operationLock unlock];
        NSLog(@"Problem adding dependency: %@", localException);
        return;
    }
    NS_ENDHANDLER
    [self->operationLock unlock];
}

- (void) cancel
{
    if (NO == self->cancelled && NO == [self isFinished])
    {
        [self->operationLock lock];
        if (NO == self->cancelled && NO == [self isFinished]) // double check
        {
            NS_DURING
            {
                [self willChangeValueForKey: @"isCancelled"]; // 改变自己的 cancel 状态. 改变自己的 ready 状态
                self->cancelled = YES;
                if (NO == self->ready)
                {
                    // A Boolean value indicating whether the operation can be performed now.
                    [self willChangeValueForKey: @"isReady"];
                    self->ready = YES;
                    [self didChangeValueForKey: @"isReady"];
                }
                [self didChangeValueForKey: @"isCancelled"];
            }
            NS_HANDLER
            {
                [self->operationLock unlock];
                NSLog(@"Problem cancelling operation: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [self->operationLock unlock];
    }
}

- (GSOperationCompletionBlock) completionBlock
{
    return self->completionBlock;
}

- (void) dealloc
{
    if (self != nil)
    {
        NSOperation	*op;
        
        [self removeObserver: self forKeyPath: @"isFinished"];
        while ((op = [self->dependencies lastObject]) != nil)
        {
            [self removeDependency: op];
        }
        RELEASE(self->dependencies);
        RELEASE(self->operationCondition);
        RELEASE(self->operationLock);
    }
    [super dealloc];
}

- (NSArray *) dependencies // 复制一份, 没有把自己的值传递出去.
{
    NSArray	*a;
    
    if (self->dependencies == nil)
    {
        a = emptyDependcy;	// OSX return an empty array
    }
    else
    {
        [self->operationLock lock];
        a = [NSArray arrayWithArray: self->dependencies];
        [self->operationLock unlock];
    }
    return a;
}

- (id) init
{
    self->priority = NSOperationQueuePriorityNormal;
    self->threadPriority = 0.5;
    self->ready = YES;
    
    self->operationLock = [NSRecursiveLock new];
    [self->operationLock setName:
     [NSString stringWithFormat: @"lock-for-opqueue-%p", self]];
    
    self->operationCondition = [[NSConditionLock alloc] initWithCondition: 0];
    [self->operationCondition setName:
     [NSString stringWithFormat: @"cond-for-opqueue-%p", self]];
    
    [self addObserver: self
           forKeyPath: @"isFinished"
              options: NSKeyValueObservingOptionNew
              context: isFinishedCtxt];
    return self;
}

- (BOOL) isCancelled
{
    return self->cancelled;
}

- (BOOL) isExecuting
{
    return self->executing;
}

- (BOOL) isFinished
{
    return self->finished;
}

- (BOOL) isConcurrent
{
    return self->concurrent;
}

- (BOOL) isReady
{
    return self->ready;
}

- (void) main;
{
    return;	// OSX default implementation does nothing
}


// NSOpertation 只关心 isFinished 的状态的变化, 至于其他的变化, 是 queue 关心的.
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    [self->operationLock lock]; // 这个函数会改变自身的属性, 所以要进行加锁处理.
    
    /* We only observe isFinished changes, and we can remove self as an
     * observer once we know the operation has finished since it can never
     * become unfinished.
     */
    [object removeObserver: self forKeyPath: @"isFinished"];
    
    if (object == self) // 如果是自己完成了.
    {
        /* We have finished and need to unlock the condition lock so that
         * any waiting thread can continue.
         */
        [self->operationCondition lock];
        [self->operationCondition unlockWithCondition: 1]; // 这里面没有 wait 的处理, 仅仅是为了 singal, 这里的 single 是为了唤醒, waitUntilFinished 的调用.
        [self->operationLock unlock];
        return;
    }
    
    if (NO == self->ready) // 遍历依赖的状态, 然后更改自己的 ready 的状态.
    {
        NSEnumerator	*en;
        NSOperation	*op;
        
        /* Some dependency has finished (or been removed) ...
         * so we need to check to see if we are now ready unless we know we are.
         * This is protected by locks so that an update due to an observed
         * change in one thread won't interrupt anything in another thread.
         */
        en = [self->dependencies objectEnumerator]; // 在这里检测自己依赖是不是都完成了, 如果是, 那么修改自己的状态.
        while ((op = [en nextObject]) != nil)
        {
            if (NO == [op isFinished])
                break;
        }
        if (op == nil)
        {
            [self willChangeValueForKey: @"isReady"];
            self->ready = YES;
            [self didChangeValueForKey: @"isReady"];
        }
    }
    [self->operationLock unlock];
}

- (NSOperationQueuePriority) queuePriority
{
    return self->priority;
}

- (void) removeDependency: (NSOperation *)op
{
    [self->operationLock lock];
    NS_DURING
    {
        if (NSNotFound != [self->dependencies indexOfObjectIdenticalTo: op])
        {
            [op removeObserver: self forKeyPath: @"isFinished"];
            [self willChangeValueForKey: @"dependencies"];
            [self->dependencies removeObject: op];
            if (NO == self->ready)
            {
                /*
                    移除了依赖, 可能会导致 isReady 的变化, 这里是模拟了一次调用. 感觉命名不好.
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
        [self->operationLock unlock];
        NSLog(@"Problem removing dependency: %@", localException);
        return;
    }
    NS_ENDHANDLER
    [self->operationLock unlock];
}

- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock
{
    self->completionBlock = aBlock;
}

// 这就是一个存储在 NSOperation 里面的一个数据, 在 queue 里面会用到这个数据.
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
    
    if (pri != self->priority)
    {
        [self->operationLock lock];
        if (pri != self->priority)
        {
            NS_DURING
            {
                [self willChangeValueForKey: @"queuePriority"];
                self->priority = pri;
                [self didChangeValueForKey: @"queuePriority"];
            }
            NS_HANDLER
            {
                [self->operationLock unlock];
                NSLog(@"Problem setting priority: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [self->operationLock unlock];
    }
}

- (void) setThreadPriority: (double)pri
{
    if (pri > 1) pri = 1;
    else if (pri < 0) pri = 0;
    self->threadPriority = pri;
}

- (void) start
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new]; // 先推进一个自动释放池
    double		prio = [NSThread  threadPriority];
    
    AUTORELEASE(RETAIN(self));	// 这里, retain 了一下自己, 因为这是多线程的环境, 所以自己的生命周期不能完全依赖于外界的强链接, 因为这个链接有可能在其他线程进行切除.
    [self->operationLock lock]; // 这里进行了加锁.
    NS_DURING
    {
        // 显示一顿的防卫式语句.
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
        // 更在自己的状态.
        if (NO == self->executing)
        {
            [self willChangeValueForKey: @"isExecuting"];
            self->executing = YES;
            [self didChangeValueForKey: @"isExecuting"];
        }
    }
    NS_HANDLER
    {
        [self->operationLock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [self->operationLock unlock]; // 这里才会开锁.
    
    NS_DURING
    {
        // 所以, cancel 函数不会改变 finish 的状态, operation 还是会有 start 的调用, 只不过最重要的 main 不会被调用.
        if (NO == [self isCancelled])
        {
            [NSThread setThreadPriority: self->threadPriority]; // 在这里, 修改线程的优先级, 然后调用 main 方法.
            [self main]; // 在 start 里面, 调用了 main. 在这里面, 没有加锁, 因为 main 是业务代码, 不会进行上面那些状态的修改.
        }
    }
    NS_HANDLER
    {
        [NSThread setThreadPriority:  prio];
        [localException raise];
    }
    NS_ENDHANDLER;
    
    [self _finish]; // 调用 finish 方法, 修改自己的状态.
    [pool release];
}

- (double) threadPriority
{
    return self->threadPriority;
}


// 阻塞当前的线程, 之后再别的线程, 通过 KVO 才能唤醒.
// 这种, 一定是要操作一个 conditionLock. 一般情况下, 是把这个 conditionLock 传出去. 现在, NSOpertation 可能在两个线程中执行他的代码, 所以会有下面的这样的一个调用.
- (void) waitUntilFinished
{
    [self->operationCondition lockWhenCondition: 1];	// 在这个函数里面, condition 会进行 wait, 在被唤醒之后, 会进行锁的重新添加
    [self->operationCondition unlockWithCondition: 1];	// 在这个函数里面, 会释放唤醒之后添加的锁, 并且进行信号的发送.
}

- (void) _finish
{
    /* retain while finishing so that we don't get deallocated when our
     * queue removes and releases us.
     */
    [self retain]; // 因为, 只有 queue 保住 operation 的命, 所以, 这里, 先自己保住了命, 防止 queue 移除自己. 因为这里会有线程的切换.
    [self->operationLock lock];
    if (NO == self->finished)
    {
        if (YES == self->executing)
        {
            [self willChangeValueForKey: @"isExecuting"];
            [self willChangeValueForKey: @"isFinished"];
            self->executing = NO;
            self->finished = YES;
            [self didChangeValueForKey: @"isFinished"];
            [self didChangeValueForKey: @"isExecuting"];
        }
        else
        {
            [self willChangeValueForKey: @"isFinished"];
            self->finished = YES;
            [self didChangeValueForKey: @"isFinished"];
        }
        // 所以, completionBlock 仅仅是一个属性, 在算法流程里面会有这个属性的检测机制.
        if (NULL != self->completionBlock)
        {
            self->completionBlock();
        }
    }
    [self->operationLock unlock]; // 在这里修改状态.
    [self release];
}

@end

#undef	GSself
#define	GSself	NSOperationQueueself


@interface	NSOperationQueue (Private)
- (void) schedule;
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

static NSString	*queueKey = @"NSOperationQueue";
static NSOperationQueue *mainQueue = nil;

@implementation NSOperationQueue

+ (id) currentQueue
{
    if ([NSThread isMainThread])
    {
        return mainQueue;
    }
    return [[[NSThread currentThread] threadDictionary] objectForKey: queueKey];
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

- (void) addOperation: (NSOperation *)operation
{
    // 对于 queue 来说, 他要检测自己每个 operation 的 isReady 状态.
    [self->queueLock lock];
    // 如果, 没有添加过这个 operation , 并且这 opration 还没有完成的话, 才添加进去.
    if (NSNotFound == [self->operations indexOfObjectIdenticalTo: operation] &&
        NO == [operation isFinished])
    {
        [operation addObserver: self
             forKeyPath: @"isReady"
                options: NSKeyValueObservingOptionNew
                context: isReadyCtxt]; // operation 的 Ready 状态需要被 queue 监听, 因为需要管理下一个可以处理的 operation 的位置.
        [self willChangeValueForKey: @"operations"]; // 因为, 在文档里面明确说明了这个属性是 KVO 兼容的, 所以在代码里面, 每一个修改的地方, 都要添加 KVO 的调用.
        [self willChangeValueForKey: @"operationCount"];
        [self->operations addObject: operation];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
        if (YES == [operation isReady]) // 如果 operation 是 isReady 的状态了, 显示的调用一下.
        {
            [self observeValueForKeyPath: @"isReady"
                                ofObject: operation
                                  change: nil
                                 context: isReadyCtxt];
        }
    }
    [self->queueLock unlock];
    [self schedule];
}

- (void) addOperations: (NSArray *)operations
     waitUntilFinished: (BOOL)shouldWait
{
    NSUInteger	total;
    NSUInteger	index;
    
    total = [operations count];
    if (total > 0)
    {
        BOOL		invalidArg = NO;
        NSUInteger	toAdd = total;
        GS_BEGINITEMBUF(buf, total, id)
        
        [operations getObjects: buf];
        for (index = 0; index < total; index++)
        {
            NSOperation	*op = buf[index];
            
            if (NO == [op isKindOfClass: [NSOperation class]])
            {
                invalidArg = YES; // 如果, 里面有一个不是 NSOperation, 那么直接抛异常了.
                toAdd = 0;
                break;
            }
            if (YES == [op isFinished])
            {
                buf[index] = nil; // 这里, buf 不是 NSArray, 所以可以进行 nil 的赋值.
                toAdd--;
            }
        }
        if (toAdd > 0)
        {
            [self->queueLock lock];
            [self willChangeValueForKey: @"operationCount"];
            [self willChangeValueForKey: @"operations"];
            for (index = 0; index < total; index++)
            {
                NSOperation	*op = buf[index];
                
                if (op == nil)
                {
                    continue;		// Not added
                }
                if (NSNotFound != [self->operations indexOfObjectIdenticalTo: op])
                {
                    buf[index] = nil;	// Not added
                    toAdd--;
                    continue;
                }
                [op addObserver: self
                     forKeyPath: @"isReady"
                        options: NSKeyValueObservingOptionNew
                        context: isReadyCtxt];
                [self->operations addObject: op];
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
            [self->queueLock unlock];
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
    [self schedule];
    // 这里, 卡住的仅仅是调用了这个方法的线程.
    if (YES == shouldWait)
    {
        [self waitUntilAllOperationsAreFinished];
    }
}

- (void) waitUntilAllOperationsAreFinished
{
    NSOperation    *op;
    
    [self->queueLock lock];
    
    /**
           真正的卡掉当前线程, 是 [op waitUntilFinished] 里面, 会有一个 conditionLock 的 wait 操作. 直到在其他的线程执行完整个 operation 之后, 才会singal waitUntilFinished 继续执行. 然后再次取当前 queue 的最后一个 operation, 然后再次调用 waitUntilFinished 方法.
           这里, 没有对于 queue 的修改, 因为对于 queue 的修改, 应该是另外的线程中执行. 也就是在 unlock, lock 之间.
     */
    while ((op = [self->operations lastObject]) != nil)
    {
        [op retain];
        [self->queueLock unlock];
        [op waitUntilFinished];
        [op release];
        [self->queueLock lock];
    }
    [self->queueLock unlock];
}

- (void) cancelAllOperations // 所有的进行 cancel 的调用.
{
    [[self operations] makeObjectsPerformSelector: @selector(cancel)];
}

- (void) dealloc
{
    [self cancelAllOperations];
    DESTROY(self->operations);
    DESTROY(self->starting);
    DESTROY(self->waiting);
    DESTROY(self->name);
    DESTROY(self->queueCondition);
    DESTROY(self->queueLock);
    [super dealloc];
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        self->suspended = NO;
        self->concurrentCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        // 下面这三个数组, 是为了进行 operation 的调配工作.
        self->operations = [NSMutableArray new]; // 总的
        self->starting = [NSMutableArray new]; // 已经执行的
        self->waiting = [NSMutableArray new]; // 还在等待的
        
        self->queueLock = [NSRecursiveLock new];
        [self->queueLock setName:
         [NSString stringWithFormat: @"lock-for-op-%p", self]];
        
        self->queueCondition = [[NSConditionLock alloc] initWithCondition: 0];
        [self->queueCondition setName:
         [NSString stringWithFormat: @"cond-for-op-%p", self]];
    }
    return self;
}

- (BOOL) isSuspended
{
    return self->suspended;
}

- (NSInteger) maxConcurrentOperationCount
{
    return self->concurrentCount;
}

- (NSString*) name
{
    NSString	*s;
    
    [self->queueLock lock];
    if (self->name == nil)
    {
        self->name
        = [[NSString alloc] initWithFormat: @"NSOperation %p", self];
    }
    s = [self->name retain]; // 在多线程环境下, 不能直接返回属性的值, 而是要进行一个变量的赋值, 然后返回这个变量.
    [self->queueLock unlock];
    return [s autorelease];
}

- (NSUInteger) operationCount
{
    NSUInteger	c;
    
    [self->queueLock lock];
    c = [self->operations count];
    [self->queueLock unlock];
    return c;
}

- (NSArray *) operations // 复制操作, 不直接返回.
{
    NSArray	*a;
    
    [self->queueLock lock];
    a = [NSArray arrayWithArray: self->operations];
    [self->queueLock unlock];
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
    [self->queueLock lock];
    if (cnt != self->concurrentCount)
    {
        [self willChangeValueForKey: @"maxConcurrentOperationCount"];
        self->concurrentCount = cnt;
        [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
    [self->queueLock unlock];
    [self schedule];
}

- (void) setName: (NSString*)s
{
    if (s == nil) s = @"";
    [self->queueLock lock];
    if (NO == [self->name isEqual: s])
    {
        [self willChangeValueForKey: @"name"];
        [self->name release];
        self->name = [s copy];
        [self didChangeValueForKey: @"name"];
    }
    [self->queueLock unlock];
}

// 所以, 这里仅仅是一个属性的设置, 然后在调用
- (void) setSuspended: (BOOL)flag
{
    [self->queueLock lock];
    if (flag != self->suspended)
    {
        [self willChangeValueForKey: @"suspended"];
        self->suspended = flag;
        [self didChangeValueForKey: @"suspended"];
    }
    [self->queueLock unlock];
    [self schedule];
}

/**
 * 对于队列来说,  它关心的是,
 * 1. 任务完成了吗, 完成了, 更新队列, 进行下一次的调度
 * 2. 任务的优先级变化了吗, 变化了, 进行调度队列的刷新
 * 3. 任务的 ready 状态变化了吗. 变化了, 更新调度队列.
 *
 * 所有的真正执行方法, 在 调度算法里面, 调度算法, 仅仅对 starting, waiting 队列感兴趣
 *
 *
 *    对于任务来说, 它关心的是,
 *    1. 依赖的任务的 finish 状态, 这样可以更新自己的 ready 状态
 *    2. 自己的finish 状态, 这样可以唤醒自己的停滞状态.
 */

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    /*
    这里, context 被用到了, 这就是一个, 类似于 NSDicitonary 的info 的东西, 它到底干什么, 是做分发用, 还是用做取值用, 全部是使用者设置.
     */
    if (context == isFinishedCtxt)
    { // 一个 operation 完成了, 修改执行的属性, 以及 operations 数组的量.
        [self->queueLock lock];
        self->executing--;
        [object removeObserver: self forKeyPath: @"isFinished"];
        [self->queueLock unlock];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [self->queueLock lock];
        [self->operations removeObjectIdenticalTo: object];
        [self->queueLock unlock];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
    } else if (context == queuePriorityCtxt || context == isReadyCtxt)
    {
        // 如果是优先级变化了, 或者是 operation 的 ready 变化了.
        NSInteger pos;
        
        [self->queueLock lock];
        if (context == queuePriorityCtxt)
        {// 如果是优先级发生了变化, 那么修改 waiting 里面的位置.
            [self->waiting removeObjectIdenticalTo: object];
        }
        if (context == isReadyCtxt)
        {
            [object removeObserver: self forKeyPath: @"isReady"];
            [object addObserver: self
                     forKeyPath: @"queuePriority"
                        options: NSKeyValueObservingOptionNew
                        context: queuePriorityCtxt];
        }
        // 根据 queuePriority 在队列里面进行排序. 也就是, 优先级越大的, 在 wait 里面的位置越靠前.
        pos = [self->waiting insertionPosition: object
                                 usingFunction: sortFunc
                                       context: 0];
        [self->waiting insertObject: object atIndex: pos];
        [self->queueLock unlock];
        // self->waiting 的操作, 只会在这里进行. schedule 只会进行 deque 的处理.
    }
    [self schedule];
}

/*
 这里, 进行真正的任务的调配, operation 的运行操作.
 任何可能会改变任务的执行顺序, 以及更新队列的操作, 都应该调用这个方法.
 */
- (void) schedule
{
    NSInteger    max;
    
    [self->queueLock lock];
    
    max = [self maxConcurrentOperationCount];
    if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
        max = maxConcurrent;
    }
    // 如果 停止了, 不做新的任务的调配工作 ,所以 isSuspended 这个值, 不会影响到已经运行了的任务.
    // 如果现在运行的值已经超过了最大的并发量, 不进行新的任务的调配
    // 如果现在没有了正在等待的任务, 返回.
    while (NO == [self isSuspended]
           && max > self->executing
           && [self->waiting count] > 0)
    {
        NSOperation    *toRunOperation;
        /* Take the first operation from the queue and start it executing.
         * We set ourselves up as an observer for the operating finishing
         * and we keep track of the count of operations we have started,
         * but the actual startup is left to the NSOperation -start method.
         */
        /**
         * 所以, operation 的 concorrent queue还是有顺序的, 只不过 maxCount 大于 1 的话, 可以多取几个 task.
         */
        
        toRunOperation = [self->waiting objectAtIndex: 0];
        [self->waiting removeObjectAtIndex: 0];
        [toRunOperation removeObserver: self forKeyPath: @"queuePriority"]; // 一旦, 取出之后, queue 就不在检测 operation 的属性值了.
        [toRunOperation addObserver: self
             forKeyPath: @"isFinished"
                options: NSKeyValueObservingOptionNew
                context: isFinishedCtxt];
        // 正在运行的 operation 的状态, 要被 queue 监听着它的 isFinished 状态, 来更新自己的状态.
        self->executing++; // 增加执行的数量.
        
        // 如果, [toRunOperation isConcurrent] == YES, 那么一定要在 operation 内部有着异步的处理逻辑. 不然, 这个 operation 还是在当前的线程执行.
        if (YES == [toRunOperation isConcurrent])
        {
            [toRunOperation start];
        }
        else
        {
            NSUInteger    pending;
            
            [self->queueCondition lock];
            pending = [self->starting count];
            [self->starting addObject: toRunOperation];
            
            /* Create a new thread if all existing threads are busy and
             * we haven't reached the pool limit.
             */
            if (0 == self->threadCount ||
                (pending > 0 && self->threadCount < POOL)) // 如果, 当前运行的线程数小于阈值.
            {
                self->threadCount++;
                [NSThread detachNewThreadSelector: @selector(_thread)
                                         toTarget: self
                                       withObject: nil]; // 这里没有值得传递.
            }
            /* Tell the thread pool that there is an operation to start.
             */
            [self->queueCondition unlockWithCondition: 1];
        }
    }
    [self->queueLock unlock];
}


- (void) _thread
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    
    [[[NSThread currentThread] threadDictionary] setObject: self
                                                    forKey: queueKey];
    for (;;) // 连续不断地进行已经提交的任务的调用. 这里这样设计, 是为了充分的利用到线程.
    {
        NSOperation	*toRunOperation;
        NSDate		*when;
        BOOL		found;
        
        when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0];
        found = [self->queueCondition lockWhenCondition: 1 beforeDate: when]; // 等待, 如果有其他的任务, 就会被唤醒.
        RELEASE(when);
        if (NO == found)
        {
            break;	// Idle for 5 seconds ... exit thread.
        }
        
        if ([self->starting count] > 0)
        {
            toRunOperation = RETAIN([self->starting objectAtIndex: 0]);
            [self->starting removeObjectAtIndex: 0];
        }
        else
        {
            toRunOperation = nil;
        }
        
        if ([self->starting count] > 0) // 如果还有没有执行起来的任务, 就通知其他的线程.
        {
            [self->queueCondition unlockWithCondition: 1];
        } else {
            // There are no more operations starting.
            [self->queueCondition unlockWithCondition: 0];
        }
        
        if (nil != toRunOperation)
        {
            NS_DURING
            {
                NSAutoreleasePool	*opPool = [NSAutoreleasePool new];
                [NSThread setThreadPriority: [toRunOperation threadPriority]];
                [toRunOperation start];// 真正的执行函数.
                RELEASE(opPool);
            }
            NS_HANDLER
            {
                NSLog(@"Problem running operation %@ ... %@",
                      toRunOperation, localException);
            }
            NS_ENDHANDLER
            [toRunOperation _finish];
            RELEASE(toRunOperation);
        }
    }
    
    [[[NSThread currentThread] threadDictionary] removeObjectForKey: queueKey];
    [self->queueLock lock];
    self->threadCount--;
    [self->queueLock unlock];
    RELEASE(pool);
    [NSThread exit];
}

@end

