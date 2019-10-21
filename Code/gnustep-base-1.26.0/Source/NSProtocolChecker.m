#import "common.h"
#define	EXPOSE_NSProtocolChecker_IVARS	1
#import "Foundation/NSProtocolChecker.h"
#import "Foundation/NSException.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSMethodSignature.h"
#include <objc/Protocol.h>

/**
 * The NSProtocolChecker and NSProxy classes provide message filtering and
 * forwarding capabilities. If you wish to ensure at runtime that a given
 * object will only be sent messages in a certain protocol, you create an
 * <code>NSProtocolChecker</code> instance with the protocol and the object as
 * arguments-

<example>
    id versatileObject = [[ClassWithManyMethods alloc] init];
    id narrowObject = [NSProtocolChecker protocolCheckerWithTarget: versatileObject
                                         protocol: @protocol(SomeSpecificProtocol)];
    return narrowObject;
</example>

 * This is often used in conjunction with distributed objects to expose only a
 * subset of an objects methods to remote processes
 */
@implementation NSProtocolChecker

/**
 * Allocates and initializes an NSProtocolChecker instance by calling
 * -initWithTarget:protocol:<br />
 * Autoreleases and returns the new instance.
 */
+ (id) protocolCheckerWithTarget: (NSObject*)anObject
			protocol: (Protocol*)aProtocol
{
  return AUTORELEASE([[NSProtocolChecker alloc] initWithTarget: anObject
						      protocol: aProtocol]);
}

- (void) dealloc
{
  DESTROY(_myTarget);
  [super dealloc];
}

- (const char *) _protocolTypeForSelector: (SEL)aSel
{
  struct objc_method_description desc;
  desc = GSProtocolGetMethodDescriptionRecursive(_myProtocol, aSel, YES, YES);
  if (desc.name == NULL && desc.types == NULL)
    {
      desc = GSProtocolGetMethodDescriptionRecursive(_myProtocol, aSel, YES, NO);
    }
  return desc.types;
}

/**
 * Forwards any message to the delegate if the method is declared in
 * the checker's protocol; otherwise raises an
 * <code>NSInvalidArgumentException</code>.
 */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  const char	*type;

  if ([self _protocolTypeForSelector: [anInvocation selector]] == NULL)
    {
      if (GSObjCIsInstance(_myTarget))
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"<%s -%@> not declared",
	    protocol_getName(_myProtocol),
              NSStringFromSelector([anInvocation selector])];
	}
      else
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"<%s +%@> not declared",
	    protocol_getName(_myProtocol),
              NSStringFromSelector([anInvocation selector])];
	}
    }
  [anInvocation invokeWithTarget: _myTarget];

  /*
   * If the method returns 'self' (ie the target object) replace the
   * returned value with the protocol checker.
   */
  type = [[anInvocation methodSignature] methodReturnType];
  if (GSSelectorTypesMatch(type, @encode(id)))
    {
      id	buf;

      [anInvocation getReturnValue: &buf];
      if (buf == _myTarget)
	{
	  buf = self;
	  [anInvocation setReturnValue: &buf];
	}
    }
}

- (id) init
{
  self = [self initWithTarget: nil protocol: nil];
  return self;
}

/**
 * Initializes a newly allocated NSProtocolChecker instance that will
 * forward any messages in the aProtocol protocol to anObject, its
 * delegate. Thus, the checker can be vended in lieu of anObject to
 * restrict the messages that can be sent to anObject. If any method
 * in the protocol returns anObject, the checker will replace the returned
 * value with itself rather than the target object.<br />
 * Returns the new instance.
 */
- (id) initWithTarget: (NSObject*)anObject protocol: (Protocol*)aProtocol
{
  _myProtocol = aProtocol;
  ASSIGN(_myTarget, anObject);
  return self;
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  if (_myProtocol != nil)
    {
      const char *types = [self _protocolTypeForSelector: aSelector];
      if (types == NULL)
	{
	  return nil;
	}
      return [NSMethodSignature signatureWithObjCTypes: types];
    }

  return [super methodSignatureForSelector: aSelector];
}

/**
 * Returns the protocol object the checker uses to verify whether a
 * given message should be forwarded to its delegate.
 */
- (Protocol*) protocol
{
  return _myProtocol;
}

/**
 * Returns the target of the NSProtocolChecker.
 */
- (NSObject*) target
{
  return _myTarget;
}

@end
