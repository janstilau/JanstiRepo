#ifndef __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#define __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
/**
 * <p>Class encapsulating type information for method arguments and return
 * value.  It is used as a component of [NSInvocation] to implement message
 * forwarding, such as within the distributed objects framework.  Instances
 * can be obtained from the [NSObject] method
 * [NSObject-methodSignatureForSelector:].</p>
 *
 * <p>Basically, types are represented as Objective-C <code>@encode(...)</code>
 * compatible strings.  The arguments are
 * numbered starting from 0, including the implicit arguments
 * <code><em>self</em></code> (type <code>id</code>, at position 0) and
 * <code><em>_cmd</em></code> (type <code>SEL</code>, at position 1).</p>
 */
@interface NSMethodSignature : NSObject
{
#if	GS_EXPOSE(NSMethodSignature)
@private
  const char		*_methodTypes;
  NSUInteger		_argFrameLength;
  NSUInteger		_numArgs;
  void			*_info;
#endif
}

/**
 * Build a method signature directly from string description of return type and
 * argument types, using the Objective-C <code>@encode(...)</code> type codes.
 */
+ (NSMethodSignature*) signatureWithObjCTypes: (const char*)t;

/**
 * Number of bytes that the full set of arguments occupies on the stack, which
 * is platform(hardware)-dependent.
 */
- (NSUInteger) frameLength;

/**
 * Returns Objective-C <code>@encode(...)</code> compatible string.  Arguments
 * are numbered starting from 0, including the implicit arguments
 * <code><em>self</em></code> (type <code>id</code>, at position 0) and
 * <code><em>_cmd</em></code> (type <code>SEL</code>, at position 1).<br />
 * Type strings may include leading type qualifiers.
 */
- (const char*) getArgumentTypeAtIndex: (NSUInteger)index;

/**
 * Pertains to distributed objects; method is asynchronous when invoked and
 * return should not be waited for.
 */
- (BOOL) isOneway;

/**
 * Number of bytes that the return value occupies on the stack, which is
 * platform(hardware)-dependent.
 */
- (NSUInteger) methodReturnLength;

/**
 * Returns an Objective-C <code>@encode(...)</code> compatible string
 * describing the return type of the method.  This may include type
 * qualifiers.
 */
- (const char*) methodReturnType;

/**
 * Returns number of arguments to method, including the implicit
 * <code><em>self</em></code> and <code><em>_cmd</em></code>.
 */
- (NSUInteger) numberOfArguments;

@end
#endif /* __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE */
