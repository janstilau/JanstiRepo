#ifndef __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#define __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif
    
/*
 A record of the type information for the return value and parameters of a method.
 
 从这里我们可以看出, 它只记录的是 返回值和参数的类型信息.
 它的主要作用, 是当一个消息不能被响应的时候, 把这个消息的一些信息传递给别的对象. 它是 NSInvocation 的一个组成部分.
 NSInvocation 中, 可以记录参数的具体的值, 但是每个值的具体的类型, 是要从 NSMethodSignature 中获取, 猜想是, 可能会有类型转化. 例如
 1.322 是具体的参数值, 但是这个参数可能要的是 int 类型的.
 
Use an NSMethodSignature object to forward messages that the receiving object does not respond to—most notably in the case of distributed objects. You typically create an NSMethodSignature object using the NSObject methodSignatureForSelector: instance method (in macOS 10.5 and later you can also use signatureWithObjCTypes:). It is then used to create an NSInvocation object, which is passed as the argument to a forwardInvocation: message to send the invocation on to whatever other object can handle the message. In the default case, NSObject invokes doesNotRecognizeSelector:, which raises an exception. For distributed objects, the NSInvocation object is encoded using the information in the NSMethodSignature object and sent to the real object represented by the receiver of the message.
 
 An NSMethodSignature object is initialized with an array of characters representing the string encoding of return and argument types for a method. You can get the string encoding of a particular type using the @encode() compiler directive. Because string encodings are implementation-specific, you should not hard-code these values.
 
 For example, the NSString instance method containsString: has a method signature with the following arguments:
 @encode(BOOL) (c) for the return type
 @encode(id) (@) for the receiver (self)
 @encode(SEL) (:) for the selector (_cmd)
 @encode(NSString *) (@) for the first explicit argument
 */
    
/*
 这个类, 会根据 runtime 里面, objc_method 里面记录的 types 的信息, 构建自己的存储的信息. 在自己的存储信息里面, 记录了每个参数的位置, size, 类型等信息, 所以, 这个类是一个纯粹的数据类. NSObject methodSignature 方法, 首先会进行 objc_method 里面记录的 types 信息的提取, 然后将提取出来的信息, 传到这个类的 designated init 中去.
 */

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
  void			*_info; // opaque pointer
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

#if	defined(__cplusplus)
}
#endif

#endif /* __NSMethodSignature_h_GNUSTEP_BASE_INCLUDE */
