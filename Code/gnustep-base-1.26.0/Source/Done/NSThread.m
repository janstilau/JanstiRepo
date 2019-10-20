#import "common.h"

#import "GSPThread.h"

// Dummy implementatation
// cleaner than IFDEF'ing the code everywhere
#if !(HAVE_PTHREAD_SPIN_LOCK)
#warning no spin_locks, using dummy versions
typedef int pthread_spinlock_t;
int pthread_spin_init(pthread_spinlock_t *lock, int pshared)
{
#if DEBUG
    fprintf(stderr,"NSThread.m: Warning this platform does not support spin locks - init.\n");
#endif
    return 0;
}
int pthread_spin_lock(pthread_spinlock_t *lock)
{
    return 0;
}
int pthread_spin_unlock(pthread_spinlock_t *lock)
{
    return 0;
}
int pthread_spin_destroy(pthread_spinlock_t *lock)
{
    return 0;
}
#endif

#define	EXPOSE_NSThread_IVARS	1

#ifdef HAVE_NANOSLEEP
#  include <time.h>
#endif
#ifdef HAVE_SYS_TIME_H
#  include <sys/time.h>
#endif
#ifdef HAVE_SYS_RESOURCE_H
#  include <sys/resource.h>
#endif

#if	defined(HAVE_SYS_FILE_H)
#  include <sys/file.h>
#endif

#if	defined(HAVE_SYS_FCNTL_H)
#  include <sys/fcntl.h>
#elif	defined(HAVE_FCNTL_H)
#  include <fcntl.h>
#endif

#if defined(__POSIX_SOURCE)\
|| defined(__EXT_POSIX1_198808)\
|| defined(O_NONBLOCK)
#define NBLK_OPT     O_NONBLOCK
#else
#define NBLK_OPT     FNDELAY
#endif

#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSConnection.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSValue.h"

#import "GSPrivate.h"
#import "GSRunLoopCtxt.h"

#if defined(HAVE_PTHREAD_NP_H)
#  include <pthread_np.h>
#endif

#if defined(HAVE_GETTID)
#  include <unistd.h>
#  include <sys/syscall.h>
#  include <sys/types.h>
#endif

#define GSInternal      NSThreadInternal
#include        "GSInternal.h"
GS_PRIVATE_INTERNAL(NSThread)

#define pthreadID (internal->_pthreadID)
#define threadID (internal->_threadID)
#define lockInfo (internal->_lockInfo)


#if defined(HAVE_PTHREAD_MAIN_NP)
#  define IS_MAIN_PTHREAD (pthread_main_np() == 1)
#elif defined(HAVE_GETTID)
#  define IS_MAIN_PTHREAD (getpid() == (pid_t)syscall(SYS_gettid))
#else
#  define IS_MAIN_PTHREAD (1)
#endif

/* Return the current thread ID as an unsigned long.
 * Ideally, we use the operating-system's notion of a thread ID so
 * that external process monitoring software will be using the same
 * value that we log.  If we don't know the system's mechanism, we
 * use the address of the current NSThread object so that, even if
 * it makes no sense externally, it can still be used to show that
 * different threads generated different logs.
 */
NSUInteger
GSPrivateThreadID()
{
    return (NSUInteger)GSCurrentThread();
}

#if 0
/*
 * NSThread setName: method for windows.
 * FIXME ... This is code for the microsoft compiler;
 * how do we make it work for gcc/clang?
 */
#include <windows.h>
const DWORD MS_VC_EXCEPTION=0x406D1388;

#pragma pack(push,8)
typedef struct tagTHREADNAME_INFO
{
    DWORD dwType; // Must be 0x1000.
    LPCSTR szName; // Pointer to name (in user addr space).
    DWORD dwThreadID; // Thread ID (-1=caller thread).
    DWORD dwFlags; // Reserved for future use, must be zero.
} THREADNAME_INFO;
#pragma pack(pop)

// Some older BSD systems used a non-standard range of thread priorities.
// Use these if they exist, otherwise define standard ones.
#ifndef PTHREAD_MAX_PRIORITY
#define PTHREAD_MAX_PRIORITY 31
#endif
#ifndef PTHREAD_MIN_PRIORITY
#define PTHREAD_MIN_PRIORITY 0
#endif


@interface NSThread (Activation)
- (void) _makeThreadCurrent;
@end

@interface NSAutoreleasePool (NSThread)
+ (void) _endThread: (NSThread*)thread;
@end

static Class                    threadClass = Nil;
static NSNotificationCenter     *nc = nil;
static BOOL                     disableTraceLocks = NO;

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
@interface GSThreadRelatedPerformHolder : NSObject
{
    id			receiver;
    id			argument;
    SEL			selector;
    NSConditionLock	*lock;		// Not retained.
    NSArray		*modes;
    BOOL                  invalidated;
@public
    NSException           *exception;
}
+ (GSThreadRelatedPerformHolder*) newForReceiver: (id)r
                           argument: (id)a
                           selector: (SEL)s
                              modes: (NSArray*)m
                               lock: (NSConditionLock*)l;
