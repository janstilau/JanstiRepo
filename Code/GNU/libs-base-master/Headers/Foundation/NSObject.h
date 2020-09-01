#ifndef __NSObject_h_GNUSTEP_BASE_INCLUDE
#define __NSObject_h_GNUSTEP_BASE_INCLUDE

#import	<Foundation/NSObjCRuntime.h>
#import <objc/objc.h>
#import	<Foundation/NSZone.h>

#ifdef	GS_WITH_GC
#undef  GS_WITH_GC
#endif
#define	GS_WITH_GC	0

#import	<GNUstepBase/GNUstep.h>

@class NSArchiver;
@class NSArray;
@class NSCoder;
@class NSDictionary;
@class NSPortCoder;
@class NSMethodSignature;
@class NSMutableString;
@class NSRecursiveLock;
@class NSString;
@class NSInvocation;
@class Protocol;

/*
 一个, 所有的对象都应该遵守的协议.
 */
@protocol NSObject

- (Class) class;

- (Class) superclass;

- (BOOL) isEqual: (id)anObject;

- (BOOL) isKindOfClass: (Class)aClass;

- (BOOL) isMemberOfClass: (Class)aClass;

- (BOOL) isProxy;

- (NSUInteger) hash;

- (id) self;

- (id) performSelector: (SEL)aSelector;

- (id) performSelector: (SEL)aSelector
            withObject: (id)anObject;
- (id) performSelector: (SEL)aSelector
            withObject: (id)object1
            withObject: (id)object2;

- (BOOL) respondsToSelector: (SEL)aSelector;

- (BOOL) conformsToProtocol: (Protocol*)aProtocol;

- (id) retain NS_AUTOMATED_REFCOUNT_UNAVAILABLE;

- (oneway void) release NS_AUTOMATED_REFCOUNT_UNAVAILABLE;

- (id) autorelease NS_AUTOMATED_REFCOUNT_UNAVAILABLE;

- (NSUInteger) retainCount NS_AUTOMATED_REFCOUNT_UNAVAILABLE;

- (NSString*) description;

- (NSZone*) zone NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
@end


@protocol NSCopying

- (id) copyWithZone: (NSZone*)zone;

@end

@protocol NSMutableCopying

- (id) mutableCopyWithZone: (NSZone*)zone;

@end


@protocol NSCoding

- (void) encodeWithCoder: (NSCoder*)aCoder;

- (id) initWithCoder: (NSCoder*)aDecoder;

@end

@protocol NSSecureCoding <NSCoding>
+ (BOOL)supportsSecureCoding;
@end


GS_ROOT_CLASS @interface NSObject <NSObject>
{
    /*
      isa 指针是 runtime 的基础. 这个指针的值, 是在 alloc 期间限定的.
     */
    Class isa;
}

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
/** On a system which performs garbage collection, you should implement
 * this method to execute code when the receiver is collected.<br />
 * You must not call this method yourself (except when a subclass
 * calls the superclass method within its own implementation).
 */
- (void) finalize;
#endif

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (NSString*) className;
#endif

+ (id) allocWithZone: (NSZone*)z;
+ (id) alloc;
+ (Class) class;

/**
 * This method is automatically invoked on any class which implements it
 * when the class is loaded into the runtime.<br />
 * It is also invoked on any category where the method is implemented
 * when that category is loaded into the runtime.<br />
 * The +load method is called directly by the runtime and you should never
 * send a +load message to a class yourself.<br />
 * This method is called <em>before</em> the +initialize message is sent
 * to the class, so you cannot depend on class initialisation having been
 * performed, or upon other classes existing (apart from superclasses of
 * the receiver, since +load is called on superclasses before it is called
 * on their subclasses).<br />
 * As a gross generalisation, it is safe to use C code, including
 * most ObjectiveC runtime functions within +load, but attempting to send
 * messages to ObjectiveC objects is likely to fail.<br />
 * In GNUstep, this method is implemented for NSObject to perform some
 * initialisation for the base library.<br />
 * If you implement +load for a class, don't call [super load] in your
 * implementation.
 */
/*
 OC 系统提供的, 一个进行初始化操作的方法.
 当这个类被加载到 runtime 的时候, 自动调用这个方法.
 当一个分类被加载进来的时候, 也会调用该方法.
 */
