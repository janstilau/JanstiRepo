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
#include	"GSInternal.h"

static void     *isFinishedCtxt = (void*)"isFinished";
static void     *isReadyCtxt = (void*)"isReady";
static void     *queuePriorityCtxt = (void*)"queuePriority";

#define	POOL	8

static NSArray	*empty = nil;

@interface	NSOperation (Private)
- (void) _finish;
@end

@implementation NSOperation

// 比较重要的几个属性, 都是 NSOperation 内部自己控制的.
+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
    return NO;
}

+ (void) initialize
{
    empty = [NSArray new];
}

/*
 这个类里面, 大量的使用了 KVO, 这种响应式编程的思想, 可以大大减少编码的复杂度.
 */

- (void) addDependency: (NSOperation *)op
{
    /*
     首先是一些防卫式的检测. 判断 op 的类型之类的.
     */
    // 这里, 是懒加载的策略. 懒加载比较可以理解, 因为, 添加依赖的任务, 还是比较少的任务. 更多的任务, 就是为了异步任务提交.
    if (self->dependencies == nil)
    {
        self->dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
    }
    
    [self->lock lock];
    /*
     任何对于自身值的修改的地方, 都增加了 lock.
     因为执行自己 main 的地方, 不一定在创建线程, 所以, 加锁是必备的.
     */
    NS_DURING
    {
        // 文档里面没有明说重复添加的后果. 这里是可以重复添加.
        if (NSNotFound == [self->dependencies indexOfObjectIdenticalTo: op])
        {
            [self willChangeValueForKey: @"dependencies"];
            [self->dependencies addObject: op];
            if (NO == [op isFinished] // 前面是判断依赖的 Task 的 Finish 状态会不会变化.
                && NO == [self isCancelled] // 后面是判断, 自己还有没有启动的机会.
                && NO == [self isExecuting]
                && NO == [self isFinished])
            {
                [op addObserver: self
                     forKeyPath: @"isFinished"
                        options: NSKeyValueObservingOptionNew
                        context: isFinishedCtxt];
                if (self->ready == YES) // 如果自己已经 ready 了, 有了新的依赖, 要改变自己的状态.
                {
                    [self willChangeValueForKey: @"isReady"];
                    self->ready = NO;
                    [self didChangeValueForKey: @"isReady"];
                }
            }
            [self didChangeValueForKey: @"dependencies"];
        }
    }
    NS_HANDLER
    {
        // 多个解锁的退出点, OC 里面, 没有 Locker 的概念. OC 对于 RAII 不支持.
        [self->lock unlock];
        NSLog(@"Problem adding dependency: %@", localException);
        return;
    }
    NS_ENDHANDLER
    [self->lock unlock];
}

// Advises the operation object that it should stop executing its task.
/*
 如果, operation 已经 start 了, 那么只有是在运行的过程中, 不断地检查是否取消了, 如果取消了, 及时推出.
 如果, operation 还没有 start, 那么直接调用 finish 方法.
 */