- (void) fire;
- (void) invalidate;
- (BOOL) isInvalidated;
- (NSArray*) modes;
@end

/**
 * Sleep until the current date/time is the specified time interval
 * past the reference date/time.<br />
 * Implemented as a function taking an NSTimeInterval argument in order
 * to avoid objc messaging and object allocation/deallocation (NSDate)
 * overheads.<br />
 * Used to implement [NSThread+sleepUntilDate:]
 * If the date is in the past, this function simply allows other threads
 * (if any) to run.
 */
// 就是不断地调用 yield 函数.
void GSSleepUntilIntervalSinceReferenceDate(NSTimeInterval when)
{
    NSTimeInterval delay;
    
    // delay is always the number of seconds we still need to wait
    delay = when - GSPrivateTimeNow();
    if (delay <= 0.0)
    {
        sched_yield();
        return;
    }
}

static NSArray *
commonModes(void)
{
    static NSArray	*modes = nil;
    
    if (modes == nil)
    {
        [gnustep_global_lock lock];
        if (modes == nil)
        {
            Class	c = NSClassFromString(@"NSApplication");
            SEL	s = @selector(allRunLoopModes);
            
            if (c != 0 && [c respondsToSelector: s])
            {
                modes = RETAIN([c performSelector: s]);
            }
            else
            {
                modes = [[NSArray alloc] initWithObjects:
                         NSDefaultRunLoopMode, NSConnectionReplyMode, nil];
            }
        }
        [gnustep_global_lock unlock];
    }
    return modes;
}

/*
 * Flag indicating whether the objc runtime ever went multi-threaded.
 */
static BOOL	entered_multi_threaded_state = NO;

static NSThread *defaultThread;

static BOOL             keyInitialized = NO;
static pthread_key_t    thread_object_key;


static NSHashTable *_activeThreads = nil; // 一个记录当前正在运转的线程的地方
static pthread_mutex_t _activeLock = PTHREAD_MUTEX_INITIALIZER;

/**
 * pthread_t is an opaque type. It might be a scalar type or
 * some kind of struct depending on the implementation, so we
 * need to wrap it up in an NSValue object if we want to pass
 * it around.
 * This follows the CoreFoundation 'create rule' and returns an object with
 * a reference count of 1.
 */
static inline NSValue* NSValueCreateFromPthread(pthread_t thread)
{
    return [[NSValue alloc] initWithBytes: &thread
                                 objCType: @encode(pthread_t)];
}

/**
 * Conversely, we need to be able to retrieve the pthread_t
 * from an NSValue.
 */
static inline void
_getPthreadFromNSValue(const void *value, pthread_t *thread_ptr)
{
    const char    *enc;
    
    NSCAssert(thread_ptr, @"No storage for thread reference");
# ifndef NS_BLOCK_ASSERTIONS
    enc = [(NSValue*)value objCType];
    NSCAssert(enc != NULL && (0 == strcmp(@encode(pthread_t),enc)),
              @"Invalid NSValue container for thread reference");
# endif
    [(NSValue*)value getValue: (void*)thread_ptr];
}

/**
 * This is the comparison function for boxed pthreads, as used by the
 * NSMapTable containing them.
 */
static BOOL
_boxedPthreadIsEqual(NSMapTable *t,
                     const void *boxed,
                     const void *boxedOther)
{
    pthread_t thread;
    pthread_t otherThread;
    
    _getPthreadFromNSValue(boxed, &thread);
    _getPthreadFromNSValue(boxedOther, &otherThread);
    return pthread_equal(thread, otherThread);
}

/**
 * Since pthread_t is opaque, we cannot make any assumption about how
 * to hash it. There are a few problems here:
 * 1. Functions to obtain the thread ID of an arbitrary thread
 *    exist in the in the Win32 and some pthread APIs (GetThreadId() and
 *    pthread_getunique_np(), respectively), but there is no protable solution
 *    for this problem.
 * 2. Even where pthread_getunique_np() is available, it might have different
 *    definitions, so it's not really robust to use it.
 *
 * For these reasons, we always return the same hash. That fulfills the API
 * contract for NSMapTable (key-hash equality as a necessary condition for key
 * equality), but makes things quite inefficient (linear search over all
 * elements), so we need to keep the table small.
 */
static NSUInteger _boxedPthreadHash(NSMapTable *t, const void *value)
{
    return 0;
}

/**
 * Retain callback for boxed thread references.
 */
static void _boxedPthreadRetain(NSMapTable *t, const void *value)
{
    RETAIN((NSValue*)value);
}