+ (void) load;

/**
 * This message is automatically sent to a class by the runtime.  It is
 * sent once for each class, just before the class is used for the first
 * time (excluding any automatic call to +load by the runtime).<br />
 * The message is sent in a thread-safe manner ... other threads may not
 * call methods of the class until +initialize has finished executing.<br />
 * If the class has a superclass, its implementation of +initialize is
 * called first.<br />
 * If the class does not implement +initialize then the implementation
 * in the closest superclass may be called.  This means that +initialize may
 * be called more than once, and the recommended way to handle this by
 * using the
 * <code>
 * if (self == [classname class])
 * </code>
 * conditional to check whether the method is being called for a subclass.<br />
 * You should never call +initialize yourself ... let the runtime do it.<br />
 * You can implement +initialize in your own class if you need to.
 * NSObject's implementation handles essential root object and base
 * library initialization.<br />
 * It should be safe to call [super initialize] in your implementation
 * of +initialize.
 */
+ (void) initialize;
+ (IMP) instanceMethodForSelector: (SEL)aSelector;
+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector;
+ (BOOL) instancesRespondToSelector: (SEL)aSelector;
+ (BOOL) isSubclassOfClass: (Class)aClass;
+ (id) new;
+ (void) poseAsClass: (Class)aClassObject;
+ (id) setVersion: (NSInteger)aVersion;
+ (NSInteger) version;

- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder;
- (Class) classForArchiver;
- (Class) classForCoder;
- (id) copy;
- (void) dealloc;
- (void) doesNotRecognizeSelector: (SEL)aSelector;
- (void) forwardInvocation: (NSInvocation*)anInvocation;
- (id) init;
- (IMP) methodForSelector: (SEL)aSelector;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;
- (id) mutableCopy;
- (id) replacementObjectForArchiver: (NSArchiver*)anArchiver;
- (id) replacementObjectForCoder: (NSCoder*)anEncoder;
- (Class) superclass;
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
/**
 * This method will be called when attempting to send a message a class that
 * does not understand it.  The class may install a new method for the given
 * selector and return YES, otherwise it should return NO.
 *
 * Note: This method is only reliable when using the GNUstep runtime.  If you
 * require compatibility with the GCC runtime, you must also implement
 * -forwardInvocation: with equivalent semantics.  This will be considerably
 *  slower, but more portable.
 */
+ (BOOL) resolveClassMethod: (SEL)name;

/**
 * This method will be called when attempting to send a message an instance
 * that does not understand it.  The class may install a new method for the
 * given selector and return YES, otherwise it should return NO.
 *
 * Note: This method is only reliable when using the GNUstep runtime.  If you
 * require compatibility with the GCC runtime, you must also implement
 * -forwardInvocation: with equivalent semantics.  This will be considerably
 *  slower, but more portable.
 */
+ (BOOL) resolveInstanceMethod: (SEL)name;
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Returns an auto-accessing proxy for the given object.  This proxy sends a
 * -beginContentAccess message to the receiver when it is created and an
 * -endContentAccess message when it is destroyed.  This prevents an object
 * that implements the NSDiscardableContent protocol from having its contents
 * discarded for as long as the proxy exists.
 *
 * On systems using the GNUstep runtime, messages send to the proxy will be
 * slightly slower than direct messages.  With the GCC runtime, they will be
 * approximately two orders of magnitude slower.  The GNUstep runtime,
 * therefore, is strongly recommended for code calling this method.
 */
- (id) autoContentAccessingProxy;

/**
 * If an object does not understand a message, it may delegate it to another
 * object.  Returning nil indicates that forwarding should not take place.  The
 * default implementation of this returns nil, but care should be taken when
 * subclassing NSObject subclasses and overriding this method that
 * the superclass implementation is called if returning nil.
 */
- (id) forwardingTargetForSelector: (SEL)aSelector;

#endif
@end

/**
 * Used to allocate memory to hold an object, and initialise the
 * class of the object to be aClass etc.  The allocated memory will
 * be extraBytes larger than the space actually needed to hold the
 * instance variables of the object.<br />
 * This function is used by the [NSObject+allocWithZone:] method.
 */
GS_EXPORT id
NSAllocateObject(Class aClass, NSUInteger extraBytes, NSZone *zone);

