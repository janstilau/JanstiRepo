
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

/*
 * Methods shared between NSLock, NSRecursiveLock, and NSCondition
 *
 * Note: These methods currently throw exceptions when locks are incorrectly
 * acquired.  This is compatible with earlier GNUstep behaviour.  In OS X 10.5
 * and later, these will just NSLog a warning instead.
 抛出异常, 是帮助开发者能够更好的进行错误排查.
 Throwing an exception  is probably better behaviour, because it encourages developer to fix their
 * code.
 */

// 从下面的宏可以看出, lock 就是 对于 mutext 的一层封装.

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

#define MFINALIZE \
- (void) finalize\
{\
  pthread_mutex_destroy(&_mutex);\ //释放 mutex
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

// lock, 就是 pthread_mutex_lock 的代用.
#define	MLOCK \
- (void) lock\
{\
  int err = pthread_mutex_lock(&_mutex);\
  if (EINVAL == err)\
    {\
      [NSException raise: NSLockException\
	    format: @"failed to lock mutex"];\
    }\
  if (EDEADLK == err)\
    {\
      _NSLockError(self, _cmd, YES);\
    }\
}

// lockBeforeDate 就是不断的调用 pthread_mutex_trylock, 在调用失败之后, 进行 sched_yield 的操作, 然后在下次获取到调度之后, 判断一下时间有没有到达限定的时间, 如果是的话, 就是 lockBeforeDate 失败了, 如果还没有到达时间, 就继续尝试 pthread_mutex_trylock.
#define	MLOCKBEFOREDATE \
- (BOOL) lockBeforeDate: (NSDate*)limit\
{\
  do\
    {\
      int err = pthread_mutex_trylock(&_mutex);\
      if (0 == err)\
	{\
	  return YES;\
	}\
      sched_yield();\
    } while ([limit timeIntervalSinceNow] > 0);\
  return NO;\
}

// 直接就是 pthread_mutex_trylock 的调用.
#define	MTRYLOCK \
- (BOOL) tryLock\
{\
  int err = pthread_mutex_trylock(&_mutex);\
  return (0 == err) ? YES : NO;\
}

#define	MUNLOCK \
- (void) unlock\
{\
  if (0 != pthread_mutex_unlock(&_mutex))\
    {\
      [NSException raise: NSLockException\
	    format: @"failed to unlock mutex"];\
    }\
}

static pthread_mutex_t deadlock;
static pthread_mutexattr_t attr_normal;
static pthread_mutexattr_t attr_reporting;
static pthread_mutexattr_t attr_recursive;

/*
 * OS X 10.5 compatibility function to allow debugging deadlock conditions.
 */
void _NSLockError(id obj, SEL _cmd, BOOL stop)
{
  NSLog(@"*** -[%@ %@]: deadlock (%@)", [obj class],
    NSStringFromSelector(_cmd), obj);
  NSLog(@"*** Break on _NSLockError() to debug.");
  if (YES == stop)
     pthread_mutex_lock(&deadlock);
}

// Exceptions

NSString *NSLockException = @"NSLockException";

@implementation NSLock

+ (void) initialize
{
  static BOOL	beenHere = NO;
    
 // 应该是, 在GNU的代码里面, 是没有 dispatch 这个概念的, 不然, 为什么有很多 dispatch 可以解决的问题, 都是用的其他的解决方法解决的呢.
    
  if (beenHere == NO)
    {
      beenHere = YES;

      /* Initialise attributes for the different types of mutex.
       * We do it once, since attributes can be shared between multiple
       * mutexes.
       * If we had a pthread_mutexattr_t instance for each mutex, we would
       * either have to store it as an ivar of our NSLock (or similar), or
       * we would potentially leak instances as we couldn't destroy them
       * when destroying the NSLock.  I don't know if any implementation
       * of pthreads actually allocates memory when you call the
       * pthread_mutexattr_init function, but they are allowed to do so
       * (and deallocate the memory in pthread_mutexattr_destroy).
       */
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
    }
}

MDEALLOC
MDESCRIPTION
MFINALIZE

/* Use an error-checking lock.  This is marginally slower, but lets us throw
 * exceptions when incorrect locking occurs.
 */
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
// 前边不是有了宏定义了?? 这一段是我替换的???
- (BOOL) lockBeforeDate: (NSDate*)limit
{
  do
    {
      int err = pthread_mutex_trylock(&_mutex);
      if (0 == err)
	{
	  return YES;
	}
      if (EDEADLK == err)
	{
	  _NSLockError(self, _cmd, NO);
	}
      sched_yield(); // 这个函数, 在之前的资源浏览器里面, 也是用到过很多次. 不过我觉得用这么低级的函数不好, 那个功能用 timer 不应该更好.
    } while ([limit timeIntervalSinceNow] > 0);
  return NO;
}

MNAME
MTRYLOCK
MUNLOCK
@end

@implementation NSRecursiveLock

// 这个类, 和上面的 NSLock 没有任何的区别,  仅仅是 attr_recursive 的替换. 不过, 应该注意的就是 attr_recursive 这个东西 ,这个东西他的意思是这个方法可以重新进入, 不过仅仅限于当前线程中.

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
      if (0 != pthread_mutex_init(&_mutex, &attr_recursive)) // 循环锁有一个特性, 就是只允许自己线程重新进入临界区. 所以, 循环锁还是可以达到线程保护的目的.
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
MTRYLOCK
MUNLOCK
@end

@implementation NSCondition

// 这个类完完全全就是对于 pthread_mutext 的封装而已.

+ (void) initialize
{
  [NSLock class];	// Ensure mutex attributes are set up.
}

- (void) broadcast
{
  pthread_cond_broadcast(&_condition);
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

- (void) signal
{
  pthread_cond_signal(&_condition);
}

MTRYLOCK
MUNLOCK

// 类仅仅是提供了接口, 真正要使用的时候, 应该首先调用 lock, 在获取到当前锁的情况下, 调用 wait.

- (void) wait
{
    pthread_cond_wait(&_condition, &_mutex); // 这个函数, 会释放自己当前已经捕获的 mutex, 然后陷入🔐中, 直到其他的线程进行 singnal, 或者 broadCast 的唤醒. 并且, 唤醒之后, 还要接着重新获取 mutex 才能继续后面的操作;.
}

// 这个没有和 tryLock 那样使用一个循环, 是因为 pthread_cond_timedwait 直接就有这样一个 函数存在.
- (BOOL) waitUntilDate: (NSDate*)limit
{
  NSTimeInterval t = [limit timeIntervalSince1970];
  double secs, subsecs;
  struct timespec timeout;
  int retVal = 0;

  // Split the float into seconds and fractions of a second
  subsecs = modf(t, &secs);
  timeout.tv_sec = secs;
  // Convert fractions of a second to nanoseconds
  timeout.tv_nsec = subsecs * 1e9;

  retVal = pthread_cond_timedwait(&_condition, &_mutex, &timeout);

  if (retVal == 0)
    {
      return YES;
    }
  else if (retVal == EINVAL)
    {
      NSLog(@"Invalid arguments to pthread_cond_timedwait");
    }

  return NO;
}

@end

@implementation NSConditionLock

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

- (void) lockWhenCondition: (NSInteger)value
{
  [_condition lock];
  while (value != _condition_value) // 所以, 在
    {
      [_condition wait]; // 这里, 会进行_condition unlock, 这个是 wait 内部的逻辑
    }
}

// 要注意, 想要通过NSCondition进行线程同步, 不同的线程之间, 首先要用同一把锁才可以.

- (BOOL) lockWhenCondition: (NSInteger)condition_to_meet
                beforeDate: (NSDate*)limitDate
{
  if (NO == [_condition lockBeforeDate: limitDate])
    {
      return NO;
    }
  if (condition_to_meet == _condition_value)
    {
      return YES;
    }
  while ([_condition waitUntilDate: limitDate])
    { // 上面, condition 进行了等待, 然后在等待之后检查值是不是自己想要的值, 如果不是, 继续等待.
      if (condition_to_meet == _condition_value)
	{
	  return YES; // KEEP THE LOCK
	}
    }
  [_condition unlock];
  return NO;
}

MNAME

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
