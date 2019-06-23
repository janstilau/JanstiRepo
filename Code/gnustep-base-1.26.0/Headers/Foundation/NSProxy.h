#ifndef __NSProxy_h_GNUSTEP_BASE_INCLUDE
#define __NSProxy_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

GS_ROOT_CLASS @interface NSProxy <NSObject>
{
@public
    Class	isa;
#if !(GS_NONFRAGILE == 1)
@private
	/**
	 * Legacy compatibility ivar.  Remove in the next ABI-breaking release.
	 */
    NSUInteger	_retain_count;
#endif
}

+ (id) alloc;
+ (id) allocWithZone: (NSZone*)z;
+ (id) autorelease;
+ (Class) class;
+ (NSString*) description;
+ (BOOL) isKindOfClass: (Class)aClass;
+ (BOOL) isMemberOfClass: (Class)aClass;
/** <override-dummy />
 */
+ (void) load;
/** <override-dummy />
 */
+ (oneway void) release;
+ (BOOL) respondsToSelector: (SEL)aSelector;
+ (id) retain;
+ (NSUInteger) retainCount;

- (id) autorelease;
- (Class) class;
- (BOOL) conformsToProtocol: (Protocol*)aProtocol;
- (void) dealloc;
- (NSString*) description;
- (void) forwardInvocation: (NSInvocation*)anInvocation;
- (NSUInteger) hash;
- (id) init;
- (BOOL) isEqual: (id)anObject;
- (BOOL) isKindOfClass: (Class)aClass;
- (BOOL) isMemberOfClass: (Class)aClass;
- (BOOL) isProxy;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;
- (oneway void) release;
- (BOOL) respondsToSelector: (SEL)aSelector;
- (id) retain;
- (NSUInteger) retainCount;
- (id) self;
- (Class) superclass;
- (NSZone*) zone;

@end

#if	defined(__cplusplus)
}
#endif

#endif /* __NSProxy_h_GNUSTEP_BASE_INCLUDE */