/**
 * Release callback for boxed thread references.
 */
static void _boxedPthreadRelease(NSMapTable *t, void *value)
{
    RELEASE((NSValue*)value);
}

/**
 * Description callback for boxed thread references.
 */
static NSString *_boxedPthreadDescribe(NSMapTable *t, const void *value)
{
    return [(NSValue*)value description];
}


static const NSMapTableKeyCallBacks _boxedPthreadKeyCallBacks =
{
    _boxedPthreadHash,
    _boxedPthreadIsEqual,
    _boxedPthreadRetain,
    _boxedPthreadRelease,
    _boxedPthreadDescribe,
    NULL
};


/**
 * This map table maintains a list of all threads currently undergoing
 * cleanup. This is a required so that +currentThread can still find the
 * thred if called from within the late-cleanup function.
 */
static NSMapTable *_exitingThreads = nil;
static pthread_mutex_t _exitingThreadsLock = PTHREAD_MUTEX_INITIALIZER;


/**
 * Called before late cleanup is run and inserts the NSThread object into the
 * table that is used by GSCurrentThread to find the thread if it is called
 * during cleanup. The boxedThread variable contains a boxed reference to
 * the result of calling pthread_self().
 */
static inline void _willLateUnregisterThread(NSValue *boxedThread,
                                             NSThread *specific)
{
    pthread_mutex_lock(&_exitingThreadsLock);
    /* The map table is created lazily/late so that the NSThread
     * +initialize method can be called without causing other
     * classes to be initialized.
     * NB this locked section cannot be protected by an exception handler
     * because the exception handler stores information in the current
     * thread variables ... which causes recursion.
     */
    if (nil == _exitingThreads)
    {
        _exitingThreads = NSCreateMapTable(_boxedPthreadKeyCallBacks,
                                           NSObjectMapValueCallBacks, 10);
    }
    NSMapInsert(_exitingThreads, (const void*)boxedThread,
                (const void*)specific);
    pthread_mutex_unlock(&_exitingThreadsLock);
}

/**
 * Called after late cleanup has run. Will remove the current thread from
 * the lookup table again. The boxedThread variable contains a boxed reference
 * to the result of calling pthread_self().
 */
static inline void _didLateUnregisterCurrentThread(NSValue *boxedThread)
{
    /* NB this locked section cannot be protected by an exception handler
     * because the exception handler stores information in the current
     * thread variables ... which causes recursion.
     */
    pthread_mutex_lock(&_exitingThreadsLock);
    if (nil != _exitingThreads)
    {
        NSMapRemove(_exitingThreads, (const void*)boxedThread);
    }
    pthread_mutex_unlock(&_exitingThreadsLock);
}

/*
 * Forward declaration of the thread unregistration function
 */
static void
unregisterActiveThread(NSThread *thread);

/**
 * Pthread cleanup call.
 *
 * We should normally not get here ... because threads should exit properly
 * and clean up, so that this function doesn't get called.  However if a
 * thread terminates for some reason without calling the exit method, we
 * we add it to a special lookup table that is used by GSCurrentThread() to
 * obtain the NSThread object.
 * We need to be a bit careful about this regarding object allocation because
 * we must not call into NSAutoreleasePool unless the NSThread object can still
 * be found using GSCurrentThread()
 */
static void exitedThread(void *thread)
{
    if (thread != defaultThread)
    {
        NSValue           *ref;
        
        if (0 == thread)
        {
            /* On some systems this is called with a null thread pointer,
             * so try to get the NSThread object for the current thread.
             */
            thread = pthread_getspecific(thread_object_key);
            if (0 == thread)
            {
                return;	// no thread info
            }
        }
        RETAIN((NSThread*)thread);
        ref = NSValueCreateFromPthread(pthread_self());
        _willLateUnregisterThread(ref, (NSThread*)thread);
        
        {
            CREATE_AUTORELEASE_POOL(arp);
            NS_DURING
            {
                unregisterActiveThread((NSThread*)thread);
            }
            NS_HANDLER
            {
                DESTROY(arp);
                _didLateUnregisterCurrentThread(ref);
                DESTROY(ref);
                RELEASE((NSThread*)thread);
            }
            NS_ENDHANDLER
            DESTROY(arp);
        }
        
        /* At this point threre shouldn't be any autoreleased objects lingering
         * around anymore. So we may remove the thread from the lookup table.
         */
        _didLateUnregisterCurrentThread(ref);
        DESTROY(ref);
        RELEASE((NSThread*)thread);
    }
}

/**
 * These functions needed because sending messages to classes is a seriously
 * slow process with gcc and the gnu runtime.
 */
