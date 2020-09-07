//
//  CacheObj.h
//  Foundation
//
//  Created by JustinLau on 2020/9/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * This is the template class whose methods are added to KVO classes to
 * override the originals and make the swizzled class look like the
 * original class.
 */
@interface    GSKVOBase : NSObject
@end

/*
 * This holds information about a subclass replacing a class which is
 * being observed.
 */
@interface    GSKVOClazzReplacement : NSObject
{
    Class         original;       /* The original class */
    Class         replaceClazz;    /* The replacement class */
    NSMutableSet  *keys;          /* The observed setter keys */
}
- (id) initWithClass: (Class)aClass;
- (void) overrideSetterFor: (NSString*)aKey;
- (Class) replacement;
@end

/*
 * This is a placeholder class which has the abstract setter method used
 * to replace all setter methods in the original.
 */
@interface    GSKVOSetter : NSObject
- (void) setter: (void*)val;
- (void) setterChar: (unsigned char)val;
- (void) setterDouble: (double)val;
- (void) setterFloat: (float)val;
- (void) setterInt: (unsigned int)val;
- (void) setterLong: (unsigned long)val;
#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val;
#endif
- (void) setterShort: (unsigned short)val;
- (void) setterRange: (NSRange)val;
- (void) setterPoint: (NSPoint)val;
- (void) setterSize: (NSSize)val;
- (void) setterRect: (NSRect)rect;
@end

/* An instance of this records all the information for a single observation.
 */
@interface    GSKVOObservation : NSObject
{
@public
    NSObject      *observer;      // Not retained (zeroing weak pointer)
    void          *context;
    int           options;
}
@end

/* An instance of thsi records the observations for a key path and the
 * recursion state of the process of sending notifications.
 */
@interface    GSKVOPathInfo : NSObject
{
@public
    unsigned              recursion;
    unsigned              allOptions;
    NSMutableArray        *observations;
    NSMutableDictionary   *change;
}
- (void) notifyForKey: (NSString *)aKey ofInstance: (id)instance prior: (BOOL)f;
@end

/*
 * Instances of this class are created to hold information about the
 * observers monitoring a particular object which is being observed.
 */
@interface GSKVOInfo : NSObject
{
    NSObject            *instance;    // Not retained.
    NSRecursiveLock            *iLock;
    NSMapTable            *paths;
}
- (GSKVOPathInfo *) lockReturningPathInfoForKey: (NSString *)key;
- (void*) contextForObserver: (NSObject*)anObserver ofKeyPath: (NSString*)aPath;
- (id) initWithInstance: (NSObject*)i;
- (NSObject*) instance;
- (BOOL) isUnobserved;
- (void) unlock;

@end

@interface NSKeyValueObservationForwarder : NSObject
{
    id                                    target;
    NSKeyValueObservationForwarder        *child;
    void                                  *contextToForward;
    id                                    observedObjectForUpdate;
    NSString                              *keyForUpdate;
    id                                    observedObjectForForwarding;
    NSString                              *keyForForwarding;
    NSString                              *keyPathToForward;
}

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)object
            withTarget: (id)aTarget
               context: (void *)context;

- (void) keyPathChanged: (id)objectToObserve;
@end

NS_ASSUME_NONNULL_END
