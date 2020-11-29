#import "common.h"

#include <pthread.h>
#import "GSPrivate.h"
#define	gs_cond_t	pthread_cond_t
#define	gs_mutex_t	pthread_mutex_t
#include <math.h>

#define	EXPOSE_NSLock_IVARS	1
#define	EXPOSE_NSRecursiveLock_IVARS	1
#define	EXPOSE_NSCondition_IVARS	1
#define	EXPOSE_NSConditionLock_IVARS	1

#import "common.h"

#import "Foundation/NSLock.h"
#import "Foundation/NSException.h"
#import "Foundation/NSThread.h"

#import "GSPThread.h"

/*
 信号量的用户, 用不是为了互斥, 它更多的是一种唤醒机制.
 当然, 互斥可以看做是一种特殊的信号量.
 PV 操作, 都是原子操作, 在 PV 本质上说, 是 test and modefy 操作. 通过关中断开中断, 使得在进行原子操作的时候, 操作系统不可以进行线程切换.
 P 操作, 首先将资源值--, 然后判断资源值 <=0, 如果 < 0, 就把当前线程记录到待唤醒队列中, 阻塞该线程, 退出原语操作.
 V 操作, 首先将资源值++, 然后判断资源值是否 <= 0, 如果是 <=0, 就证明有着需要被唤醒的线程, 唤醒第一个被阻塞的线程.
 
 所以信号量最重要的, 是阻塞唤醒的机制.
 
 当信号量值为 1 的时候, 只会有一个线程进入临界区, 这就形成了互斥的目的. 在退出临界区之后, 进行 V 操作, 进行被阻塞线程的唤醒.
 可以认为, lock, unlock, 就是特殊的 PV 操作.
 
 但是, 同步操作要复杂一些. 同步操作要 触发代码执行 V 操作, 执行代码执行 P 操作. 并且把信号量设置为 0.
 如果执行代码先执行, 那么 P 操作之后, 执行代码就会被阻塞. 然后触发代码执行, V 操作可以唤醒执行代码. 这样就达到了有序的目的, 先触发, 后执行.
 如果触发代码先执行, 那么 V 操作之后, 执行代码执行 P 操作, 发现信号量没有小于 0, 就可以正常的运行不会被阻塞. 也达成了先触发, 后执行的目的.
 
 其他比较复杂的流程, 都是要找准触发代码和执行代码的关系. 可以这样说, 想要达成同步的目的, PV 操作要分别在有序的执行, 要分散到不同的代码块.
 
 但是这种同步, 仅仅是早就有序的目的, 对于共享资源的访问, 还是需要互斥来保证.
 
 consition 可以认为是, 内部含有一个初始值为 0 的信号量. 先加锁, 因为加锁了, 所以可以使用共享的资源进行判断, 当发现条件不允许的情况下, 就进行 wait.
 wait 操作, 首先将 P 操作, 将当前线程加入到待唤醒线程中, 然后放开锁.
 这样, 其他的线程就可以获取到锁, 进行共享资源的操作, 然后进行 signal 操作, 也就是 P 操作. 之前阻塞的线程被唤醒, 首先会立马再次加锁, 保证对于共享资源的互斥访问, 然后再次进行判断, 如果不合适, 再次进行 wiat, P 操作, 并放开互斥锁.
 而 broadcast 会将所有等待的线程都唤醒, 相当于是进行了多次的 V 操作, 被唤醒的线程, 首先会尝试加锁, 然后判断条件, 如果不允许的话, 还会进行 wait, 相当于进行 P 操作并释放锁.
 
 这个逻辑, 被 NSConditionLock 封装到了自己的内部.
 
 NSConditionLock 的提出, 使得线程同步问题, 可以有一个比较好的解决办法.
 
 
 
 除了以上的办法, 我个人觉得, 维护一个队列和调度算法, 是比较通用的办法. 每次任务完成之后, 要重新调用一下这个调度算法, 只要保证调度算法在一个线程, 或者对于调度算法的调用, 前后加锁, 那么也可以达到并发执行的目的.
 如果任务之间有依赖, 可以参考 NSOperationQueue 的实现.
 
 dispatch_barrier_async, 和 gcd 的 groupnotify 机制, 我觉得都可以用队列加调度算法的机制模拟.
 
 如果不用上面的机制, 那就用 conditionLock 方式. 设置相关的信号量, 等到条件允许的时候, 进行 P 操作, 当然条件的更改, 要互斥保护. 这样, 需要依赖才能执行的任务上来就在子线程执行 P 操作, 但是需要其他线程完成完任务之后改变资源 V 操作唤醒. 这样其实变复杂了, 远远不如调度算法清晰可扩展.
 
 */