- (void) cancel
{
    // 双检测法.
    if (NO == self->cancelled && NO == [self isFinished])
    {
        [self->lock lock];
        if (NO == self->cancelled && NO == [self isFinished])
        {
            NS_DURING
            {
                [self willChangeValueForKey: @"isCancelled"];
                self->cancelled = YES;
                if (NO == self->ready)
                {
                    [self willChangeValueForKey: @"isReady"];
                    self->ready = YES;
                    [self didChangeValueForKey: @"isReady"];
                }
                [self didChangeValueForKey: @"isCancelled"];
            }
            NS_HANDLER
            {
                [self->lock unlock];
                NSLog(@"Problem cancelling operation: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [self->lock unlock];
    }
}

- (void*) completionBlock
{
    return self->completionBlock;
}

- (NSArray *) dependencies
{
    NSArray	*result;
    
    if (self->dependencies == nil)
    {
        result = empty;	// OSX return an empty array
    } else {
        [self->lock lock];
        result = [NSArray arrayWithArray: self->dependencies];
        [self->lock unlock];
    }
    return result;
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        self->priority = NSOperationQueuePriorityNormal;
        self->threadPriority = 0.5;
        self->ready = YES;
        self->lock = [NSRecursiveLock new];
        [self->lock setName:
         [NSString stringWithFormat: @"lock-for-opqueue-%p", self]];
        self->operationConditionLock = [[NSConditionLock alloc] initWithCondition: 0];
        [self->operationConditionLock setName:
         [NSString stringWithFormat: @"cond-for-opqueue-%p", self]];
        /*
         自己监听自己的 isFinished 的状态.
         */
        [self addObserver: self
               forKeyPath: @"isFinished"
                  options: NSKeyValueObservingOptionNew
                  context: isFinishedCtxt];
    }
    return self;
}

// 如果, 任务已经开始执行, 就在 main 方法里面, 不断地判断 cancel 的提前退出.
// 如果, 还没有开始执行, 就不调用 main 方法, 直接跳入 finish 流程.
- (BOOL) isCancelled
{
    return self->cancelled;
}

// 任务有没有在执行.
- (BOOL) isExecuting
{
    return self->executing;
}
// 任务有没有结束.
- (BOOL) isFinished
{
    return self->finished;
}
// 任务, 一定会有从开始到结束的过程的, 只不过 cancel 了的任务, 不会进入 main 方法. 但是, 对于外界来说, 这个任务也是已经执行过了.
// 而依赖, 则是根据 isFinished 状态, 去更改自己的 ready 状态的. 所以, 任务, 一定要走一遍 start 到 finish 的流程.

- (BOOL) isConcurrent
{
    return self->concurrent;
}

// 代表着, 任务是否可以进入就绪态. 如果所有的依赖, 都进入了 finish 态, 他就可以进入就绪态. 类似于线程调度.
- (BOOL) isReady
{
    return self->ready;
}

- (void)start{
    
    // 在每一个 operation 里面, 都新建了一个自动释放吃
    ENTER_POOL
    
    double    threadPriority = [NSThread  threadPriority];
    
    AUTORELEASE(RETAIN(self));    // Make sure we exist while running.
    
    /*
     在真正执行之前, 要进行一些状态的检查操作.
     如果是由 OperationQueue 去管理, 那么一般不会出现状态不合适就进去 start 的状态.
     但是 start 可以由手动进行触发, 所以里面的各个检查, 都是有必要的.
     */
    [self->lock lock];
    NS_DURING
    {
        if (YES == [self isExecuting]) // 已经启动过了, 异常
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on executing operation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (YES == [self isFinished]) // 已经完成了, 异常
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on finished operation",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (NO == [self isReady]) // 还没有准备好, 也就是依赖任务还没有完成, 异常
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@-%@] called on operation which is not ready",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        }
        if (NO == self->executing) // 更改自己的状态.
        {
            [self willChangeValueForKey: @"isExecuting"];
            self->executing = YES;
            [self didChangeValueForKey: @"isExecuting"];
        }
    }
    NS_HANDLER
    {
        [self->lock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [self->lock unlock];
    
    NS_DURING
    {
        // 如果, 没有被取消, 就执行 main 方法. 否则, 直接进入 finish 方法.
        // 调度类根本不关心 operation 有没有提前被 cancel, 这是 operation 自己内部的事情.
        if (NO == [self isCancelled])
        {
            [NSThread setThreadPriority: self->threadPriority];
            [self main];
        }
    }
    NS_HANDLER
    {
        [NSThread setThreadPriority:  threadPriority];
        [localException raise];
    }
    NS_ENDHANDLER;
    
    [self _finish];
    LEAVE_POOL
}


- (void) _finish
{
    RETAIN(self);
    [self->lock lock];
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
        // 如果设置了 completionBlock, 就执行.
        // 类暴露了什么属性, 想要达成效果, 就要在算法里面增加相关的逻辑.
        if (NULL != self->completionBlock)
        {
            CALL_BLOCK_NO_ARGS(self->completionBlock);
        }
    }
    [self->lock unlock];
    RELEASE(self);
}


/*
子类主要复写该方法, 来完成子类化的目的.
 */
- (void) main;
{
    return;
}

/*
 NSOperation, 是通过监听 isFinished 来改变自己的 READY 状态的.
 */
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    [self->lock lock];
    /*
     Self 只监听一次对应 OBJ 的状态, 所以这里监听到了就取消注册.
     */
    [object removeObserver: self forKeyPath: @"isFinished"];
    
    // 监听自己的 Finish 主要是为了 unlockWithCondition: 1, 也就是唤醒因为自己未执行而阻塞的其他线程.
    if (object == self)
    {
        [self->operationConditionLock lock];
        [self->operationConditionLock unlockWithCondition: 1];
        [self->lock unlock];
        return;
    }
    
    // 遍历一遍自己的依赖项, 修改自己的 ready 状态.
    if (NO == self->ready)
    {
        NSEnumerator	*en;
        NSOperation	*op;
        en = [self->dependencies objectEnumerator];
        while ((op = [en nextObject]) != nil)
        {
            if (NO == [op isFinished]) break;
        }
        if (op == nil)
        {
            [self willChangeValueForKey: @"isReady"];
            self->ready = YES;
            [self didChangeValueForKey: @"isReady"];
        }
    }
    [self->lock unlock];
}

- (NSOperationQueuePriority) queuePriority
{
    return self->priority;
}

- (void) removeDependency: (NSOperation *)op
{
    [self->lock lock];
    NS_DURING
    {
        if (NSNotFound != [self->dependencies indexOfObjectIdenticalTo: op])
        {
            [op removeObserver: self forKeyPath: @"isFinished"];
            [self willChangeValueForKey: @"dependencies"];
            [self->dependencies removeObject: op];
            if (NO == self->ready)
            {
                // 主动调用一些 observeValueForKeyPath 方法, 在里面, 修改 self 的 ready 状态
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
        [self->lock unlock];
        NSLog(@"Problem removing dependency: %@", localException);
        return;
    }
    NS_ENDHANDLER
    [self->lock unlock];
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
    
    if (pri != self->priority)
    {
        [self->lock lock];
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
                [self->lock unlock];
                NSLog(@"Problem setting priority: %@", localException);
                return;
            }
            NS_ENDHANDLER
        }
        [self->lock unlock];
    }
}

- (void) setThreadPriority: (double)pri
{
    if (pri > 1) pri = 1;
    else if (pri < 0) pri = 0;
    self->threadPriority = pri;
}


- (double) threadPriority
{
    return self->threadPriority;
}

// 外界调用该方法, 来阻塞调用时的线程.
- (void) waitUntilFinished
{
    [self->operationConditionLock lockWhenCondition: 1];	// Wait for finish
    [self->operationConditionLock unlockWithCondition: 1];	// Signal any other watchers
}

@end

@implementation	NSOperation (Private)


@end


/*
 Block Opertation, 就是简简单单的, 将 Block 当做参数存储起来, main 里面调用就得了.
 */
@implementation NSBlockOperation

+ (instancetype) blockOperationWithBlock: (GSBlockOperationBlock)block
{
    NSBlockOperation *op = [[self alloc] init];
    
    [op addExecutionBlock: block];
    return AUTORELEASE(op);
}

- (void) addExecutionBlock: (GSBlockOperationBlock)block
{
    GSBlockOperationBlock	blockCopy = [block copy];
    
    [_executionBlocks addObject: blockCopy];
    RELEASE(blockCopy);
}

- (void) dealloc
{
    RELEASE(_executionBlocks);
    [super dealloc];
}

- (NSArray *) executionBlocks
{
    return _executionBlocks;
}

- (id) init
{
    self = [super init];
    if (self != nil)
    {
        _executionBlocks = [[NSMutableArray alloc] initWithCapacity: 1];
    }
    return self;
}

- (void) main
{
    NSEnumerator 		*en = [[self executionBlocks] objectEnumerator];
    GSBlockOperationBlock theBlock;
    
    while ((theBlock = [en nextObject]) != NULL)
    {
        CALL_BLOCK_NO_ARGS(theBlock);
    }
}
@end


#include	"GSInternal.h"

@interface	NSOperationQueue (Private)
- (void) _execute;
- (void) queueThreadLauncher;
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context;
@end

static NSInteger	maxConcurrent = 200;	// Thread pool size

/*
 这里, 直接是按照 queuePriority 进行的排序.
 */
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
    // 从这里看到, 每一个线程, 都有一个关联的 OperationQueue
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
    [self->queueLock lock];
    if (NSNotFound == [self->operations indexOfObjectIdenticalTo: op]
        && NO == [op isFinished])
    {
        // OperationQueue 观测每个 Operation 的 isReady, 来进行队列的调度处理.
        [op addObserver: self
             forKeyPath: @"isReady"
                options: NSKeyValueObservingOptionNew
                context: isReadyCtxt];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [self->operations addObject: op];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
        // 这里, 如果 op 已经是 ready 了, 显示的调用 observeValueForKeyPath, 主要是为了可以进行队列的调度.
        if (YES == [op isReady])
        {
            [self observeValueForKeyPath: @"isReady"
                                ofObject: op
                                  change: nil
                                 context: isReadyCtxt];
        }
    }
    [self->queueLock unlock];
}


