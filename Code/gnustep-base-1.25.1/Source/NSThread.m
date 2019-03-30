#import "common.h"
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
#ifdef HAVE_PTHREAD_H
#  include <pthread.h>
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
#import "Foundation/NSThread.h"
#import "Foundation/NSLock.h"
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


@interface NSAutoreleasePool (NSThread)
+ (void) _endThread: (NSThread*)thread;
@end

static Class threadClass = Nil;
static NSNotificationCenter *nc = nil;

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
    id			receiver;
    id			argument;
    SEL			selector;
    NSConditionLock	*lock;		// Not retained.
    NSArray		*modes;
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
// sleep 方法的实现.
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
        sched_yield(); // 让出线程的调度权.
        return;
    }
    
#if     defined(_WIN32)
    /*
     * Avoid integer overflow by breaking up long sleeps.
     牛逼
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
        [gnustep_global_lock lock]; // 线程同步
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
                         NSDefaultRunLoopMode, NSConnectionReplyMode, nil]; // 其实可以直接这样写, 上面可能是为了以后的扩展
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

static pthread_key_t thread_object_key;


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
    // 看样子, 这样可以包装任何的 scalar 类型的数值. 猜测, NSValue 的内部会将这个 scalar 的数据原封不动的保存, NSValue 只是对这层数据的包装, 增加取值函数, 更重要的是, 进行内存, 也就是引用计数的管理操作.
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
    [(NSValue*)value getValue: (void*)thread_ptr]; // 从这里看出, NSValue 就是一层包装.
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
static NSLock *_exitingThreadsLock;

/**
 * Called before late cleanup is run and inserts the NSThread object into the
 * table that is used by GSCurrentThread to find the thread if it is called
 * during cleanup. The boxedThread variable contains a boxed reference to
 * the result of calling pthread_self().
 */
