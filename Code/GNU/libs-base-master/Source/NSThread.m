#import "common.h"

#import "GSPThread.h"

// Dummy implementatation
// cleaner than IFDEF'ing the code everywhere
#if !(HAVE_PTHREAD_SPIN_LOCK)
typedef volatile int pthread_spinlock_t;
int pthread_spin_init(pthread_spinlock_t *lock, int pshared)
{
#if DEBUG && !__has_builtin(__sync_bool_compare_and_swap)
    fprintf(stderr,"NSThread.m: Warning this platform does not support spin locks - init.\n");
#endif
    return 0;
}
int pthread_spin_lock(pthread_spinlock_t *lock)
{
#if __has_builtin(__sync_bool_compare_and_swap)
    int count = 0;
    // Set the spin lock value to 1 if it is 0.
    while(!__sync_bool_compare_and_swap(lock, 0, 1))
    {
        count++;
        if (0 == count % 10)
        {
            // If it is already 1, let another thread play with the CPU for a
            // bit then try again.
            sleep(0);
        }
    }
#else
#warning no spin_locks, using dummy versions
#endif
    return 0;
}
int pthread_spin_unlock(pthread_spinlock_t *lock)
{
#if __has_builtin(__sync_bool_compare_and_swap)
    __sync_synchronize();
    *lock = 0;
#endif
    return 0;
}
int pthread_spin_destroy(pthread_spinlock_t *lock)
{
    return 0;
}
#endif

/** Structure for holding lock information for a thread.
 */
typedef struct {
    pthread_spinlock_t    spin;   /* protect access to struct members */
    NSHashTable           *held;  /* all locks/conditions held by thread */
    id                    wait;   /* the lock/condition we are waiting for */
} GSLockInfo;

#define	EXPOSE_NSThread_IVARS	1
#define	GS_NSThread_IVARS \
pthread_t             _pthreadID; \
NSUInteger            _threadID; \
GSLockInfo            _lockInfo


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
#if defined(_WIN32)
    return (NSUInteger)GetCurrentThreadId();
#elif defined(HAVE_GETTID)
    return (NSUInteger)syscall(SYS_gettid);
#elif defined(HAVE_PTHREAD_GETTHREADID_NP)
    return (NSUInteger)pthread_getthreadid_np();
#else
    return (NSUInteger)GSCurrentThread();
#endif
}

#if 0
/*
 * NSThread setName: method for windows.
 * FIXME ... This is code for the microsoft compiler;
 * how do we make it work for gcc/clang?
 */
#if defined(_WIN32) && defined(HAVE_WINDOWS_H)
// Usage: SetThreadName (-1, "MainThread");
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

static int SetThreadName(DWORD dwThreadID, const char *threadName)
{
    THREADNAME_INFO info;
    int result;
    
    info.dwType = 0x1000;
    info.szName = threadName;
    info.dwThreadID = dwThreadID;
    info.dwFlags = 0;
    
    __try
    {
        RaiseException(MS_VC_EXCEPTION, 0,
                       sizeof(info)/sizeof(ULONG_PTR), (ULONG_PTR*)&info);
        result = 0;
    }
    __except(EXCEPTION_EXECUTE_HANDLER)
    {
        result = -1;
    }
}

#define PTHREAD_SETNAME(a)  SetThreadName(-1, a)

#endif
#endif

#ifndef PTHREAD_SETNAME
#define PTHREAD_SETNAME(a) -1
#endif


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
 * Sleep until the current date/time is the specified time interval
 * past the reference date/time.<br />
 * Implemented as a function taking an NSTimeInterval argument in order
 * to avoid objc messaging and object allocation/deallocation (NSDate)
 * overheads.<br />
 * Used to implement [NSThread+sleepUntilDate:]
 * If the date is in the past, this function simply allows other threads
 * (if any) to run.
 */