inline NSThread*
GSCurrentThread(void)
{
    NSThread *thr;
    
    thr = pthread_getspecific(thread_object_key); // 通过  thread_object_key , 获取到当前的 NSThread
    if (nil == thr)
    {
        NSValue *selfThread = NSValueCreateFromPthread(pthread_self());
        
        /* NB this locked section cannot be protected by an exception handler
         * because the exception handler stores information in the current
         * thread variables ... which causes recursion.
         */
        if (nil != _exitingThreads)
        {
            pthread_mutex_lock(&_exitingThreadsLock);
            thr = NSMapGet(_exitingThreads, (const void*)selfThread);
            pthread_mutex_unlock(&_exitingThreadsLock);
        }
        DESTROY(selfThread);
        if (nil == thr)
        {
            GSRegisterCurrentThread();
            thr = pthread_getspecific(thread_object_key);
            if ((nil == defaultThread) && IS_MAIN_PTHREAD)
            {
                defaultThread = RETAIN(thr);
            }
        }
        assert(nil != thr && "No main thread");
    }
    return thr;
}

NSMutableDictionary*
GSDictionaryForThread(NSThread *t)
{
    if (nil == t)
    {
        t = GSCurrentThread();
    }
    return [t threadDictionary];
}

/**
 * Fast access function for thread dictionary of current thread.
 */
NSMutableDictionary*
GSCurrentThreadDictionary(void)
{
    return GSDictionaryForThread(nil);
}

/*
 * Callback function to send notifications on becoming multi-threaded.
 */
static void
gnustep_notify_enterMultiThread(void)
{
    /*
     * Protect this function with locking ... to avoid any possibility
     * of multiple threads registering with the system simultaneously,
     * and so that all NSWillBecomeMultiThreadedNotifications are sent
     * out before any second thread can interfere with anything.
     */
    if (entered_multi_threaded_state == NO)
    {
        [gnustep_global_lock lock];
        if (entered_multi_threaded_state == NO)
        {
            /*
             * For apple compatibility ... and to make things easier for
             * code called indirectly within a will-become-multi-threaded
             * notification handler, we set the flag to say we are multi
             * threaded BEFORE sending the notifications.
             */
            entered_multi_threaded_state = YES;
            NS_DURING
            {
                [GSThreadRelatedPerformHolder class];	// Force initialization
                
                /*
                 * Post a notification if this is the first new thread
                 * to be created.
                 * Won't work properly if threads are not all created
                 * by this class, but it's better than nothing.
                 */
                if (nc == nil)
                {
                    nc = RETAIN([NSNotificationCenter defaultCenter]);
                }
                [nc postNotificationName: NSWillBecomeMultiThreadedNotification
                                  object: nil
                                userInfo: nil];
            }
            NS_HANDLER
            {
                fprintf(stderr,
                        "ALERT ... exception while becoming multi-threaded ... system may not be\n"
                        "properly initialised.\n");
                fflush(stderr);
            }
            NS_ENDHANDLER
        }
        [gnustep_global_lock unlock];
    }
}

@implementation NSThread (Activation)
- (void) _makeThreadCurrent
{
    /* NB. We must set up the pointer to the new NSThread instance from
     * pthread specific memory before we do anything which might need to
     * check what the current thread is (like getting the ID)!
     */
    pthread_setspecific(thread_object_key, self); // 将 NSThread 对象, 和 真正的 pThread 通过 thread_object_key 进行了关联.
    threadID = GSPrivateThreadID();
    pthread_mutex_lock(&_activeLock);
    /* The hash table is created lazily/late so that the NSThread
     * +initialize method can be called without causing other
     * classes to be initialized.
     * NB this locked section cannot be protected by an exception handler
     * because the exception handler stores information in the current
     * thread variables ... which causes recursion.
     */
    if (nil == _activeThreads)
    {
        _activeThreads = NSCreateHashTable(
                                           NSNonRetainedObjectHashCallBacks, 100);
    }
    NSHashInsert(_activeThreads, (const void*)self);
    pthread_mutex_unlock(&_activeLock);
}
@end


// Thread 的实现.


@implementation NSThread

static void
setThreadForCurrentThread(NSThread *t)
{
    [t _makeThreadCurrent];
    gnustep_notify_enterMultiThread();
}

static void
unregisterActiveThread(NSThread *thread)
{
    if (thread->_active == YES)
    {
        /*
         * Set the thread to be inactive to avoid any possibility of recursion.
         */
        thread->_active = NO;
        thread->_finished = YES;
        
        [nc postNotificationName: NSThreadWillExitNotification
                          object: thread
                        userInfo: nil];
        
        [(GSThreadRelatedTaskContainer*)thread->_runLoopInfo threadRelatedTaskContainerInvalidate];
        RELEASE(thread);
        pthread_setspecific(thread_object_key, nil); // 移除 NSThread 的绑定
    }
}