#define class_createInstance(C,E) NSAllocateObject(C,E,NSDefaultMallocZone())

static Class    baseConditionClass = Nil;
static Class    baseConditionLockClass = Nil;
static Class    baseLockClass = Nil;
static Class    baseRecursiveLockClass = Nil;

static Class    tracedConditionClass = Nil;
static Class    tracedConditionLockClass = Nil;
static Class    tracedLockClass = Nil;
static Class    tracedRecursiveLockClass = Nil;

static Class    untracedConditionClass = Nil;
static Class    untracedConditionLockClass = Nil;
static Class    untracedLockClass = Nil;
static Class    untracedRecursiveLockClass = Nil;

static BOOL     traceLocks = NO;

@implementation NSObject (GSTraceLocks)

+ (BOOL) shouldCreateTraceableLocks: (BOOL)shouldTrace
{
    BOOL  old = traceLocks;
    
    traceLocks = shouldTrace ? YES : NO;
    return old;
}

+ (NSCondition*) tracedCondition
{
    return AUTORELEASE([GSTracedCondition new]);
}

+ (NSConditionLock*) tracedConditionLockWithCondition: (NSInteger)value
{
    return AUTORELEASE([[GSTracedConditionLock alloc] initWithCondition: value]);
}

+ (NSLock*) tracedLock
{
    return AUTORELEASE([GSTracedLock new]);
}

+ (NSRecursiveLock*) tracedRecursiveLock
{
    return AUTORELEASE([GSTracedRecursiveLock new]);
}

@end

/* In untraced operations these macros do nothing.
 * When tracing they are defined to perform the trace methods of the thread.
 */
#define CHKT(T,X) 
#define CHK(X)

// 当, 大部分代码都一样的时候, 使用宏可以大大减少代码行的长度. 当然, 在编译器看来, 没有什么变化. 但是人工阅读起来, 代码行数少的文件, 更加容易理解.
// dealloc, 增加了一个方法的调用, finalize,
#define	MDEALLOC \
- (void) dealloc\
{\
[self finalize];\
[_name release];\
[super dealloc];\
}

#if     defined(HAVE_PTHREAD_MUTEX_OWNER)

#define	MDESCRIPTION \
- (NSString*) description\
{\
if (_mutex.__data.__owner)\
{\
if (_name == nil)\
{\
return [NSString stringWithFormat: @"%@ (locked by %llu)",\
[super description], (unsigned long long)_mutex.__data.__owner];\
}\
return [NSString stringWithFormat: @"%@ '%@' (locked by %llu)",\
[super description], _name, (unsigned long long)_mutex.__data.__owner];\
}\
else\
{\
if (_name == nil)\
{\
return [super description];\
}\
return [NSString stringWithFormat: @"%@ '%@'",\
[super description], _name];\
}\
}

#define	MISLOCKED \
- (BOOL) isLockedByCurrentThread\
{\
if (GSPrivateThreadID() == (NSUInteger)_mutex.__data.__owner)\
return YES;\
else\
return NO; \
}

#else

#define	MDESCRIPTION \
- (NSString*) description\
{\
if (_name == nil)\
{\
return [super description];\
}\
return [NSString stringWithFormat: @"%@ '%@'",\
[super description], _name];\
}

#define	MISLOCKED \
- (BOOL) isLockedByCurrentThread\
{\
[NSException raise: NSGenericException format: @"Not supported"];\
return NO;\
}

#endif

// 大部分情况下, finalize 就是销毁成员变量 _mutex.
#define MFINALIZE \
- (void) finalize\
{\
pthread_mutex_destroy(&_mutex);\
}