static inline void _willLateUnregisterThread(NSValue *boxedThread,
                                             NSThread *specific)
{
    [_exitingThreadsLock lock];
    /* The map table is created lazily/late so that the NSThread
     * +initilize method can be called without causing other
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
    [_exitingThreadsLock unlock];
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
    [_exitingThreadsLock lock];
    if (nil != _exitingThreads)
    {
        NSMapRemove(_exitingThreads, (const void*)boxedThread);
    }
    [_exitingThreadsLock unlock];
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
             * so try to ger the NSThread object for the current thread.
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
    // 从这里我们看出, thread_object_key 主要就是为了存储 NSThread 对象.
    NSThread *thr = pthread_getspecific(thread_object_key);
    
    // pthread_self是一种函数，功能是获得线程自身的ID。
    if (nil == thr)
    {
        NSValue *selfThread = NSValueCreateFromPthread(pthread_self());
        if (nil != _exitingThreads)
        {
            [_exitingThreadsLock lock]; // 线程同步
            thr = NSMapGet(_exitingThreads, (const void*)selfThread);
            [_exitingThreadsLock unlock];
        }
        DESTROY(selfThread);
    }
    if (nil == thr)
    {
        GSRegisterCurrentThread(); // 在这里面, 一定会有生成线程的操作.
        thr = pthread_getspecific(thread_object_key);
        if ((nil == defaultThread) && IS_MAIN_PTHREAD)
        {
            defaultThread = RETAIN(thr); // default 就是 主线程.
        }
    }
    assert(nil != thr && "No main thread");
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
    return GSDictionaryForThread(nil); // NSThread 通过特殊的 pthread 的函数和线程进行连接, 而每一个 NSThread 里面, 又有一个NSDictionay 作为整个线程的私有数据.
}

/*
 * Callback function to send notifications on becoming multi-threaded.
 */
// 这个方法就是改变一下全局的值, 然后发一个通知而已. 但是它的意义更多的是函数名, 一个进入多线程环境的准备.
static void
gnustep_base_thread_callback(void)
{
    /*
     * Protect this function with locking ... to avoid any possibility
     * of multiple threads registering with the system simultaneously,
     * and so that all NSWillBecomeMultiThreadedNotifications are sent
     * out before any second thread can interfere with anything.
     */
    if (entered_multi_threaded_state == NO) // 对于程序的一个记录量, 表示现在是单线程环境. 在 start 方法里面调用这个, 使得程序变为多线程环境
    {
        [gnustep_global_lock lock]; // double check, 这是多线程的基本操作.
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
                [GSPerformHolder class];	// Force initialization
                
                /*
                 * Post a notification if this is the first new thread
                 * to be created.
                 * Won't work properly if threads are not all created
                 * by this class, but it's better than nothing.
                 */
                if (nc == nil)
                {
                    nc = RETAIN([NSNotificationCenter defaultCenter]); // defaultCenter 是在 NSNotificationCenter 的 initlize 里面生成的.
                }
#if	!defined(HAVE_INITIALIZE)
                if (NO == [[NSUserDefaults standardUserDefaults]
                           boolForKey: @"GSSilenceInitializeWarning"])
                {
                    NSLog(@"WARNING your program is becoming multi-threaded, but you are using an ObjectiveC runtime library which does not have a thread-safe implementation of the +initialize method. Please see README.initialize for more information.");
                }
#endif
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



// NSThread 的类方法, 一般是对于 pthread 方法的封装

// 整个 NSThread 方法, 其实是对于 pthread 方法的封装, 也就是用面向对象的编程管理了原来杂乱无章的 pthread C语言函数. 比如, 是不是主线程这件事, 它其实是在将第一个生成的 NSThread 对象当做 defaultThread, 而这个对象 一定是在主线程里面才能生成的. 通过面向对象的方法, 记录一些公共的值为static 数据, 记录一些和线程相关的值在自己的实例对象里面, 实现了业务的封装处理.

@implementation NSThread

static void
setThreadForCurrentThread(NSThread *t)
{
    pthread_setspecific(thread_object_key, t);
    gnustep_base_thread_callback();
}

// 这个方法, 会在线程退出的时候调用
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
        
        /*
         * Let observers know this thread is exiting.
         */
        if (nc == nil)
        {
            nc = RETAIN([NSNotificationCenter defaultCenter]);
        }
        [nc postNotificationName: NSThreadWillExitNotification
                          object: thread
                        userInfo: nil];
        
        [(GSRunLoopThreadInfo*)thread->_runLoopInfo invalidate];
        RELEASE(thread);
        
        pthread_setspecific(thread_object_key, nil);
    }
}

+ (NSArray*) callStackReturnAddresses
{
    NSMutableArray        *stack = GSPrivateStackAddresses();
    
    return stack;
}

+ (BOOL) _createThreadForCurrentPthread
{
    NSThread	*t = pthread_getspecific(thread_object_key);
    
    if (t == nil)
    {
        t = [self new];
        t->_active = YES;
        pthread_setspecific(thread_object_key, t);
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

+ (void) detachNewThreadSelector: (SEL)aSelector
                        toTarget: (id)aTarget
                      withObject: (id)anArgument
{
    NSThread	*thread;
    
    /*
     * Create the new thread.
     */
    thread = [[NSThread alloc] initWithTarget: aTarget
                                     selector: aSelector
                                       object: anArgument];
    // 类方法, 一般是对于实例方法的封装.
    
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
            /* For the default thread, we exit the process.
             */
            exit(0); // 如果是主线程, 直接退出 app
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

/*
 https://www.jianshu.com/p/d52c1ebf808a 什么是线程存储.
 创建一个类型为pthread_key_t类型的变量。
 调用pthread_key_create()来创建该变量。该函数有两个参数，第一个参数就是上面声明的pthread_key_t变量，第二个参数是一个清理函数，用来在线程释放该线程存储的时候被调用。该函数指针可以设成 NULL，这样系统将调用默认的清理函数。该函数成功返回0.其他任何返回值都表示出现了错误。
 当线程中需要存储特殊值的时候，可以调用 pthread_setspcific() 。该函数有两个参数，第一个为前面声明的pthread_key_t变量，第二个为void*变量，这样你可以存储任何类型的值。
 如果需要取出所存储的值，调用pthread_getspecific()。该函数的参数为前面提到的pthread_key_t变量，该函数返回void *类型的值。下面是前面提到的函数的原型：
 */
+ (void) initialize
{
    if (self == [NSThread class])
    {
        
        if (pthread_key_create(&thread_object_key, exitedThread)) // exitedThread 线程退出的时候的清理函数.
        {
            [NSException raise: NSInternalInconsistencyException
                        format: @"Unable to create thread key!"];
        }
        /* Ensure that the default thread exists.
         * It's safe to create a lock here (since [NSObject+initialize]
         * creates locks, and locks don't depend on any other class),
         * but we want to avoid initialising other classes while we are
         * initialising NSThread.
         */
        threadClass = self;
        _exitingThreadsLock = [NSLock new];
        GSCurrentThread();
    }
}

+ (BOOL) isMainThread
{
    return (GSCurrentThread() == defaultThread ? YES : NO); // 从这里我们看出, NSThread 是存储到线程内部的, 通过 pthread_getspecific 函数获取.
}

+ (BOOL) isMultiThreaded
{
    return entered_multi_threaded_state;
}

+ (NSThread*) mainThread
{
    return defaultThread;
}

/**
 * Set the priority of the current thread.  This is a value in the
 * range 0.0 (lowest) to 1.0 (highest) which is mapped to the underlying
 * system priorities.
 */
+ (void) setThreadPriority: (double)pri
{
#if defined(_POSIX_THREAD_PRIORITY_SCHEDULING) && (_POSIX_THREAD_PRIORITY_SCHEDULING > 0)
    int	policy;
    struct sched_param param;
    
    // Clamp pri into the required range.
    if (pri > 1) { pri = 1; }
    if (pri < 0) { pri = 0; }
    
    // Scale pri based on the range of the host system.
    pri *= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);
    pri += PTHREAD_MIN_PRIORITY;
    
    pthread_getschedparam(pthread_self(), &policy, &param); // 调用底层的 pthread 代码, 将传入的 priority 添加到底层的数据结构中.
    param.sched_priority = pri;
    pthread_setschedparam(pthread_self(), policy, &param);
#endif
}

+ (void) sleepForTimeInterval: (NSTimeInterval)ti
{
    // 底层还是用了 sleep 的方法, 不过这个方法里面有很多的优化.
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
+ (double) threadPriority // 调用底层函数获取底层数据结构中对应的参数.
{
    double pri = 0;
#if defined(_POSIX_THREAD_PRIORITY_SCHEDULING) && (_POSIX_THREAD_PRIORITY_SCHEDULING > 0)
    int policy;
    struct sched_param param;
    
    pthread_getschedparam(pthread_self(), &policy, &param);
    pri = param.sched_priority;
    // Scale pri based on the range of the host system.
    pri -= PTHREAD_MIN_PRIORITY;
    pri /= (PTHREAD_MAX_PRIORITY - PTHREAD_MIN_PRIORITY);
    
#else
#warning Your pthread implementation does not support thread priorities
#endif
    return pri;
    
}



/*
 * Thread instance methods.
 */

- (void) cancel
{
    _cancelled = YES; // 仅仅做一个数据的记录, 这个数据怎么使用, 是另外的函数的事情.
}

- (void) dealloc
{
    int   retries = 0;
    
    if (_active == YES)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Deallocating an active thread without [+exit]!"];
    }
    DESTROY(_runLoopInfo); // 每个 thread 都有的 runloopInfo
    DESTROY(_thread_dictionary); // 这个值?? 没有被用过啊.
    DESTROY(_target); // 启动 的 target
    DESTROY(_arg); // 启动的 arg
    DESTROY(_name); // thread 对应的 name
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
    [super dealloc];
}

- (NSString*) description
{
    return [NSString stringWithFormat: @"%@{name = %@, num = %"PRIuPTR"}",
            [super description], _name, GSPrivateThreadID()];
}

- (id) init
{
    init_autorelease_thread_vars(&_autorelease_vars);
    return self;
}

- (id) initWithTarget: (id)aTarget
             selector: (SEL)aSelector
               object: (id)anArgument
{
    /* initialize our ivars. */
    _selector = aSelector;
    _target = RETAIN(aTarget);
    _arg = RETAIN(anArgument);
    init_autorelease_thread_vars(&_autorelease_vars);
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
    if ([aName isKindOfClass: [NSString class]])
    {
        int       i;
        char      buf[200];
        
        if (YES == [aName getCString: buf
                           maxLength: sizeof(buf)
                            encoding: NSUTF8StringEncoding])
        {
            i = strlen(buf);
        }
        else
        {
            /* Too much for buffer ... truncate on a character boundary.
             */
            i = sizeof(buf) - 1;
            if (buf[i] & 0x80)
            {
                while (i > 0 && (buf[i] & 0x80))
                {
                    buf[i--] = '\0';
                }
            }
            else
            {
                buf[i--] = '\0';
            }
        }
        while (i > 0)
        {
            if (PTHREAD_SETNAME(buf) == 0)
            {
                break;    // Success
            }
            
            if (ERANGE == errno)
            {
                /* Name must be too long ... gnu/linux uses 15 characters
                 */
                if (i > 15)
                {
                    i = 15;
                }
                else
                {
                    i--;
                }
                /* too long a name ... truncate on a character boundary.
                 */
                if (buf[i] & 0x80)
                {
                    while (i > 0 && (buf[i] & 0x80))
                    {
                        buf[i--] = '\0';
                    }
                }
                else
                {
                    buf[i--] = '\0';
                }
            }
            else
            {
                break;    // Some other error
            }
        }
    }
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
    
    setThreadForCurrentThread(t); // 将 thread 对象通过 pthread_setsepecific 方法进行保存.
    
    /*
     * Let observers know a new thread is starting.
     */
    if (nc == nil)
    {
        nc = RETAIN([NSNotificationCenter defaultCenter]);
    }
    [nc postNotificationName: NSThreadDidStartNotification
                      object: t
                    userInfo: nil]; // 发送一个通知.
    
    [t _setName: [t name]]; // 设置一个方法.
    
    [t main]; // main 函数里面, 其实就是调用 target 的 selection 方法.
    
    // 所以说, 线程其实就是一个代码指令, 以及维护这个代码指令执行的相关数据, 也就是 pthread 数据.
    // 而我们如果想要进行 runloop .其实是在 main 里面, 人工制造一个 运行循环, 让 nsthreadLauncher 这个方法, 不会退出.
    
    [NSThread exit]; // 在这个方法里面, 会调用 pthread_exit 方法, 所以下面的 return 语句实际上是不会执行.
    // Not reached
    return NULL; // 返回.
}

// 真正的开始方法.
/*
 这个方法, 就是对于 pthread 方法的封装.
 */
- (void) start
{
    pthread_attr_t	attr;
    pthread_t		thr;
    
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
    if (_finished == YES)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"[%@-%@] called on finished thread",
         NSStringFromClass([self class]),
         NSStringFromSelector(_cmd)];
    }
    
    /* Make sure the notification is posted BEFORE the new thread starts.
     */
    gnustep_base_thread_callback();
    
    /* The thread must persist until it finishes executing.
     */
    RETAIN(self); // thread self.
    
    /* Mark the thread as active whiul it's running.
     */
    _active = YES;
    
    errno = 0;
    pthread_attr_init(&attr);
    /* Create this thread detached, because we never use the return state from
     * threads.
     */
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED); // 而分离线程不是这样子的，它没有被其他的线程所等待，自己运行结束了，线程也就终止了，马上释放系统资源
    /* Set the stack size when the thread is created.  Unlike the old setrlimit
     * code, this actually works.
     */
    if (_stackSize > 0)
    {
        pthread_attr_setstacksize(&attr, _stackSize);
    }
    if (pthread_create(&thr, &attr, nsthreadLauncher, self)) // 生成线程的函数, 所以这里, 其实 thr, 以及 attr 没有被保存起来, 第三个是线程启动要调用的函数, 第四个则是传递给这个函数的参数, 这里是 self
    {
        DESTROY(self);
        [NSException raise: NSInternalInconsistencyException
                    format: @"Unable to detach thread (last error %@)",
         [NSError _last]];
    }
}

