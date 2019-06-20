/*	NSObject.h
	Copyright (c) 1994-2012, Apple Inc. All rights reserved.
*/

#ifndef _OBJC_NSOBJECT_H_
#define _OBJC_NSOBJECT_H_

#if __OBJC__

#include <objc/objc.h>
#include <objc/NSObjCRuntime.h>

@class NSString, NSMethodSignature, NSInvocation;

@protocol NSObject

/**
 *  默认这个函数是 Receiver 和 object 的 == 比较, 由于 OC 里面并没有操作符重载, 所以就是地址的比较.
 *  这个函数有着很重要的意义, 比如数组的 indexOf 函数判断对象相等就是用的这个方法. 注意是, 用的是这个方法, 而不是 == 地址比较, 也就是说, 各个类可以自定义这个函数, 已达到自定义相等操作的目的.
 
 This method defines what it means for instances to be equal. For example, a container object might define two containers as equal if their corresponding objects all respond YES to an isEqual: request. See the NSData, NSDictionary, NSArray, and NSString class specifications for examples of the use of this method.
 
 If two objects are equal, they must have the same hash value. This last point is particularly important if you define isEqual: in a subclass and intend to put instances of that subclass into a collection. Make sure you also define hash in your subclass.
 */
- (BOOL)isEqual:(id)object;
/**
 * hash 的真正意义, 如果不去学习数据结构的话, 不会有所了解. hash 首先是 hash 容器用到, 用来确定数组的下标, 如果是链式解决冲突的办法, 那么在数组的相应位置, 应该是一个链表, 那么在对于链表的每个对象调用 isEqual 方法. 所以, 一般来说, isEqual 和 hash 方法要一起修改.
 */
@property (readonly) NSUInteger hash;

/**
 * 这个就是直接读取的类对象里面的 superClass. 
 */
@property (readonly) Class superclass;
- (Class)class OBJC_SWIFT_UNAVAILABLE("use 'type(of: anObject)' instead");
- (instancetype)self;

- (id)performSelector:(SEL)aSelector;
- (id)performSelector:(SEL)aSelector withObject:(id)object;
- (id)performSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2;

- (BOOL)isProxy;

- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;

- (BOOL)respondsToSelector:(SEL)aSelector;

- (instancetype)retain OBJC_ARC_UNAVAILABLE;
- (oneway void)release OBJC_ARC_UNAVAILABLE;
- (instancetype)autorelease OBJC_ARC_UNAVAILABLE;
- (NSUInteger)retainCount OBJC_ARC_UNAVAILABLE;

- (struct _NSZone *)zone OBJC_ARC_UNAVAILABLE;

@property (readonly, copy) NSString *description;
@optional
@property (readonly, copy) NSString *debugDescription;

@end


OBJC_AVAILABLE(10.0, 2.0, 9.0, 1.0, 2.0)
OBJC_ROOT_CLASS
OBJC_EXPORT
@interface NSObject <NSObject> {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"
    Class isa  OBJC_ISA_AVAILABILITY;
#pragma clang diagnostic pop
}

+ (void)load;

+ (void)initialize;
- (instancetype)init
#if NS_ENFORCE_NSOBJECT_DESIGNATED_INITIALIZER
    NS_DESIGNATED_INITIALIZER
#endif
    ;

+ (instancetype)new OBJC_SWIFT_UNAVAILABLE("use object initializers instead");
+ (instancetype)allocWithZone:(struct _NSZone *)zone OBJC_SWIFT_UNAVAILABLE("use object initializers instead");
+ (instancetype)alloc OBJC_SWIFT_UNAVAILABLE("use object initializers instead");
- (void)dealloc OBJC_SWIFT_UNAVAILABLE("use 'deinit' to define a de-initializer");

- (void)finalize OBJC_DEPRECATED("Objective-C garbage collection is no longer supported");

- (id)copy;
- (id)mutableCopy;

+ (id)copyWithZone:(struct _NSZone *)zone OBJC_ARC_UNAVAILABLE;
+ (id)mutableCopyWithZone:(struct _NSZone *)zone OBJC_ARC_UNAVAILABLE;

+ (BOOL)instancesRespondToSelector:(SEL)aSelector;
+ (BOOL)conformsToProtocol:(Protocol *)protocol;
- (IMP)methodForSelector:(SEL)aSelector;
+ (IMP)instanceMethodForSelector:(SEL)aSelector;
- (void)doesNotRecognizeSelector:(SEL)aSelector;

- (id)forwardingTargetForSelector:(SEL)aSelector OBJC_AVAILABLE(10.5, 2.0, 9.0, 1.0, 2.0);
- (void)forwardInvocation:(NSInvocation *)anInvocation OBJC_SWIFT_UNAVAILABLE("");
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector OBJC_SWIFT_UNAVAILABLE("");

+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)aSelector OBJC_SWIFT_UNAVAILABLE("");

- (BOOL)allowsWeakReference UNAVAILABLE_ATTRIBUTE;
- (BOOL)retainWeakReference UNAVAILABLE_ATTRIBUTE;

+ (BOOL)isSubclassOfClass:(Class)aClass;

+ (BOOL)resolveClassMethod:(SEL)sel OBJC_AVAILABLE(10.5, 2.0, 9.0, 1.0, 2.0);
+ (BOOL)resolveInstanceMethod:(SEL)sel OBJC_AVAILABLE(10.5, 2.0, 9.0, 1.0, 2.0);

+ (NSUInteger)hash;
+ (Class)superclass;
+ (Class)class OBJC_SWIFT_UNAVAILABLE("use 'aClass.self' instead");
+ (NSString *)description;
+ (NSString *)debugDescription;

@end

#endif

#endif