// lock 就是调用 pthread_mutex_lock
#define	MLOCK \
- (void) lock\
{\
int err = pthread_mutex_lock(&_mutex);\
if (EDEADLK == err)\
{\
(*_NSLock_error_handler)(self, _cmd, YES, @"deadlock");\
}\
else if (err != 0)\
{\
[NSException raise: NSLockException format: @"failed to lock mutex"];\
}\
}

// lockBeforeDate 就是一个死循环, 在里面不断地进行 tryLock, 如果 lock 是信号量实现的, 那就是不断地去询问当前的资源值的大小. 当不能加锁的时候, 就主动的 yield 让出 CPU 资源.
#define	MLOCKBEFOREDATE \
- (BOOL) lockBeforeDate: (NSDate*)limit\
{\
do\
{\
int err = pthread_mutex_trylock(&_mutex);\
if (0 == err)\
{\
CHK(Hold) \
return YES;\
}\
sched_yield();\
} while ([limit timeIntervalSinceNow] > 0);\
return NO;\
}

#define MNAME \
- (void) setName: (NSString*)newName\
{\
ASSIGNCOPY(_name, newName);\
}\
- (NSString*) name\
{\
return _name;\
}

#define MSTACK \
- (GSStackTrace*) stack \
{ \
return nil; \
}

#define	MTRYLOCK \
- (BOOL) tryLock\
{\
int err = pthread_mutex_trylock(&_mutex);\
if (0 == err) \
{ \
CHK(Hold) \
return YES; \
} \
else \
{ \
return NO;\
} \
}

#define	MUNLOCK \
- (void) unlock\
{\
if (0 != pthread_mutex_unlock(&_mutex))\
{\
[NSException raise: NSLockException\
format: @"failed to unlock mutex"];\
}\
CHK(Drop) \
}

static pthread_mutex_t deadlock;
static pthread_mutexattr_t attr_normal;
static pthread_mutexattr_t attr_reporting;
static pthread_mutexattr_t attr_recursive;


NSLock_error_handler  *_NSLock_error_handler = _NSLockError;

// Exceptions

NSString *NSLockException = @"NSLockException";

@implementation NSLock

+ (id) allocWithZone: (NSZone*)z
{
    if (self == baseLockClass && YES == traceLocks)
    {
        return class_createInstance(tracedLockClass, 0);
    }
    return class_createInstance(self, 0);
}

// 在这里, 做一次全局资源的初始化操作.
+ (void) initialize
{
    static BOOL	hasInitilized = NO;
    
    if (hasInitilized == NO)
    {
        hasInitilized = YES;
        
        pthread_mutexattr_init(&attr_normal);
        pthread_mutexattr_settype(&attr_normal, PTHREAD_MUTEX_NORMAL);
        pthread_mutexattr_init(&attr_reporting);
        pthread_mutexattr_settype(&attr_reporting, PTHREAD_MUTEX_ERRORCHECK);
        pthread_mutexattr_init(&attr_recursive);
        pthread_mutexattr_settype(&attr_recursive, PTHREAD_MUTEX_RECURSIVE);
        
        /* To emulate OSX behavior, we need to be able both to detect deadlocks
         * (so we can log them), and also hang the thread when one occurs.
         * the simple way to do that is to set up a locked mutex we can
         * force a deadlock on.
         */
        pthread_mutex_init(&deadlock, &attr_normal);
        pthread_mutex_lock(&deadlock);
        
        baseConditionClass = [NSCondition class];
        baseConditionLockClass = [NSConditionLock class];
        baseLockClass = [NSLock class];
        baseRecursiveLockClass = [NSRecursiveLock class];
        
        tracedConditionClass = [GSTracedCondition class];
        tracedConditionLockClass = [GSTracedConditionLock class];
        tracedLockClass = [GSTracedLock class];
        tracedRecursiveLockClass = [GSTracedRecursiveLock class];
        
        untracedConditionClass = [GSUntracedCondition class];
        untracedConditionLockClass = [GSUntracedConditionLock class];
        untracedLockClass = [GSUntracedLock class];
        untracedRecursiveLockClass = [GSUntracedRecursiveLock class];
    }
}