+ (NSArray*) callStackReturnAddresses
{
    GSStackTrace          *stack;
    NSArray               *addrs;
    
    stack = [GSStackTrace new];
    [stack trace];
    addrs = RETAIN([stack addresses]);
    RELEASE(stack);
    return AUTORELEASE(addrs);
}

+ (BOOL) _createThreadForCurrentPthread
{
    NSThread	*t = pthread_getspecific(thread_object_key);
    
    if (t == nil)
    {
        t = [self new];
        t->_active = YES;
        [t _makeThreadCurrent];
        GS_CONSUMED(t);
        if (defaultThread != nil && t != defaultThread)
        {
            gnustep_notify_enterMultiThread();
        }
        return YES;
    }
    return NO;
}

+ (NSThread*) currentThread
{
    return GSCurrentThread();
}

// 仅仅是对 NSThread 方法的一层包装.
+ (void) detachNewThreadSelector: (SEL)aSelector
                        toTarget: (id)aTarget
                      withObject: (id)anArgument
{
    NSThread	*thread;
    
    thread = [[NSThread alloc] initWithTarget: aTarget
                                     selector: aSelector
                                       object: anArgument];
    
    [thread start];
    RELEASE(thread);
}

+ (void) exit
{
    NSThread	*t;
    
    t = GSCurrentThread(); //
    if (t->_active == YES)
    {
        unregisterActiveThread(t); // 在这里, 移除了 Thread 和 pthread 的绑定, 并且修改了 NSThread 里面的值.
        
        if (t == defaultThread || defaultThread == nil)
        {
            /* For the default thread, we exit the process.
             */
            exit(0);
        }
        else
        {
            pthread_exit(NULL); // 操作系统的退出线程.
        }
    }
}

/*
 * Class initialization
 */
+ (void) initialize
{
    if (self == [NSThread class])
    {
        if (NO == keyInitialized)
        {
            if (pthread_key_create(&thread_object_key, exitedThread))
            {
                [NSException raise: NSInternalInconsistencyException
                            format: @"Unable to create thread key!"];
            }
            keyInitialized = YES;
        }
        /* Ensure that the default thread exists.
         * It's safe to create a lock here (since [NSObject+initialize]
         * creates locks, and locks don't depend on any other class),
         * but we want to avoid initialising other classes while we are
         * initialising NSThread.
         */
        threadClass = self;
        GSCurrentThread();
    }
}

+ (BOOL) isMainThread
{
    return (GSCurrentThread() == defaultThread ? YES : NO);
}

+ (BOOL) isMultiThreaded
{
    return entered_multi_threaded_state;
}

+ (NSThread*) mainThread
{
    return defaultThread;
}

+ (void) setThreadPriority: (double)pri
{
    // 直接设置当前线程的优先级.
    int	policy;
    struct sched_param param;
    if (pri > 1) { pri = 1; }
    if (pri < 0) { pri = 0; }
    // Scale pri based on the range of the host system.
    pri *= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);
    pri += PTHREAD_MIN_PRIORITY;
    
    pthread_getschedparam(pthread_self(), &policy, &param);
    param.sched_priority = pri;
    pthread_setschedparam(pthread_self(), policy, &param);
}

+ (void) sleepForTimeInterval: (NSTimeInterval)ti
{
    GSSleepUntilIntervalSinceReferenceDate(GSPrivateTimeNow() + ti); // 不断地调用 yield 就可以了
}

/**
 * Delaying a thread ... pause until the specified date.
 */
+ (void) sleepUntilDate: (NSDate*)date
{
    GSSleepUntilIntervalSinceReferenceDate([date timeIntervalSinceReferenceDate]);
}


/**
 * Return the priority of the current thread.
 */
+ (double) threadPriority
{
    // 直接取当前线程取相应的值.
    double pri = 0;
    int policy;
    struct sched_param param;
    pthread_getschedparam(pthread_self(), &policy, &param);
    pri = param.sched_priority;
    // Scale pri based on the range of the host system.
    pri -= PTHREAD_MIN_PRIORITY;
    pri /= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);
    return pri;
    
}

- (void) cancel
{
    _cancelled = YES;
}