/**
 * Return the thread dictionary.  This dictionary can be used to store
 * arbitrary thread specific data.<br />
 * NB. This cannot be autoreleased, since we cannot be sure that the
 * autorelease pool for the thread will continue to exist for the entire
 * life of the thread!
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



@implementation GSRunLoopThreadInfo
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
    [self invalidate];
    DESTROY(lock);
    DESTROY(loop);
    [super dealloc];
}

- (id) init
{
#ifdef _WIN32
    if ((event = CreateEvent(NULL, TRUE, FALSE, NULL)) == INVALID_HANDLE_VALUE)
    {
        DESTROY(self);
        [NSException raise: NSInternalInconsistencyException
                    format: @"Failed to create event to handle perform in thread"];
    }
#else
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
    p = AUTORELEASE(performers); // performers , 如果没有执行, 那么直接释放一点问题没有.
    performers = nil;
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
    [lock unlock];
    [p makeObjectsPerformSelector: @selector(invalidate)];
}

- (void) fire // 在这个时候, 才将原来注册给 Thread 的调用信息, 加到了 runloop 里面. 这是在什么时候呢, 是在 RunloopCtx 里面的 poll 函数中, 也就是在 timer 之后.
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
    toDo = [NSArray arrayWithArray: performers]; // 这样写, 其实是为了拿出缓存来. 就 MCClick 的双数组的概念是一样的.
    [performers removeAllObjects];
    [lock unlock];
    
    for (i = 0; i < c; i++)
    {
        GSPerformHolder	*h = [toDo objectAtIndex: i];
        
        [loop performSelector: @selector(fire) // 在这里, 将注册的所有的 holder 进行了调用. info 的 fire 操作, 是在 RUNLOOP CONTEXT 中进行的.
                       target: h
                     argument: nil
                        order: 0
                        modes: [h modes]];
    }
}
@end

GSRunLoopThreadInfo *
GSRunLoopInfoForThread(NSThread *aThread)
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
            aThread->_runLoopInfo = [GSRunLoopThreadInfo new]; // 一个Thread 里面, 会关联一个 runloopInfo , 不过, 关联式关联, 现在不保证里面就有一个 runloop
        }
        [gnustep_global_lock unlock];
    }
    info = aThread->_runLoopInfo;
    return info;
}

@implementation GSPerformHolder

+ (GSPerformHolder*) newForReceiver: (id)r
                           argument: (id)a
                           selector: (SEL)s
                              modes: (NSArray*)m
                               lock: (NSConditionLock*)l
{
    GSPerformHolder	*h;
    
    h = (GSPerformHolder*)NSAllocateObject(self, 0, NSDefaultMallocZone());
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

- (void) fire // 这个 fire , 就是执行 GSPerformHolder 中记录的方法, 
{
    GSRunLoopThreadInfo   *threadInfo;
    
    if (receiver == nil)
    {
        return;	// Already fired!
    }
    threadInfo = GSRunLoopInfoForThread(GSCurrentThread());
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
            [l unlockWithCondition: 1]; // 这里, performerHolder 不要忘记把之前停到的线程进行唤醒.
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


// NSObject 的扩展方法.
// 这个方法暴露出去是因为主线程实在是太重要了.
@implementation	NSObject (NSThreadPerformAdditions)

- (void) performSelectorOnMainThread: (SEL)aSelector
                          withObject: (id)anObject
                       waitUntilDone: (BOOL)aFlag
                               modes: (NSArray*)anArray
{
    /* It's possible that this method could be called before the NSThread
     * class is initialised, so we check and make sure it's initiailised
     * if necessary.
     */
    if (defaultThread == nil)
    {
        [NSThread currentThread];
    }
    [self performSelector: aSelector
                 onThread: defaultThread
               withObject: anObject
            waitUntilDone: aFlag
                    modes: anArray];
}