/**
 * Used to release the memory used by an object.<br />
 * This function is used by the [NSObject-dealloc] method.
 */
GS_EXPORT void
NSDeallocateObject(id anObject);

/**
 * Used to copy anObject.  This makes a bitwise copy of anObject to
 * memory allocated from zone.  The allocated memory will be extraBytes
 * longer than that necessary to actually store the instance variables
 * of the copied object.<br />
 */
GS_EXPORT NSObject *
NSCopyObject(NSObject *anObject, NSUInteger extraBytes, NSZone *zone);

/**
 * Returns a flag to indicate whether anObject should be retained or
 * copied in order to make a copy in the specified zone.<br />
 * Basically, this tests to see if anObject was allocated from
 * requestedZone and returns YES if it was.
 */
GS_EXPORT BOOL
NSShouldRetainWithZone(NSObject *anObject, NSZone *requestedZone);

GS_EXPORT BOOL
NSDecrementExtraRefCountWasZero(id anObject);

GS_EXPORT NSUInteger
NSExtraRefCount(id anObject);

GS_EXPORT void
NSIncrementExtraRefCount(id anObject);

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)

/** Global lock to be used by classes when operating on any global
 data that invoke other methods which also access global; thus,
 creating the potential for deadlock. */
GS_EXPORT NSRecursiveLock *gnustep_global_lock;

@interface NSObject (NEXTSTEP)
- (id) error:(const char *)aString, ...;
/* - (const char *) name;
 Removed because OpenStep has -(NSString*)name; */
@end

#if GS_API_VERSION(GS_API_NONE, 011700)
@interface NSObject (GNUstep)
+ (void) enableDoubleReleaseCheck: (BOOL)enable;
@end
#endif

#endif

#import	<Foundation/NSDate.h>
/**
 *  Declares some methods for sending messages to self after a fixed delay.
 *  (These methods <em>are</em> in OpenStep and OS X.)
 */
@interface NSObject (TimedPerformers)

/**
 * Cancels any perform operations set up for the specified target
 * in the current run loop.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)obj;

/**
 * Cancels any perform operations set up for the specified target
 * in the current loop, but only if the value of aSelector and argument
 * with which the performs were set up match those supplied.<br />
 * Matching of the argument may be either by pointer equality or by
 * use of the [NSObject-isEqual:] method.
 */
+ (void) cancelPreviousPerformRequestsWithTarget: (id)obj
                                        selector: (SEL)s
                                          object: (id)arg;
/**
 * Sets given message to be sent to this instance after given delay,
 * in any run loop mode.  See [NSRunLoop].
 */
- (void) performSelector: (SEL)s
              withObject: (id)arg
              afterDelay: (NSTimeInterval)seconds;

/**
 * Sets given message to be sent to this instance after given delay,
 * in given run loop modes.  See [NSRunLoop].
 */
- (void) performSelector: (SEL)s
              withObject: (id)arg
              afterDelay: (NSTimeInterval)seconds
                 inModes: (NSArray*)modes;
@end

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * The NSDiscardableContent protocol is used by objects which encapsulate data
 * which may be discarded if resource constraints are exceeded.  These
 * constraints are typically, but not always, related memory.
 */
@protocol NSDiscardableContent

/**
 * This method is called before any access to the object.  It returns YES if
 * the object's content is still valid.  The caller must call -endContentAccess
 * once for every call to -beginContentAccess;
 */
- (BOOL) beginContentAccess;

/**
 * Discards the contents of the object if it is not currently being edited.
 */
- (void) discardContentIfPossible;

/**
 * This method indicates that the caller has finished accessing the contents of
 * the object adopting this protocol.  Every call to -beginContentAccess must
 * be be paired with a call to this method after the caller has finished
 * accessing the contents.
 */
- (void) endContentAccess;

/**
 * Returns YES if the contents of the object have been discarded, either via a
 * call to -discardContentIfPossible while the object is not in use, or by some
 * implementation dependent mechanism.
 */
- (BOOL) isContentDiscarded;
@end
#endif

#if     !NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import <GNUstepBase/NSObject+GNUstepBase.h>
#endif

#endif /* __NSObject_h_GNUSTEP_BASE_INCLUDE */