- (void) dealloc
{
    int   retries = 0;
    
    if (_active == YES)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Deallocating an active thread without [+exit]!"];
    }
    DESTROY(_runLoopInfo);
    DESTROY(_thread_dictionary);
    DESTROY(_target);
    DESTROY(_arg);
    DESTROY(_name);
    if (_autorelease_vars.pool_cache != 0)
    {
        [NSAutoreleasePool _endThread: self];
    }
    
    while ((_thread_dictionary != nil || _runLoopInfo != nil) && retries++ < 10)
    {
        /* Try again.
         */
        DESTROY(_runLoopInfo);
        DESTROY(_thread_dictionary);
        if (_autorelease_vars.pool_cache != 0)
        {
            [NSAutoreleasePool _endThread: self];
        }
    }
    
    if (_runLoopInfo != nil)
    {
        NSLog(@"Oops - leak - run loop is %@", _runLoopInfo);
        if (_autorelease_vars.pool_cache != 0)
        {
            [NSAutoreleasePool _endThread: self];
        }
    }
    if (_thread_dictionary != nil)
    {
        NSLog(@"Oops - leak - thread dictionary is %@", _thread_dictionary);
        if (_autorelease_vars.pool_cache != 0)
        {
            [NSAutoreleasePool _endThread: self];
        }
    }
    if (_activeThreads)
    {
        pthread_mutex_lock(&_activeLock);
        NSHashRemove(_activeThreads, self);
        pthread_mutex_unlock(&_activeLock);
    }
    [super dealloc];
}

- (NSString*) description
{
    return [NSString stringWithFormat: @"%@{name = %@, num = %"PRIuPTR"}",
            [super description], _name, threadID];
}

- (id) init
{
    pthread_spin_init(&lockInfo.spin, 0);
    lockInfo.held = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 10);
    init_autorelease_thread_vars(&_autorelease_vars);
    return self;
}

- (id) initWithTarget: (id)aTarget
             selector: (SEL)aSelector
               object: (id)anArgument
{
    if (nil != (self = [self init]))
    {
        _selector = aSelector;
        _target = RETAIN(aTarget);
        _arg = RETAIN(anArgument);
    }
    return self;
}

- (BOOL) isCancelled
{
    return _cancelled;
}

- (BOOL) isExecuting
{
    return _active;
}

- (BOOL) isFinished
{
    return _finished;
}

- (BOOL) isMainThread
{
    return (self == defaultThread ? YES : NO);
}

- (NSString*) name
{
    return _name;
}

- (void) setName: (NSString*)aName
{
    ASSIGN(_name, aName); // zi
}

- (void) setStackSize: (NSUInteger)stackSize
{
    _stackSize = stackSize;
}

- (NSUInteger) stackSize
{
    return _stackSize;
}

/**
 * Trampoline function called to launch the thread
 * Trampoline 鞍马, 发射器.
 * Start 方法, 会调用这个方法, 这个方法, 会调用底层的方法来创建真正的线程.
 */
static void *
nsthreadLauncher(void *thread)
{
    NSThread *t = (NSThread*)thread; // 这里的强转很安全.
    
    setThreadForCurrentThread(t);
    
    // 在一个线程创建之前, 先发通知
    [nc postNotificationName: NSThreadDidStartNotification
                      object: t
                    userInfo: nil];
    [t main];
    [NSThread exit]; // 在执行了NSThread 里面保存的 main 之后, 立马调用 NSThread 的退出方法.
    return NULL;
}

- (void) main
{
    // main 方法, 仅仅是简单的调用一下 target action 而已.
    if (_active == NO)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on inactive thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    [_target performSelector: _selector withObject: _arg];
}

- (void) start
{
    
    /* Make sure the notification is posted BEFORE the new thread starts.
     */
    gnustep_notify_enterMultiThread();
    
    /* The thread must persist until it finishes executing.
     */
    RETAIN(self);
    
    /* Mark the thread as active while it's running.
     */
    _active = YES;
    
    pthread_attr_t    attr;
    pthread_attr_init(&attr);
    /* Create this thread detached, because we never use the return state from
     * threads.
     */
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    /* Set the stack size when the thread is created.  Unlike the old setrlimit
     * code, this actually works.
     */
    if (_stackSize > 0)
    {
        pthread_attr_setstacksize(&attr, _stackSize);
    }
    // pthreadID 作为保留 pthread_create 的输出参数, 保留线程的 ID 值.
    // attr 是创建的参数
    // nsthreadLauncher 是创建线程调用的函数
    // self 作为 nsthreadLauncher 函数的参数值.
    if (pthread_create(&pthreadID, &attr, nsthreadLauncher, self))
    {
        DESTROY(self);
        [NSException raise: NSInternalInconsistencyException
                    format: @"Unable to detach thread (last error %@)",
        [NSError _last]];
    }
}

- (NSMutableDictionary*) threadDictionary
{
    if (_thread_dictionary == nil)
    {
        _thread_dictionary = [NSMutableDictionary new];
    }
    return _thread_dictionary;
}

@end

@implementation GSThreadRelatedTaskContainer