MDEALLOC
MDESCRIPTION
MFINALIZE

- (id) init
{
    if (nil != (self = [super init]))
    {
        if (0 != pthread_mutex_init(&_mutex, &attr_reporting))
        {
            DESTROY(self);
        }
    }
    return self;
}

MISLOCKED
MLOCK

/*
 所谓的 lock before date, 就是不断的调用 tryLock, 如果没有成功, 那么就直接 yield 就可以了.
 */
- (BOOL) lockBeforeDate: (NSDate*)limit
{
    do
    {
        int err = pthread_mutex_trylock(&_mutex);
        if (0 == err)
        {
            CHK(Hold)
            return YES;
        }
        if (EDEADLK == err)
        {
            (*_NSLock_error_handler)(self, _cmd, NO, @"deadlock");
        }
        sched_yield();
    } while ([limit timeIntervalSinceNow] > 0);
    return NO;
}

MNAME
MSTACK
MTRYLOCK
MUNLOCK

@end

/*
 NSRecursiveLock 仅仅是封装的 mutex 用 attr_recursive 进行修饰.
 */
@implementation NSRecursiveLock

+ (id) allocWithZone: (NSZone*)z
{
    if (self == baseRecursiveLockClass && YES == traceLocks)
    {
        return class_createInstance(tracedRecursiveLockClass, 0);
    }
    return class_createInstance(self, 0);
}

+ (void) initialize
{
    [NSLock class];	// Ensure mutex attributes are set up.
}

MDEALLOC
MDESCRIPTION
MFINALIZE

- (id) init
{
    if (nil != (self = [super init]))
    {
        if (0 != pthread_mutex_init(&_mutex, &attr_recursive))
        {
            DESTROY(self);
        }
    }
    return self;
}

MISLOCKED
MLOCK
MLOCKBEFOREDATE
MNAME
MSTACK
MTRYLOCK
MUNLOCK
@end

@implementation NSCondition

+ (id) allocWithZone: (NSZone*)z
{
    if (self == baseConditionClass && YES == traceLocks)
    {
        return class_createInstance(tracedConditionClass, 0);
    }
    return class_createInstance(self, 0);
}

+ (void) initialize
{
    [NSLock class];	// Ensure mutex attributes are set up.
}

// 这里, 会唤醒一个当前被阻塞的线程. 如果内部是 信号量实现的, 那就是 V 操作一次.
// Signals the condition, waking up one thread waiting on it.
- (void) signal
{
    pthread_cond_signal(&_condition);
}

// Signals the condition, waking up all threads waiting on it.
- (void) broadcast
{
    pthread_cond_broadcast(&_condition);
}

- (void) wait
{
    pthread_cond_wait(&_condition, &_mutex);
}

- (BOOL) waitUntilDate: (NSDate*)limit
{
    NSTimeInterval ti = [limit timeIntervalSince1970];
    double secs, subsecs;
    struct timespec timeout;
    int retVal = 0;
    
    // Split the float into seconds and fractions of a second
    subsecs = modf(ti, &secs);
    timeout.tv_sec = secs;
    // Convert fractions of a second to nanoseconds
    timeout.tv_nsec = subsecs * 1e9;
    
    /* NB. On timeout the lock is still held even through condition is not met
     */
    
    retVal = pthread_cond_timedwait(&_condition, &_mutex, &timeout);
    if (retVal == 0)
    {
        return YES;
    }
    if (retVal == ETIMEDOUT)
    {
        return NO;
    }
    if (retVal == EINVAL)
    {
        NSLog(@"Invalid arguments to pthread_cond_timedwait");
    }
    return NO;
}

MDEALLOC
MDESCRIPTION

- (void) finalize
{
    pthread_cond_destroy(&_condition);
    pthread_mutex_destroy(&_mutex);
}

- (id) init
{
    if (nil != (self = [super init]))
    {
        if (0 != pthread_cond_init(&_condition, NULL))
        {
            DESTROY(self);
        }
        else if (0 != pthread_mutex_init(&_mutex, &attr_reporting))
        {
            pthread_cond_destroy(&_condition);
            DESTROY(self);
        }
    }
    return self;
}