- (void) addOperations: (NSArray *)ops
     waitUntilFinished: (BOOL)shouldWait
{
    NSUInteger	total;
    NSUInteger	index;
    
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
                if (NSNotFound
                    != [self->operations indexOfObjectIdenticalTo: op])
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
    
    
    if (YES == shouldWait)
    {
        [self waitUntilAllOperationsAreFinished];
    }
}

// 所有的 task, 标志一下自己的 cancel 位.
- (void) cancelAllOperations
{
    [[self operations] makeObjectsPerformSelector: @selector(cancel)];
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        self->suspended = NO;
        self->count = NSOperationQueueDefaultMaxConcurrentOperationCount;
        self->operations = [NSMutableArray new];
        self->pending = [NSMutableArray new];
        self->waiting = [NSMutableArray new];
        self->queueLock = [NSRecursiveLock new];
        [self->queueLock setName:
         [NSString stringWithFormat: @"lock-for-op-%p", self]];
        self->startingQueueCondition = [[NSConditionLock alloc] initWithCondition: 0];
        [self->startingQueueCondition setName:
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
    return self->count;
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
    s = RETAIN(self->name);
    [self->queueLock unlock];
    return AUTORELEASE(s);
}

- (NSUInteger) operationCount
{
    NSUInteger	c;
    
    [self->queueLock lock];
    c = [self->operations count];
    [self->queueLock unlock];
    return c;
}

/*
 复制一份出去.
 */
- (NSArray *) operations
{
    NSArray	*a;
    
    [self->queueLock lock];
    a = [NSArray arrayWithArray: self->operations];
    [self->queueLock unlock];
    return a;
}

- (void) setMaxConcurrentOperationCount: (NSInteger)cnt
{
    [self->queueLock lock];
    if (cnt != self->count)
    {
        [self willChangeValueForKey: @"maxConcurrentOperationCount"];
        self->count = cnt;
        [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
    [self->queueLock unlock];
    [self _execute];
}

- (void) setName: (NSString*)s
{
    if (s == nil) s = @"";
    [self->queueLock lock];
    if (NO == [self->name isEqual: s])
    {
        [self willChangeValueForKey: @"name"];
        RELEASE(self->name);
        self->name = [s copy];
        [self didChangeValueForKey: @"name"];
    }
    [self->queueLock unlock];
}

/*
 A Boolean value indicating whether the queue is actively scheduling operations for execution.
 
 When the value of this property is NO, the queue actively starts operations that are in the queue and ready to execute. Setting this property to YES prevents the queue from starting any queued operations, but already executing operations continue to execute.
 You may continue to add operations to a queue that is suspended but those operations are not scheduled for execution until you change this property to NO.
 */
- (void)setSuspended: (BOOL)flag
{
    [self->queueLock lock];
    if (flag != self->suspended)
    {
        [self willChangeValueForKey: @"suspended"];
        self->suspended = flag;
        [self didChangeValueForKey: @"suspended"];
    }
    [self->queueLock unlock];
    /*
     在相应的地方, 重启队列就可以了.
     已经执行的任务, 不会受到影响.
     */
    [self _execute];
}

// 找到最后一个 operation, 然后让他卡住当前线程.
- (void) waitUntilAllOperationsAreFinished
{
    NSOperation	*op;
    
    [self->queueLock lock];
    while ((op = [self->operations lastObject]) != nil)
    {
        RETAIN(op);
        [self->queueLock unlock];
        [op waitUntilFinished];
        RELEASE(op);
        [self->queueLock lock];
    }
    [self->queueLock unlock];
}
@end

@implementation	NSOperationQueue (Private)

// Queue 监听 Operation 的属性, 在可以引起队列变化的属性变化时, 重新改变队列的状态. 然后进行下一次的调度.
// 不过, 这个方法很多时候不是监听调用的, 在这个类里面, 这个方法, 成为了队列变化的终点方法, 很多时候是主动调用的.
// 所以这个方法, 算是 Queue Resort 方法.
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if (context == isFinishedCtxt)
    {
        // 如果, 一个任务已经完成了, 那就更改 正执行数和队列.
        [self->queueLock lock];
        self->executingCount--;
        [object removeObserver: self forKeyPath: @"isFinished"];
        [self->queueLock unlock];
        [self willChangeValueForKey: @"operations"];
        [self willChangeValueForKey: @"operationCount"];
        [self->queueLock lock];
        [self->operations removeObjectIdenticalTo: object];
        [self->queueLock unlock];
        [self didChangeValueForKey: @"operationCount"];
        [self didChangeValueForKey: @"operations"];
    } else if (context == queuePriorityCtxt || context == isReadyCtxt) {
        NSInteger pos;
        [self->queueLock lock];
        if (context == queuePriorityCtxt)
        {
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
        // 如果, ready 的状态改变了, 那么就把该任务, 安放到 waiting 队列里面.
        pos = [self->waiting insertionPosition: object
                                 usingFunction: sortFunc
                                       context: 0];
        [self->waiting insertObject: object atIndex: pos];
        [self->queueLock unlock];
    }
    /*
     改变了队列里面的内容之后, 要立马执行调度算法, 进行下一个任务的执行.
     所以, 在 add 函数里面我们没有看到 execute 的调用. 只要队列发生了变化, 就会调度.
     */
    [self _execute];
}


/*
 总体理一遍线程 Launcher 的逻辑.
 
 startingQueueCondition lockWhenCondition
 如果当前的条件变量为 1, 那么这个 lock 其实锁不住的.
 */
- (void) queueThreadLauncher
{
    ENTER_POOL
    /*
     开辟了一个新的线程, 这个线程不断的做提取, 绑定 operationQueueKey 到自己.
     */
    [[[NSThread currentThread] threadDictionary] setObject: self
                                                    forKey: operationQueueKey];
    while(true) {
        /*
         首先, 等待 5 秒, 看一下有没有新的任务可以执行.
         
         这里, 相当于一个 P 操作, 等待 V 操作来进行唤醒.
         V 操作就是 self->queueCondition unlockWithCondition.
         
         可能开启了很多的线程, 每次线程完成一个 Operation 之后, 重新进入循环, 然后阻塞自己, 等待新的任务的分配.
         
         如果自己想要管理线程的话, 可以使用这个办法. GCD 这种方式, 使得已经习惯了 dispatch_async 了. 其实可以通过这种方式, 来管理线程的个数.
         线程的主方法, 就是不断地从任务队列里面取值, 然后做任务, 死循环不间断. 如果没有任务了, 就退出.
         这里, 为了让线程多存货一段时间, 使用了 PV 操作, 这样线程就可以多存活一段时间, 等待任务的来临. 同时, 如果确实没有任务的话, 就理所当然的退出了.
         */
        NSDate *when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0];
        BOOL hasWaitingOperation = [self->startingQueueCondition lockWhenCondition: 1 beforeDate: when];
        if (NO == hasWaitingOperation)
        {
            break;	// Idle for 5 seconds ... exit thread.
        }
        
        // 在这里, 能够到这里来, 其实是 startingQueueCondition 已经 Lock 上了. 所以下面的都是在上锁的状态.
        
        NSOperation    *currentOperation;
        if ([self->pending count] > 0)
        {
            currentOperation = RETAIN([self->pending objectAtIndex: 0]);
            [self->pending removeObjectAtIndex: 0];
        } else {
            currentOperation = nil;
        }
        
        // 不是在任务完成了之后, 再去进行唤醒, 而是在任务分配完了之后, 就去进行唤醒.
        // 当没有任务了, 就 unlock 0.
        if ([self->pending count] > 0)
        {
            // 唤醒其他的线程, 继续做任务.
            [self->startingQueueCondition unlockWithCondition: 1];
        } else {
            [self->startingQueueCondition unlockWithCondition: 0];
        }
        
        // 到这里, startingQueueCondition 的那把锁已经放开了.
        
        if (nil != currentOperation)
        {
            NS_DURING
            {
                ENTER_POOL
                [NSThread setThreadPriority: [currentOperation threadPriority]];
                [currentOperation start]; // 在这里, 进行了真正的任务的运行.
                LEAVE_POOL
            }
            NS_HANDLER
            {
                NSLog(@"Problem running operation %@ ... %@",
                      currentOperation, localException);
            }
            NS_ENDHANDLER {
                [currentOperation _finish];
            }
            RELEASE(currentOperation);
        }
    }
    
    // 在这里, 就是退出操作了.
    [[[NSThread currentThread] threadDictionary] removeObjectForKey: operationQueueKey];
    [self->queueLock lock];
    self->threadCount--;
    [self->queueLock unlock];
    LEAVE_POOL
    [NSThread exit];
}

/*
 队列的调度就是这样, 各个相关的方法, 主动地去进行队列的调度函数.
 在调度算法执行的时候, 要进行加锁处理, 或者, 应该将调度算法放到主线程, 串行队列执行, 保证各个值不会线程冲突.
 
 调度算法拿到相应的任务之后, 执行任务的时候, 就应该放开锁, 让任务单独在子线程处理.
 
 在任务执行完毕之后, 应该让任务的回调, 重新执行调度算法, 进行下一步的操作.
 调度算法如果发现没有任务了, 直接 return 就可以了. 所以, 可能会出现停止的情况.
 
 在添加任务, 或者改变任务优先级的时候, 应该加锁, 并且改变队列的顺序, 然后重新调用调度算法.
 
 OperationQueue 里面, 只要 observe 到变化, 就重新进行调度.
 */
- (void) _execute
{
    NSInteger	max;
    
    /*
     所有对于队列的改变, 都在锁下进行.
     */
    [self->queueLock lock];
    
    max = [self maxConcurrentOperationCount];
    if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
        max = maxConcurrent;
    }
    
    NS_DURING
    
    /*
     如果, 没有暂停, 还有余量, 还有等在执行的队列, 那么就可以开启新的任务.
     */
    while (NO == [self isSuspended]
           && max > self->executingCount
           && [self->waiting count] > 0)
    {
        NSOperation	*op;
        
        /*
         从 waiting 的第一个进行调度, wait 里面的顺序, 会随着优先级参数的设置随时调整.
         */
        op = [self->waiting objectAtIndex: 0];
        [self->waiting removeObjectAtIndex: 0];
        [op removeObserver:self forKeyPath: @"queuePriority"];
        
        /*
         只有任务开始执行, 才会去监听它的 finished 状态.
         */
        [op addObserver: self
             forKeyPath: @"isFinished"
                options: NSKeyValueObservingOptionNew
                context: isFinishedCtxt];
        self->executingCount++; // 增加正在执行的个数.
        /*
         NSOperation isConcurrent == YES, 代表着这个 NSOperation 内部会进行线程的开辟.
         默认的都是 NO.
         */
        if (YES == [op isConcurrent])
        {
            [op start];
        }
        else
        {
            // 如果需要 operationQueue 开辟线程运行任务, 在这里进行线程的新开辟处理.
            NSUInteger	pendingCount;
            /*
             self->starting
             self->threadCount
             这些值, 都是在 self->queueCondition 的管理下进行的取值赋值.
             */
            [self->startingQueueCondition lock];
            pendingCount = [self->pending count];
            [self->pending addObject: op];
            /*
             在这里, 进行了新的线程的分配工作. 如果可以新开启一个线程的话.
             */
            if (0 == self->threadCount // 如果, 没有线程正在执行任务
                || (pendingCount > 0 && self->threadCount < POOL)) // 或者, 可以开启一个线程来执行任务.
            {
                self->threadCount++;
                NS_DURING
                {
                    [NSThread detachNewThreadSelector: @selector(queueThreadLauncher)
                                             toTarget: self
                                           withObject: nil];
                }
                NS_HANDLER
                {
                    NSLog(@"Failed to create thread for %@: %@",
                          self, localException);
                }
                NS_ENDHANDLER
            }
            /*
             主动的通知新开辟的线程, 可以进行新任务的处理
             */
            [self->startingQueueCondition unlockWithCondition: 1];
        }
    }
    NS_HANDLER
    {
        [self->queueLock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [self->queueLock unlock];
}

@end

