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

static NSArray	*empty = nil;

@interface	NSOperation (Private)
- (void) _finish;
@end

@implementation NSOperation

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)theKey
{
  /* Handle all KVO manually
   */
  return NO;
}

+ (void) initialize
{
  empty = [NSArray new];
  RELEASE([NSObject leakAt: &empty]);
}

- (void) addDependency: (NSOperation *)op
{
  if (NO == [op isKindOfClass: [NSOperation class]])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] dependency is not an NSOperation",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  if (op == self)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@-%@] attempt to add dependency on self",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  [self->lock lock];
  if (self->dependencies == nil)
    {
      self->dependencies = [[NSMutableArray alloc] initWithCapacity: 5];
    }
  NS_DURING
    {
      if (NSNotFound == [self->dependencies indexOfObjectIdenticalTo: op])
	{
	  [self willChangeValueForKey: @"dependencies"];
          [self->dependencies addObject: op];
	  /* We only need to watch for changes if it's possible for them to
	   * happen and make a difference.
	   */
	  if (NO == [op isFinished]
	    && NO == [self isCancelled]
	    && NO == [self isExecuting]
	    && NO == [self isFinished])
	    {
	      /* Can change readiness if we are neither cancelled nor
	       * executing nor finished.  So we need to observe for the
	       * finish of the dependency.
	       */
	      [op addObserver: self
		   forKeyPath: @"isFinished"
		      options: NSKeyValueObservingOptionNew
		      context: isFinishedCtxt];
	      if (self->ready == YES)
		{
		  /* The new dependency stops us being ready ...
		   * change state.
		   */
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
      [self->lock unlock];
      NSLog(@"Problem adding dependency: %@", localException);
      return;
    }
  NS_ENDHANDLER
  [self->lock unlock];
}

- (void) cancel
{
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

- (GSOperationCompletionBlock) completionBlock
{
  return self->completionBlock;
}

- (void) dealloc
{
  if (self != nil)
    {
      NSOperation	*op;

      if (!self->finished)
        {
          [self removeObserver: self forKeyPath: @"isFinished"];
        }
      while ((op = [self->dependencies lastObject]) != nil)
	{
	  [self removeDependency: op];
	}
      RELEASE(self->dependencies);
      RELEASE(self->cond);
      RELEASE(self->lock);
      RELEASE(self->completionBlock);
      GS_DESTROY_self(NSOperation);
    }
  [super dealloc];
}

- (NSArray *) dependencies
{
  NSArray	*a;

  if (self->dependencies == nil)
    {
      a = empty;	// OSX return an empty array
    }
  else
    {
      [self->lock lock];
      a = [NSArray arrayWithArray: self->dependencies];
      [self->lock unlock];
    }
  return a;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      GS_CREATE_self(NSOperation);
      self->priority = NSOperationQueuePriorityNormal;
      self->threadPriority = 0.5;
      self->ready = YES;
      self->lock = [NSRecursiveLock new];
      [self->lock setName:
        [NSString stringWithFormat: @"lock-for-opqueue-%p", self]];
      self->cond = [[NSConditionLock alloc] initWithCondition: 0];
      [self->cond setName:
        [NSString stringWithFormat: @"cond-for-opqueue-%p", self]];
      [self addObserver: self
             forKeyPath: @"isFinished"
                options: NSKeyValueObservingOptionNew
                context: isFinishedCtxt];
    }
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

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  [self->lock lock];

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
      [self->cond lock];
      [self->cond unlockWithCondition: 1];
      [self->lock unlock];
      return;
    }

  if (NO == self->ready)
    {
      NSEnumerator	*en;
      NSOperation	*op;

      /* Some dependency has finished (or been removed) ...
       * so we need to check to see if we are now ready unless we know we are.
       * This is protected by locks so that an update due to an observed
       * change in one thread won't interrupt anything in another thread.
       */
      en = [self->dependencies objectEnumerator];
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
      [self->lock unlock];
      NSLog(@"Problem removing dependency: %@", localException);
      return;
    }
  NS_ENDHANDLER
  [self->lock unlock];
}

- (void) setCompletionBlock: (GSOperationCompletionBlock)aBlock
{
  ASSIGNCOPY(self->completionBlock, aBlock);
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

- (void) start
{
  ENTER_POOL

  double	prio = [NSThread  threadPriority];

  AUTORELEASE(RETAIN(self));	// Make sure we exist while running.
  [self->lock lock];
  NS_DURING
    {
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
      if (NO == self->executing)
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
      if (NO == [self isCancelled])
	{
	  [NSThread setThreadPriority: self->threadPriority];
	  [self main];
	}
    }
  NS_HANDLER
    {
      [NSThread setThreadPriority:  prio];
      [localException raise];
    }
  NS_ENDHANDLER;

  [self _finish];
  LEAVE_POOL
}

- (double) threadPriority
{
  return self->threadPriority;
}

- (void) waitUntilFinished
{
  [self->cond lockWhenCondition: 1];	// Wait for finish
  [self->cond unlockWithCondition: 1];	// Signal any other watchers
}
@end

@implementation	NSOperation (Private)
- (void) _finish
{
  /* retain while finishing so that we don't get deallocated when our
   * queue removes and releases us.
   */
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
      if (NULL != self->completionBlock)
	{
	  CALL_BLOCK_NO_ARGS(self->completionBlock);
	}
    }
  [self->lock unlock];
  RELEASE(self);
}

@end

	  
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


#undef	GSself
#define	GSself	NSOperationQueueself
#include	"GSself.h"
GS_PRIVATE_self(NSOperationQueue)


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

static NSString	*threadKey = @"NSOperationQueue";
static NSOperationQueue *mainQueue = nil;

@implementation NSOperationQueue

+ (id) currentQueue
{
  if ([NSThread isMainThread])
    {
      return mainQueue;
    }
  return [[[NSThread currentThread] threadDictionary] objectForKey: threadKey];
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
  [self->lock lock];
  if (NSNotFound == [self->operations indexOfObjectIdenticalTo: op]
    && NO == [op isFinished])
    {
      [op addObserver: self
	   forKeyPath: @"isReady"
	      options: NSKeyValueObservingOptionNew
	      context: isReadyCtxt];
      [self willChangeValueForKey: @"operations"];
      [self willChangeValueForKey: @"operationCount"];
      [self->operations addObject: op];
      [self didChangeValueForKey: @"operationCount"];
      [self didChangeValueForKey: @"operations"];
      if (YES == [op isReady])
	{
	  [self observeValueForKeyPath: @"isReady"
			      ofObject: op
				change: nil
			       context: isReadyCtxt];
	}
    }
  [self->lock unlock];
}

- (void) addOperationWithBlock: (GSBlockOperationBlock)block
{
  NSBlockOperation *bop = [NSBlockOperation blockOperationWithBlock: block];
  [self addOperation: bop];
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
          [self->lock lock];
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
          [self->lock unlock];
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
  DESTROY(self->operations);
  DESTROY(self->starting);
  DESTROY(self->waiting);
  DESTROY(self->name);
  DESTROY(self->cond);
  DESTROY(self->lock);
  GS_DESTROY_self(NSOperationQueue);
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      GS_CREATE_self(NSOperationQueue);
      self->suspended = NO;
      self->maxRunningCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
      self->operations = [NSMutableArray new];
      self->starting = [NSMutableArray new];
      self->waiting = [NSMutableArray new];
      self->lock = [NSRecursiveLock new];
      [self->lock setName:
        [NSString stringWithFormat: @"lock-for-op-%p", self]];
      self->cond = [[NSConditionLock alloc] initWithCondition: 0];
      [self->cond setName:
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
  return self->maxRunningCount;
}

- (NSString*) name
{
  NSString	*s;

  [self->lock lock];
  if (self->name == nil)
    {
      self->name
	= [[NSString alloc] initWithFormat: @"NSOperation %p", self];
    }
  s = RETAIN(self->name);
  [self->lock unlock];
  return AUTORELEASE(s);
}

- (NSUInteger) operationCount
{
  NSUInteger	c;

  [self->lock lock];
  c = [self->operations count];
  [self->lock unlock];
  return c;
}

- (NSArray *) operations
{
  NSArray	*a;

  [self->lock lock];
  a = [NSArray arrayWithArray: self->operations];
  [self->lock unlock];
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
  [self->lock lock];
  if (cnt != self->maxRunningCount)
    {
      [self willChangeValueForKey: @"maxConcurrentOperationCount"];
      self->maxRunningCount = cnt;
      [self didChangeValueForKey: @"maxConcurrentOperationCount"];
    }
  [self->lock unlock];
  [self _execute];
}

- (void) setName: (NSString*)s
{
  if (s == nil) s = @"";
  [self->lock lock];
  if (NO == [self->name isEqual: s])
    {
      [self willChangeValueForKey: @"name"];
      RELEASE(self->name);
      self->name = [s copy];
      [self didChangeValueForKey: @"name"];
    }
  [self->lock unlock];
}

- (void) setSuspended: (BOOL)flag
{
  [self->lock lock];
  if (flag != self->suspended)
    {
      [self willChangeValueForKey: @"suspended"];
      self->suspended = flag;
      [self didChangeValueForKey: @"suspended"];
    }
  [self->lock unlock];
  [self _execute];
}

- (void) waitUntilAllOperationsAreFinished
{
  NSOperation	*op;

  [self->lock lock];
  while ((op = [self->operations lastObject]) != nil)
    {
      RETAIN(op);
      [self->lock unlock];
      [op waitUntilFinished];
      RELEASE(op);
      [self->lock lock];
    }
  [self->lock unlock];
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
      [self->lock lock];
      self->executing--;
      [object removeObserver: self forKeyPath: @"isFinished"];
      [self->lock unlock];
      [self willChangeValueForKey: @"operations"];
      [self willChangeValueForKey: @"operationCount"];
      [self->lock lock];
      [self->operations removeObjectIdenticalTo: object];
      [self->lock unlock];
      [self didChangeValueForKey: @"operationCount"];
      [self didChangeValueForKey: @"operations"];
    }
  else if (context == queuePriorityCtxt || context == isReadyCtxt)
    {
      NSInteger pos;

      [self->lock lock];
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
      pos = [self->waiting insertionPosition: object
                                   usingFunction: sortFunc
                                         context: 0];
      [self->waiting insertObject: object atIndex: pos];
      [self->lock unlock];
    }
  [self _execute];
}

- (void) _thread
{
  ENTER_POOL

  [[[NSThread currentThread] threadDictionary] setObject: self
                                                  forKey: threadKey];
  for (;;)
    {
      NSOperation	*op;
      NSDate		*when;
      BOOL		found;

      when = [[NSDate alloc] initWithTimeIntervalSinceNow: 5.0];
      found = [self->cond lockWhenCondition: 1 beforeDate: when];
      RELEASE(when);
      if (NO == found)
	{
	  break;	// Idle for 5 seconds ... exit thread.
	}

      if ([self->starting count] > 0)
	{
          op = RETAIN([self->starting objectAtIndex: 0]);
	  [self->starting removeObjectAtIndex: 0];
	}
      else
	{
	  op = nil;
	}

      if ([self->starting count] > 0)
	{
	  // Signal any other idle threads,
          [self->cond unlockWithCondition: 1];
	}
      else
	{
	  // There are no more operations starting.
          [self->cond unlockWithCondition: 0];
	}

      if (nil != op)
	{
          NS_DURING
	    {
	      ENTER_POOL
              [NSThread setThreadPriority: [op threadPriority]];
              [op start];
	      LEAVE_POOL
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

  [[[NSThread currentThread] threadDictionary] removeObjectForKey: threadKey];
  [self->lock lock];
  self->threadCount--;
  [self->lock unlock];
  LEAVE_POOL
  [NSThread exit];
}

/* Check for operations which can be executed and start them.
 */
- (void) _execute
{
  NSInteger	max;

  [self->lock lock];

  max = [self maxConcurrentOperationCount];
  if (NSOperationQueueDefaultMaxConcurrentOperationCount == max)
    {
      max = maxConcurrent;
    }

  NS_DURING
  while (NO == [self isSuspended]
    && max > self->executing
    && [self->waiting count] > 0)
    {
      NSOperation	*op;

      /* Take the first operation from the queue and start it executing.
       * We set ourselves up as an observer for the operating finishing
       * and we keep track of the count of operations we have started,
       * but the actual startup is left to the NSOperation -start method.
       */
      op = [self->waiting objectAtIndex: 0];
      [self->waiting removeObjectAtIndex: 0];
      [op removeObserver: self forKeyPath: @"queuePriority"];
      [op addObserver: self
	   forKeyPath: @"isFinished"
	      options: NSKeyValueObservingOptionNew
	      context: isFinishedCtxt];
      self->executing++;
      if (YES == [op isConcurrent])
	{
          [op start];
	}
      else
	{
	  NSUInteger	pending;

	  [self->cond lock];
	  pending = [self->starting count];
	  [self->starting addObject: op];

	  /* Create a new thread if all existing threads are busy and
	   * we haven't reached the pool limit.
	   */
	  if (0 == self->threadCount
	    || (pending > 0 && self->threadCount < POOL))
	    {
	      self->threadCount++;
	      NS_DURING
		{
		  [NSThread detachNewThreadSelector: @selector(_thread)
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
	  /* Tell the thread pool that there is an operation to start.
	   */
	  [self->cond unlockWithCondition: 1];
	}
    }
  NS_HANDLER
    {
      [self->lock unlock];
      [localException raise];
    }
  NS_ENDHANDLER
  [self->lock unlock];
}

@end