void
GSSleepUntilIntervalSinceReferenceDate(NSTimeInterval when)
{
    NSTimeInterval delay;
    
    // delay is always the number of seconds we still need to wait
    delay = when - GSPrivateTimeNow();
    if (delay <= 0.0)
    {
        /* We don't need to wait, but since we are willing to wait at this
         * point, we should let other threads have preference over this one.
         */
        sched_yield();
        return;
    }
    
#if     defined(_WIN32)
    /*
     * Avoid integer overflow by breaking up long sleeps.
     */
    while (delay > 30.0*60.0)
    {
        // sleep 30 minutes
        Sleep (30*60*1000);
        delay = when - GSPrivateTimeNow();
    }
    
    /* Don't use nanosleep (even if available) on mingw ... it's reported no
     * to work with pthreads.
     * Sleeping may return early because of signals, so we need to re-calculate
     * the required delay and check to see if we need to sleep again.
     */
    while (delay > 0)
    {
#if	defined(HAVE_USLEEP)
        /* On windows usleep() seems to perform a busy wait ... so we only
         * use it for short delays ... otherwise use the less accurate Sleep()
         */
        if (delay > 0.1)
        {
            Sleep ((NSInteger)(delay*1000));
        }
        else
        {
            usleep ((NSInteger)(delay*1000000));
        }
#else
        Sleep ((NSInteger)(delay*1000));
#endif	/* HAVE_USLEEP */
        delay = when - GSPrivateTimeNow();
    }
    
#else   /* _WIN32 */
    
    /*
     * Avoid integer overflow by breaking up long sleeps.
     */
    while (delay > 30.0*60.0)
    {
        // sleep 30 minutes
        sleep(30*60);
        delay = when - GSPrivateTimeNow();
    }
    
#ifdef	HAVE_NANOSLEEP
    if (delay > 0)
    {
        struct timespec request;
        struct timespec remainder;
        
        request.tv_sec = (time_t)delay;
        request.tv_nsec = (long)((delay - request.tv_sec) * 1000000000);
        remainder.tv_sec = 0;
        remainder.tv_nsec = 0;
        
        /*
         * With nanosleep, we can restart the sleep after a signal by using
         * the remainder information ... so we can be sure to sleep to the
         * desired limit without having to re-generate the delay needed.
         */
        while (nanosleep(&request, &remainder) < 0
               && (remainder.tv_sec > 0 || remainder.tv_nsec > 0))
        {
            request.tv_sec = remainder.tv_sec;
            request.tv_nsec = remainder.tv_nsec;
            remainder.tv_sec = 0;
            remainder.tv_nsec = 0;
        }
    }
#else   /* HAVE_NANOSLEEP */
    
    /*
     * sleeping may return early because of signals, so we need to re-calculate
     * the required delay and check to see if we need to sleep again.
     */
    while (delay > 0)
    {
#if	defined(HAVE_USLEEP)
        usleep((NSInteger)(delay*1000000));
#else	/* HAVE_USLEEP */
        sleep((NSInteger)delay);
#endif	/* !HAVE_USLEEP */
        delay = when - GSPrivateTimeNow();
    }
#endif	/* !HAVE_NANOSLEEP */
#endif	/* !_WIN32 */
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


static NSHashTable *_activeBlocked = nil;
static NSHashTable *_activeThreads = nil;
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

/*
 通过 pthread_getspecific 获取到绑定的 NSThread 对象.
 */
inline NSThread*
GSCurrentThread(void)
{
    NSThread *thr;
    
    if (NO == keyInitialized)
    {
        if (pthread_key_create(&thread_object_key, exitedThread))
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Unable to create thread key!"];
        }
        keyInitialized = YES;
    }
    thr = pthread_getspecific(thread_object_key);
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
 当, 变为 多线程 环境的时候, 会调用该函数. 该函数会在第一次进入多线程的时候, 做一些值的更改. 这里, 基本就是发送一个进入到 多线程环境 的通知而已.
 */
static void
gnustep_base_thread_callback(void)
{
    static pthread_mutex_t  threadLock = PTHREAD_MUTEX_INITIALIZER;
    /*
     Double check.
     */
    if (entered_multi_threaded_state == NO)
    {
        pthread_mutex_lock(&threadLock);
        if (entered_multi_threaded_state == NO)
        {
            ENTER_POOL
            entered_multi_threaded_state = YES;
            NS_DURING
            {
                [GSPerformHolder class];	// Force initialization
                
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
            LEAVE_POOL
        }
        pthread_mutex_unlock(&threadLock);
    }
}

@implementation NSThread (Activation)
- (void) _makeThreadCurrent
{
    /*
     通过, pthread_setspecific, 将一个 NSThread 对象, 关联到真正的 线程 PCB 对象上.
     */
    pthread_setspecific(thread_object_key, self);
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

@implementation NSThread

static void
setThreadForCurrentThread(NSThread *t)
{
    [t _makeThreadCurrent];
    gnustep_base_thread_callback();
}

static void
unregisterActiveThread(NSThread *thread)
{
    if (thread->_active == YES)
    {
        ENTER_POOL
        if (nc == nil)
        {
            nc = RETAIN([NSNotificationCenter defaultCenter]);
        }
        [nc postNotificationName: NSThreadWillExitNotification
                          object: thread
                        userInfo: nil];
        
        /* Set the thread to be finished *after* notification it will exit.
         * This is the order OSX 10.15.4 does it (May 2020).
         */
        thread->_active = NO;
        thread->_finished = YES;
        
        [(GSRunLoopThreadInfo*)thread->_runLoopInfo invalidate];
        LEAVE_POOL
        /*
         这里, 对 thread 对象, 进行了 release 操作.
         */
        RELEASE(thread);
        pthread_setspecific(thread_object_key, nil);
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
            gnustep_base_thread_callback();
        }
        return YES;
    }
    return NO;
}

+ (NSThread*) currentThread
{
    return GSCurrentThread();
}

/*
 一个工厂方法.
 */
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
    
    t = GSCurrentThread();
    if (t->_active == YES)
    {
        unregisterActiveThread(t);
        
        if (t == defaultThread || defaultThread == nil)
        {
            exit(0);
        }
        else
        {
            pthread_exit(NULL);
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

/*
 * Set the priority of the current thread.  This is a value in the
 * range 0.0 (lowest) to 1.0 (highest) which is mapped to the underlying
 * system priorities.
 */
+ (void) setThreadPriority: (double)pri
{
    int	policy;
    struct sched_param param;
    // Clamp pri into the required range.
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
    GSSleepUntilIntervalSinceReferenceDate(GSPrivateTimeNow() + ti);
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

/*
 * Thread instance methods.
 */

- (void) cancel
{
    _cancelled = YES;
}

- (void) dealloc
{
    int   retries = 0;
    
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
    DESTROY(_gcontext);
    if (_activeThreads)
    {
        pthread_mutex_lock(&_activeLock);
        NSHashRemove(_activeThreads, self);
        pthread_mutex_unlock(&_activeLock);
    }
    if (GS_EXISTS_INTERNAL)
    {
        pthread_spin_lock(&lockInfo.spin);
        DESTROY(lockInfo.held);
        lockInfo.wait = nil;
        pthread_spin_unlock(&lockInfo.spin);
        pthread_spin_destroy(&lockInfo.spin);
        if (internal != nil)
        {
            GS_DESTROY_INTERNAL(NSThread);
        }
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
    GS_CREATE_INTERNAL(NSThread);
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
        /* initialize our ivars. */
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

- (void) main
{
    if (_active == NO)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on inactive thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    
    [_target performSelector: _selector withObject: _arg];
}

- (NSString*) name
{
    return _name;
}

- (void) _setName: (NSString *)aName
{
    /*
     这个函数里面, 代码过于复杂, 简单的理解为, 进行了 thread 的name设置就好了.
     */
}

- (void) setName: (NSString*)aName
{
    ASSIGN(_name, aName);
#ifdef PTHREAD_SETNAME
    if (YES == _active)
    {
        [self performSelector: @selector(_setName:)
                     onThread: self
                   withObject: aName
                waitUntilDone: NO];
    }
#endif
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
 */
static void *
nsthreadLauncher(void *thread)
{
    NSThread *t = (NSThread*)thread;
    
    /*
     该函数, 将 PCB 和 NSThread 进行了关联.
     */
    setThreadForCurrentThread(t);
    
    /*
     * Let observers know a new thread is starting.
     */
    if (nc == nil)
    {
        nc = RETAIN([NSNotificationCenter defaultCenter]);
    }
    [nc postNotificationName: NSThreadDidStartNotification
                      object: t
                    userInfo: nil];
    
    [t _setName: [t name]];
    
    /*
     Main 方法, 特别像是 NSOperation 的 main.
     nsthreadLauncher 是一个模板方法, main 方法就是其中可以自定义的方法.
     默认的 main 方法, 就是 target action 的调用.
     */
    [t main];
    
    /*
     NSThread exit 会将当前的 thread 的 active, finish 的状态值改变, 将 pthread 进行退出.
     这也就是 NSThread finish 之后, 不应该使用的原因, NSThread 是一个对象, 但是, 它 finsih 这个对象所代表的实际的操作系统的线程, 已经消亡了.
     */
    [NSThread exit];
    return NULL;
}

- (void) start
{
    pthread_attr_t	attr;
    
    if (_active == YES)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on active thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    
    if (_cancelled == YES)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on cancelled thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    
    /*
     _finished 之后 , 就不应该再在这个 thread 上面提交任务了.
     */
    if (_finished == YES)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on finished thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    
    /*
     当, Thread 没有 finish 之前, 它的生命不会消亡.
     */
    RETAIN(self);
    
    /* Mark the thread as active while it's running.
     */
    _active = YES;
    
    
    
    /*
     下面是真正的线程开启的过程. 可以看到, 和 NSThread 并不是完全相关的, NSThread 应该是关联到 pthread 上.
     */
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
    /*
     真正开启线程, 还是使用了 pthread 的方法. _pthreadID 记录当前的线程 ID
     nsthreadLauncher 作为开启线程的函数. self 作为函数的参数值.
     */
    if (pthread_create(&_pthreadID, &attr, nsthreadLauncher, self))
    {
        DESTROY(self);
    }
}

/*
 一个和 thread 相关的容器.
 有了这个容器, 就可以放任何东西.
 目前 GNU 将 runloop 对象, nsoperationqueue 对象, 都放在了这个容器的内部.
 */
- (NSMutableDictionary*) threadDictionary
{
    if (_thread_dictionary == nil)
    {
        _thread_dictionary = [NSMutableDictionary new];
    }
    return _thread_dictionary;
}

@end



@implementation NSThread (GSLockInfo)

/*
 mutexDrop
 mutexHold
 mutexWait 的实现, 没有发现调用的地方, 都先删了
 */

@end



@implementation GSRunLoopThreadInfo

- (void) addPerformer: (id)performer
{
    BOOL  signalled = NO;
    
    [lock lock];
    {
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
    [self invalidate];
    DESTROY(lock);
    DESTROY(loop);
    [super dealloc];
}

- (id) init
{
    int	fd[2];
    
    if (pipe(fd) == 0)
    {
        int	e;
        
        inputFd = fd[0];
        outputFd = fd[1];
        if ((e = fcntl(inputFd, F_GETFL, 0)) >= 0)
        {
            e |= NBLK_OPT;
            if (fcntl(inputFd, F_SETFL, e) < 0)
            {
                [NSException raise: NSInternalInconsistencyException
                            format: @"Failed to set non block flag for perform in thread"];
            }
        }
        else
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Failed to get non block flag for perform in thread"];
        }
        if ((e = fcntl(outputFd, F_GETFL, 0)) >= 0)
        {
            e |= NBLK_OPT;
            if (fcntl(outputFd, F_SETFL, e) < 0)
            {
                [NSException raise: NSInternalInconsistencyException
                            format: @"Failed to set non block flag for perform in thread"];
            }
        }
        else
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Failed to get non block flag for perform in thread"];
        }
    }
    else
    {
        DESTROY(self);
        [NSException raise: NSInternalInconsistencyException
                    format: @"Failed to create pipe to handle perform in thread"];
    }
#endif
    lock = [NSLock new];
    performers = [NSMutableArray new];
    return self;
}

- (void) invalidate
{
    NSArray       *p;
    
    [lock lock];
    p = AUTORELEASE(performers);
    performers = nil;
#ifdef _WIN32
    if (event != INVALID_HANDLE_VALUE)
    {
        CloseHandle(event);
        event = INVALID_HANDLE_VALUE;
    }
#else
    if (inputFd >= 0)
    {
        close(inputFd);
        inputFd = -1;
    }
    if (outputFd >= 0)
    {
        close(outputFd);
        outputFd = -1;
    }
#endif
    [lock unlock];
    [p makeObjectsPerformSelector: @selector(invalidate)];
}

- (void) fire
{
    NSArray	*toDo;
    unsigned int	i;
    unsigned int	c;
    
    [lock lock];
#if defined(_WIN32)
    if (event != INVALID_HANDLE_VALUE)
    {
        if (ResetEvent(event) == 0)
        {
            NSLog(@"Reset event failed - %@", [NSError _last]);
        }
    }
#else
    if (inputFd >= 0)
    {
        char	buf[BUFSIZ];
        
        /* We don't care how much we read.  If there have been multiple
         * performers queued then there will be multiple bytes available,
         * but we always handle all available performers, so we can also
         * read all available bytes.
         * The descriptor is non-blocking ... so it's safe to ask for more
         * bytes than are available.
         */
        while (read(inputFd, buf, sizeof(buf)) > 0)
            ;
    }
#endif
    
    c = [performers count];
    if (0 == c)
    {
        /* We deal with all available performers each time we fire, so
         * it's likely that we will fire when we have no performers left.
         * In that case we can skip the copying and emptying of the array.
         */
        [lock unlock];
        return;
    }
    toDo = [NSArray arrayWithArray: performers];
    [performers removeAllObjects];
    [lock unlock];
    
    for (i = 0; i < c; i++)
    {
        GSPerformHolder	*h = [toDo objectAtIndex: i];
        
        [loop performSelector: @selector(fire)
                       target: h
                     argument: nil
                        order: 0
                        modes: [h modes]];
    }
}
@end

GSRunLoopThreadInfo * GSRunLoopInfoForThread(NSThread *aThread)
{
    GSRunLoopThreadInfo   *info;
    
    if (aThread == nil)
    {
        aThread = GSCurrentThread();
    }
    if (aThread->_runLoopInfo == nil)
    {
        [gnustep_global_lock lock];
        if (aThread->_runLoopInfo == nil)
        {
            aThread->_runLoopInfo = [GSRunLoopThreadInfo new];
        }
        [gnustep_global_lock unlock];
    }
    info = aThread->_runLoopInfo;
    return info;
}


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