MISLOCKED
MLOCK
MLOCKBEFOREDATE
MNAME

MSTACK
MTRYLOCK
MUNLOCK

@end

@implementation NSConditionLock

+ (id) allocWithZone: (NSZone*)z
{
    if (self == baseConditionLockClass && YES == traceLocks)
    {
        return class_createInstance(tracedConditionLockClass, 0);
    }
    return class_createInstance(self, 0);
}

+ (void) initialize
{
    [NSLock class];	// Ensure mutex attributes are set up.
}

- (NSInteger) condition
{
    return _condition_value;
}

- (void) dealloc
{
    [_name release];
    [_condition release];
    [super dealloc];
}

- (id) init
{
    return [self initWithCondition: 0];
}

- (id) initWithCondition: (NSInteger)value
{
    if (nil != (self = [super init]))
    {
        if (nil == (_condition = [NSCondition new]))
        {
            DESTROY(self);
        }
        else
        {
            _condition_value = value;
            [_condition setName:
             [NSString stringWithFormat: @"condition-for-lock-%p", self]];
        }
    }
    return self;
}

- (BOOL) isLockedByCurrentThread
{
    return [_condition isLockedByCurrentThread];
}

- (void) lock
{
    [_condition lock];
}

- (BOOL) lockBeforeDate: (NSDate*)limit
{
    return [_condition lockBeforeDate: limit];
}

/*
 其实, NSCondition 里面的文档, 也是这样的示例代码. 在 mutex 进行 lock 之后, 要在一个循环里面, 不断地判断条件, 如果不满足的话, 就直接进行 wait.
 这里, NSConditionLock 相当于把这个条件封装到了自己的内部.
 value 作为函数的参数, 是保存到了每个线程自己的空间的. 每个线程自己的参数变量, 和共享的 _condition_value 比较, 当不符合的时候, 就进行 wait. 这是一个死循环, wait 又是一个阻塞函数. 所以, lockWhenCondition 可以起到如果条件不允许, 就一直进行阻塞的效果.
 */
- (void) lockWhenCondition: (NSInteger)value
{
    [_condition lock]; // 首先, 使用 mutex 进行加锁, 如果条件不允许, 就进行等待操作.
    while (value != _condition_value)
    {
        [_condition wait]; // 这里, 其他的线程进行了 wake 操作之后, 会加锁, 然后判断 value 值如果和自己的 _condition_value 不等, 又会进行 wait 操作.
    }
}

- (BOOL) lockWhenCondition: (NSInteger)condition_to_meet
                beforeDate: (NSDate*)limitDate
{
    if (NO == [_condition lockBeforeDate: limitDate])
    {
        return NO;        // Not locked
    }
    if (condition_to_meet == _condition_value)
    {
        return YES;       // Keeping the lock
    }
    while ([_condition waitUntilDate: limitDate])
    { // 这个时候, 已经获取到 mutex 了,
        // 然后需要判断, _condition_value 是否和 condition_to_meet 相等.
        // 如果不等, 那么重新进入循环, [_condition waitUntilDate: limitDate] 中调用 wait 方法, 又会释放锁.
        if (condition_to_meet == _condition_value)
        {
            return YES;   // Keeping the lock
        }
    }
    [_condition unlock];
    return NO;            // Not locked
}

MNAME
MSTACK

- (BOOL) tryLock
{
    return [_condition tryLock];
}

- (BOOL) tryLockWhenCondition: (NSInteger)condition_to_meet
{
    if ([_condition tryLock])
    {
        if (condition_to_meet == _condition_value)
        {
            return YES; // KEEP THE LOCK
        }
        else
        {
            [_condition unlock];
        }
    }
    return NO;
}

- (void) unlock
{
    [_condition unlock];
}

- (void) unlockWithCondition: (NSInteger)value
{
    _condition_value = value;
    [_condition broadcast];
    [_condition unlock];
}

@end



/* Versions of the lock classes where the locking is unconditionally traced
 */

