/** Control of executable units within a shared virtual memory space
   Copyright (C) 1996-2010 Free Software Foundation, Inc.

   Original Author:  David Chisnall <csdavec@swan.ac.uk>

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSLock class reference</title>
   <ignore> All autogsdoc markup is in the header
*/

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
 * and later, these will just NSLog a warning instead.  Throwing an exception
 * is probably better behaviour, because it encourages developer to fix their
 * code.
 */

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
  pthread_mutex_destroy(&_mutex);\
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

// 在其他的几个锁的 initialize 方法里面, 调用了 NSLock class 方法, 那么就能确保调用 NSLock 的 initialize 方法
// 这个方法的内部, 是创建几个共用的数据.
+ (void) initialize
{
  static BOOL	beenHere = NO;

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

// lockBeforeDate 的内部逻辑, 就是一个 while 循环, 不断地调用 tryLock. 直到时间超时了. 这里可以看出, 底层的函数, 是没有定时这一个概念, 需要手动创造出定时的这个逻辑出来.
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
      sched_yield();
    } while ([limit timeIntervalSinceNow] > 0);
  return NO;
}

MNAME
MTRYLOCK
MUNLOCK
@end

@implementation NSRecursiveLock

+ (void) initialize
{
  [NSLock class];	// Ensure mutex attributes are set up.
}

MDEALLOC
MDESCRIPTION
MFINALIZE
// 递归所, 仅仅是锁的类别做了修改, 实际上, 和 NSLock 没有什么区别.
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
MTRYLOCK
MUNLOCK
@end

@implementation NSCondition

+ (void) initialize
{
  [NSLock class];	// Ensure mutex attributes are set up.
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

// NSCondition 和 NSLock 的用法在加锁解锁的时候, 没有区别. 只是, 这个类增加了等待, 唤醒的操作.

- (void) signal
{
  pthread_cond_signal(&_condition);
}

- (void) broadcast
{
    pthread_cond_broadcast(&_condition);
}


MTRYLOCK
MUNLOCK

- (void) wait
{
  pthread_cond_wait(&_condition, &_mutex);
}

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

// 这里的逻辑是, 首先加锁, 如果发现当前的_condition_value 不是形参的值, 就进行 wait. wait 操作会释放锁, 这样别的线程就可以进行加锁操作.
// 而别的线程在释放锁之前, 会进行 _condition_value 的赋值, 然后释放锁. 这个时候, 原来线程就可以重新加锁, 然后再次判断 _condition_value 的值.
// 由于这些操作, 都是在加锁之后, 所以, _condition_value 是线程安全的.
// 可以看出, 底层没有那么便利的 api, 可以进行唤醒操作, 还是需要程序员手工控制.
- (void) lockWhenCondition: (NSInteger)value
{
  [_condition lock];
  while (value != _condition_value)
    {
      [_condition wait];
    }
}

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
    {
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

// 这里的 tryLock 之后, 增加了关于 condition 的判断, 如果不满足, 立马进行 unlock
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