- (void) performSelectorOnMainThread: (SEL)aSelector
                          withObject: (id)anObject
                       waitUntilDone: (BOOL)aFlag
{
    [self performSelectorOnMainThread: aSelector
                           withObject: anObject
                        waitUntilDone: aFlag
                                modes: commonModes()]; // 默认是 commonModes
}

// 这个是没有 timed 的概念的. 这里, aThread 的概念仅仅是, 在不同线程的 runloop 进行切换. 就算是一个 runloop 没有开启的线程也没有关系??
- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)shouldWait
                   modes: (NSArray*)runModes
{
    GSRunLoopThreadInfo   *runloopInfo;
    NSThread	        *t;
    
    if ([runModes count] == 0)
    {
        return;
    }
    
    t = GSCurrentThread();
    if (aThread == nil)
    {
        aThread = t;
    }
    runloopInfo = GSRunLoopInfoForThread(aThread);
    if (t == aThread) // 如果调用线程, 就是当前线程.
    {
        /* Perform in current thread.
         */
        if (shouldWait == YES || runloopInfo->loop == nil)
        {
            /* Wait until done or no run loop.
             */
            [self performSelector: aSelector withObject: anObject]; //如果要等待, 或者当前线程没有 runLoop 的话, 就直接执行.
        }
        else
        {
            [runloopInfo->loop performSelector: aSelector
                                 target: self
                               argument: anObject
                                  order: 0
                                  modes: runModes];
            // 如果有 runloop 并且是异步操作, 那么就添加到 runloop 维护的队列中去.
            // 就算这样写也是没有问题的, 因为这里面没有 timer 的
        }
    }
    else
    { // 如果是在另外一个线程执行, 就是讲任务添加到了另外一个线程的 runloop 里面去, 并且通过了 NSConditionLock 这种方式, 控制wait 问题.
        GSPerformHolder   *h;
        NSConditionLock	*l = nil;
        
        if (shouldWait == YES)
        { // 如果是同步操作, 就加一把唤醒锁.
            l = [[NSConditionLock alloc] init];
        }
        
        // 这里是 GSPerformHolder, 还不是直接添加到 runloop 里面.
        h = [GSPerformHolder newForReceiver: self
                                   argument: anObject
                                   selector: aSelector
                                      modes: runModes
                                       lock: l]; // 注意, 这里把 lock 传递过去了, 所以在另外一个线程里面, 进行 unlock, 这里才会进行唤醒操作.
        [runloopInfo addPerformer: h];// 这里, 就讲要完成的操作, 注册给了另外一个线程的 runloopInfo
        if (l != nil)
        {
            // 如果是同步, 那么就进行 condition 锁的处理.
            [l lockWhenCondition: 1];
            // The receiver’s condition must be equal to condition before the locking operation will succeed. This method blocks the thread’s execution until the lock can be acquired.
            [l unlock]; // 这里立马进行了释放 ,因为这个锁的意义, 其实就是等待.
            RELEASE(l);
            if ([h isInvalidated] == YES)
            {
                RELEASE(h);
                [NSException raise: NSInternalInconsistencyException
                            format: @"perform on finished thread"];
            }
            /* If we have an exception passed back from the remote thread,
             * re-raise it.
             */
            if (nil != h->exception)
            {
                NSException       *e = AUTORELEASE(RETAIN(h->exception));
                
                RELEASE(h);
                [e raise];
            }
        }
        RELEASE(h);
    }
}

- (void) performSelector: (SEL)aSelector
                onThread: (NSThread*)aThread
              withObject: (id)anObject
           waitUntilDone: (BOOL)aFlag
{
    [self performSelector: aSelector
                 onThread: aThread
               withObject: anObject
            waitUntilDone: aFlag
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