- (void) addPerformer: (id)performer
{
    BOOL  signalled = NO;
    
    [lock lock];
    NSTimeInterval        start = 0.0;
    
    /* The write could concievably fail if the pipe is full.
     * In that case we need to release the lock temporarily to allow the other
     * thread to consume data from the pipe.  It's possible that the thread
     * and its runloop might stop during that ... so we need to check that
     * outputFd is still valid.
     */
    while (outputFd >= 0
           && NO == (signalled = (write(outputFd, "0", 1) == 1) ? YES : NO))
    {
        NSTimeInterval    now = [NSDate timeIntervalSinceReferenceDate];
        
        if (0.0 == start)
        {
            start = now;
        }
        else if (now - start >= 1.0)
        {
            NSLog(@"Unable to signal %@ within a second; blocked?", self);
            break;
        }
        [lock unlock];
        [lock lock];
    }
    
    if (YES == signalled)
    {
        [performers addObject: performer];
    }
    [lock unlock];
    if (NO == signalled)
    {
        /* We failed to add the performer ... so we must invalidate it in
         * case there is code waiting for it to complete.
         */
        [performer invalidate];
    }
}

- (void) dealloc
{
    [self threadRelatedTaskContainerInvalidate];
    DESTROY(lock);
    DESTROY(loop);
    [super dealloc];
}

- (id) init
{
    lock = [NSLock new];
    performers = [NSMutableArray new];
    return self;
}

- (void) threadRelatedTaskContainerInvalidate
{
    NSArray       *p;
    
    [lock lock];
    p = AUTORELEASE(performers);
    performers = nil;
    [lock unlock];
    [p makeObjectsPerformSelector: @selector(timerPerformerInvalidate)];
}

// 这个函数被调用的时机, 应该是切换到相应的线程, 然后调用这个方法来出发之前存储的调用.
- (void) threadRelatedTaskContainerFire
{
    NSArray	*toDo;
    unsigned int	i;
    unsigned int	c;
    
    [lock lock];
    c = [performers count];
    if (0 == c)
    {
        [lock unlock];
        return;
    }
    toDo = [NSArray arrayWithArray: performers]; // 这里进行一次复制, 然后就解锁了, 这让代码段要比最后解锁要少很多.
    [performers removeAllObjects];
    [lock unlock];
    
    for (i = 0; i < c; i++)
    {
        GSThreadRelatedPerformHolder	*h = [toDo objectAtIndex: i];
        // 调用 runloop 的方法, 将存储的任务进行使用.
        [loop performSelector: @selector(timerPerformFire)
                       target: h
                     argument: nil
                        order: 0
                        modes: [h modes]];
    }
}
@end

// 类似于懒加载的机制, 获取当前 Thread 下存储的要执行的任务集合.
GSThreadRelatedTaskContainer *
GSThreadCacheTasks(NSThread *aThread)
{
    GSThreadRelatedTaskContainer   *info;
    
    if (aThread == nil)
    {
        aThread = GSCurrentThread();
    }
    if (aThread->_runLoopInfo == nil)
    {
        [gnustep_global_lock lock];
        if (aThread->_runLoopInfo == nil)
        {
            aThread->_runLoopInfo = [GSThreadRelatedTaskContainer new];
        }
        [gnustep_global_lock unlock];
    }
    info = aThread->_runLoopInfo;
    return info;
}

@implementation GSThreadRelatedPerformHolder

+ (GSThreadRelatedPerformHolder*) newForReceiver: (id)r
                           argument: (id)a
                           selector: (SEL)s
                              modes: (NSArray*)m
                               lock: (NSConditionLock*)l
{
    GSThreadRelatedPerformHolder	*h;
    
    h = (GSThreadRelatedPerformHolder*)NSAllocateObject(self, 0, NSDefaultMallocZone());
    h->receiver = RETAIN(r);
    h->argument = RETAIN(a);
    h->selector = s;
    h->modes = RETAIN(m);
    h->lock = l;
    
    return h;
}

- (void) dealloc
{
    DESTROY(exception);
    DESTROY(receiver);
    DESTROY(argument);
    DESTROY(modes);
    if (lock != nil)
    {
        [lock lock];
        [lock unlockWithCondition: 1];
        lock = nil;
    }
    NSDeallocateObject(self);
    GSNOSUPERDEALLOC;
}

- (void) fire
{
    GSThreadRelatedTaskContainer   *threadInfo;
    
    if (receiver == nil)
    {
        return;	// Already fired!
    }
    threadInfo = GSThreadCacheTasks(GSCurrentThread());
    [threadInfo->loop cancelPerformSelectorsWithTarget: self];
    NS_DURING
    {
        [receiver performSelector: selector withObject: argument];
    }
    NS_HANDLER
    {
        ASSIGN(exception, localException);
        if (nil == lock)
        {
            NSLog(@"*** NSRunLoop ignoring exception '%@' (reason '%@') "
                  @"raised during perform in other thread... with receiver %p "
                  @"and selector '%s'",
                  [localException name], [localException reason], receiver,
                  sel_getName(selector));
        }
    }
    NS_ENDHANDLER
    DESTROY(receiver);
    DESTROY(argument);
    DESTROY(modes);
    if (lock != nil)
    {
        NSConditionLock	*l = lock;
        
        [lock lock];
        lock = nil;
        [l unlockWithCondition: 1];
    }
}

