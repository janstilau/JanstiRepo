
#import "common.h"
#define	EXPOSE_NSPort_IVARS	1
#import "Foundation/NSException.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSPort.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSPortNameServer.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSUserDefaults.h"
#import "GSPrivate.h"


@class NSMessagePort;

@implementation NSObject(NSPortDelegateMethods)
- (void) handlePortMessage: (NSPortMessage*)aMessage
{
}
@end

@implementation NSPort

NSString * const NSInvalidReceivePortException
  = @"NSInvalidReceivePortException";
NSString * const NSInvalidSendPortException
  = @"NSInvalidSendPortException";
NSString * const NSPortReceiveException
  = @"NSPortReceiveException";
NSString * const NSPortSendException
  = @"NSPortSendException";
NSString * const NSPortTimeoutException
  = @"NSPortTimeoutException";

static Class	NSPort_abstract_class;
static Class	NSPort_concrete_class;

+ (id) allocWithZone: (NSZone*)aZone
{
  if (self == NSPort_abstract_class)
    {
      return NSAllocateObject(NSPort_concrete_class, 0, aZone);
    }
  else
    {
      return NSAllocateObject(self, 0, aZone);
    }
}

+ (void) initialize
{
  if (self == [NSPort class])
    {
      NSUserDefaults	*defs;

      GSMakeWeakPointer(self, "delegate");

      NSPort_abstract_class = self;
      NSPort_concrete_class = [NSMessagePort class];

      defs = [NSUserDefaults standardUserDefaults];
      if ([defs objectForKey: @"NSPortIsMessagePort"] != nil
	&& [defs boolForKey: @"NSPortIsMessagePort"] == NO)
	{
	  NSPort_concrete_class = [NSSocketPort class];
	}
    }
}

+ (NSPort*) port
{
  if (self == NSPort_abstract_class)
    return AUTORELEASE([NSPort_concrete_class new]);
  else
    return AUTORELEASE([self new]);
}

+ (NSPort*) portWithMachPort: (NSInteger)machPort
{
  return AUTORELEASE([[self alloc] initWithMachPort: machPort]);
}

- (id) copyWithZone: (NSZone*)aZone
{
  return RETAIN(self);
}

- (id) delegate
{
  return _delegate;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [(NSPortCoder*)aCoder encodePortObject: self];
}

- (id) init
{
  self = [super init];
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  id	obj = [(NSPortCoder*)aCoder decodePortObject];

  if (obj != self)
    {
      DESTROY(self);
      self = RETAIN(obj);
    }
  return self;
}

- (id) initWithMachPort: (NSInteger)machPort
{
  [self shouldNotImplement: _cmd];
  return nil;
}

/*
 *	subclasses should override this method and call [super invalidate]
 *	in their versions of the method.
 */
- (void) invalidate
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  _is_valid = NO;
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSPortDidBecomeInvalidNotification
		  object: self];
  [arp drain];
}

- (BOOL) isValid
{
  return _is_valid;
}

- (NSInteger) machPort
{
  [self shouldNotImplement: _cmd];
  return 0;
}

- (id) retain
{
  return [super retain];
}

- (id) autorelease
{
  return [super autorelease];
}

- (oneway void) release
{
  if (_is_valid && [self retainCount] == 1)
    {
      /*
       * If the port is about to have a final release deallocate it
       * we must invalidate it.
       * Bracket with retain/release pair to prevent recursion.
       */
      [super retain];
      [self invalidate];
      [super release];
    }
  [super release];
}

- (void) setDelegate: (id) anObject
{
  NSAssert(anObject == nil
    || [anObject respondsToSelector: @selector(handlePortMessage:)],
    NSInvalidArgumentException);
  _delegate = anObject;
}

- (void) addConnection: (NSConnection*)aConnection
             toRunLoop: (NSRunLoop*)aLoop
               forMode: (NSString*)aMode
{
  [aLoop addPort: self forMode: aMode];
}

- (void) removeConnection: (NSConnection*)aConnection
              fromRunLoop: (NSRunLoop*)aLoop
                  forMode: (NSString*)aMode
{
  [aLoop removePort: self forMode: aMode];
}

- (NSUInteger) reservedSpaceLength
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL) sendBeforeDate: (NSDate*)when
             components: (NSMutableArray*)components
                   from: (NSPort*)receivingPort
               reserved: (NSUInteger)length
{
  return [self sendBeforeDate: when
			msgid: 0
		   components: components
			 from: receivingPort
		     reserved: length];
}

- (BOOL) sendBeforeDate: (NSDate*)when
		  msgid: (NSInteger)msgid
             components: (NSMutableArray*)components
                   from: (NSPort*)receivingPort
               reserved: (NSUInteger)length
{
  [self subclassResponsibility: _cmd];
  return YES;
}

@end

/*
 * This is a callback method used by the NSRunLoop class to determine which
 * descriptors to watch for the port.  Subclasses override it.
 */
@implementation	NSPort (GNUstep)
- (void) getFds: (NSInteger*)fds count: (NSInteger*)count
{
  *count = 0;
}
@end