#undef CHKT
#define CHKT(T,X) \
{ \
NSString *msg = [T mutex ## X: self]; \
if (nil != msg) \
{ \
(*_NSLock_error_handler)(self, _cmd, YES, msg); \
} \
}
#undef CHK
#define CHK(X) CHKT(GSCurrentThread(), X)

#undef  MDEALLOC
#define	MDEALLOC \
- (void) dealloc \
{ \
DESTROY(stack); \
[super dealloc]; \
}

#undef MLOCK
#define	MLOCK \
- (void) lock\
{ \
NSThread      *t = GSCurrentThread(); \
int		err; \
CHKT(t,Wait) \
err = pthread_mutex_lock(&_mutex);\
if (EDEADLK == err)\
{\
CHKT(t,Drop) \
(*_NSLock_error_handler)(self, _cmd, YES, @"deadlock");\
}\
else if (err != 0)\
{\
CHKT(t,Drop) \
[NSException raise: NSLockException format: @"failed to lock mutex"];\
}\
CHKT(t,Hold) \
}

#undef MSTACK
#define MSTACK \
- (GSStackTrace*) stack \
{ \
if (nil == stack) \
{ \
stack = [GSStackTrace new]; \
} \
return stack; \
}

@implementation GSTracedCondition
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(tracedConditionClass, 0);
}
MDEALLOC
MLOCK
MLOCKBEFOREDATE
MSTACK
MTRYLOCK

- (void) wait
{
    NSThread      *t = GSCurrentThread();
    CHKT(t,Drop)
    CHKT(t,Wait)
    pthread_cond_wait(&_condition, &_mutex);
    CHKT(t,Hold)
}

- (BOOL) waitUntilDate: (NSDate*)limit
{
    NSTimeInterval ti = [limit timeIntervalSince1970];
    NSThread      *t = GSCurrentThread();
    double secs, subsecs;
    struct timespec timeout;
    int retVal = 0;
    
    // Split the float into seconds and fractions of a second
    subsecs = modf(ti, &secs);
    timeout.tv_sec = secs;
    // Convert fractions of a second to nanoseconds
    timeout.tv_nsec = subsecs * 1e9;
    
    /* NB. On timeout the lock is still held even through condition is not met
     */
    
    CHKT(t,Drop)
    retVal = pthread_cond_timedwait(&_condition, &_mutex, &timeout);
    if (retVal == 0)
    {
        CHKT(t,Hold)
        return YES;
    }
    if (retVal == ETIMEDOUT)
    {
        CHKT(t,Hold)
        return NO;
    }
    
    if (retVal == EINVAL)
    {
        NSLog(@"Invalid arguments to pthread_cond_timedwait");
    }
    return NO;
}

MUNLOCK
@end
@implementation GSTracedConditionLock
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(tracedConditionLockClass, 0);
}
- (id) initWithCondition: (NSInteger)value
{
    if (nil != (self = [super init]))
    {
        if (nil == (_condition = [GSTracedCondition new]))
        {
            DESTROY(self);
        }
        else
        {
            _condition_value = value;
            [_condition setName:
             [NSString stringWithFormat: @"condition-for-lock-%p", self]];
        }
    }
    return self;
}
@end
@implementation GSTracedLock
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(tracedLockClass, 0);
}
MDEALLOC
MLOCK
MLOCKBEFOREDATE
MSTACK
MTRYLOCK
MUNLOCK
@end
@implementation GSTracedRecursiveLock
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(tracedRecursiveLockClass, 0);
}
MDEALLOC
MLOCK
MLOCKBEFOREDATE
MSTACK
MTRYLOCK
MUNLOCK
@end


/* Versions of the lock classes where the locking is never traced
 */
@implementation GSUntracedCondition
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(baseConditionClass, 0);
}
@end
@implementation GSUntracedConditionLock
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(baseConditionLockClass, 0);
}
@end
@implementation GSUntracedLock
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(baseRecursiveLockClass, 0);
}
@end
@implementation GSUntracedRecursiveLock
+ (id) allocWithZone: (NSZone*)z
{
    return class_createInstance(baseRecursiveLockClass, 0);
}
@end