- (void) invalidate
{
    if (invalidated == NO)
    {
        invalidated = YES;
        DESTROY(receiver);
        if (lock != nil)
        {
            NSConditionLock	*l = lock;
            
            [lock lock];
            lock = nil;
            [l unlockWithCondition: 1];
        }
    }
}

- (BOOL) isInvalidated
{
    return invalidated;
}

- (NSArray*) modes
{
    return modes;
}
@end

@implementation	NSObject (NSThreadPerformAdditions)

// NSObject 的对于跨线程操作的包装.

- (void) performSelectorOnMainThread: (SEL)aSelector
                          withObject: (id)anObject
                       waitUntilDone: (BOOL)shouldWait
                               modes: (NSArray*)modes
{
    [self performSelector: aSelector
                 onThread: defaultThread
               withObject: anObject
            waitUntilDone: shouldWait
                    modes: modes];
}

- (void) performSelectorOnMainThread: (SEL)aSelector
                          withObject: (id)anObject
                       waitUntilDone: (BOOL)shouldWait
{
    [self performSelectorOnMainThread: aSelector
                           withObject: anObject
                        waitUntilDone: shouldWait
                                modes: commonModes()];
}

- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)shouldWait
                   modes: (NSArray*)anArray
{
    if ([anArray count] == 0)
    {
        return;
    }
    NSThread *t = GSCurrentThread();
    if (aThread == nil)
    {
        aThread = GSCurrentThread();;
    }
    GSThreadRelatedTaskContainer   *threadTaskContainer = GSThreadCacheTasks(aThread);
    if (t == aThread) // 如果是当前线程下提交任务.
    {
        if (shouldWait == YES || threadTaskContainer->loop == nil) // 如果当前线程的任务, 并且没有开启 runloop, 立即执行.
        {
            /* Wait until done or no run loop.
             */
            [self performSelector: aSelector withObject: anObject];
        } else { // 不用立即使用, 那么就提交给 runloop 在合适的时机在进行调用. 相当于做了任务的存储工作.
            /* Don't wait ... schedule operation in run loop.
             */
            [threadTaskContainer->loop performSelector: aSelector
                                 target: self
                               argument: anObject
                                  order: 0
                                  modes: anArray];
        }
    } else { // 将这个任务存起来, 最后还是要调用runloop 的方法将存起来的方法调用起来.
        GSThreadRelatedPerformHolder   *h;
        NSConditionLock	*lock = nil;
        if (shouldWait == YES) // 如果同步处理.
        {
            lock = [[NSConditionLock alloc] init];
        }
        
        h =
        [GSThreadRelatedPerformHolder newForReceiver: self
                                   argument: anObject
                                   selector: aSelector
                                      modes: anArray
                                       lock: lock];
        [threadTaskContainer addPerformer: h]; // 存起来.
        if (lock != nil)// 需要同步, 就设置同步锁. 这里, 锁必须传出去用于唤醒.
        {
            [lock lockWhenCondition: 1];
            [lock unlock];
            RELEASE(lock);
        }
        RELEASE(h);
    }
}

- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)shouldWait
{
    [self performSelector: aSelector
                 onThread: aThread
               withObject: anObject
            waitUntilDone: shouldWait
                    modes: commonModes()];
}

- (void) performSelectorInBackground: (SEL)aSelector
                          withObject: (id)anObject
{
    [NSThread detachNewThreadSelector: aSelector
                             toTarget: self
                           withObject: anObject];
}

@end

/**
 * <p>
 *   This function is provided to let threads started by some other
 *   software library register themselves to be used with the
 *   GNUstep system.  All such threads should call this function
 *   before attempting to use any GNUstep objects.
 * </p>
 * <p>
 *   Returns <code>YES</code> if the thread can be registered,
 *   <code>NO</code> if it is already registered.
 * </p>
 * <p>
 *   Sends out a <code>NSWillBecomeMultiThreadedNotification</code>
 *   if the process was not already multithreaded.
 * </p>
 */
BOOL
GSRegisterCurrentThread(void)
{
    return [NSThread _createThreadForCurrentPthread];
}

/**
 * <p>
 *   This function is provided to let threads started by some other
 *   software library unregister themselves from the GNUstep threading
 *   system.
 * </p>
 * <p>
 *   Calling this function causes a
 *   <code>NSThreadWillExitNotification</code>
 *   to be sent out, and destroys the GNUstep NSThread object
 *   associated with the thread (like [NSThread+exit]) but does
 *   not exit the underlying thread.
 * </p>
 */
void
GSUnregisterCurrentThread(void)
{
    unregisterActiveThread(GSCurrentThread());
}
