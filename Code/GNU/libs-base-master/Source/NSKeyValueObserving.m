#import "common.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSIndexSet.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "GNUstepBase/Unicode.h"
#import "GNUstepBase/GSLock.h"
#import "GSInvocation.h"
#import "CacheObj.h"

#if defined(USE_LIBFFI)
#import "cifframe.h"
#endif

NSString *const NSKeyValueChangeIndexesKey = @"indexes";
NSString *const NSKeyValueChangeKindKey = @"kind";
NSString *const NSKeyValueChangeNewKey = @"new";
NSString *const NSKeyValueChangeOldKey = @"old";
NSString *const NSKeyValueChangeNotificationIsPriorKey = @"notificationIsPrior";

static NSRecursiveLock	*kvoLock = nil;
static NSMapTable	*classTable = 0;
static NSMapTable	*infoTable = 0;
static NSMapTable       *dependentKeyTable;

static id               null;

/*
 这里, setup 方法, 就是做一些初始化的操作而已.
 */
static inline void
setup()
{
}

@implementation NSObject (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext
{
    GSKVOInfo             *info;
    GSKVOReplacement      *r;
    NSKeyValueObservationForwarder *forwarder;
    NSRange               dot;
    [kvoLock lock];
    
    // Use the original class
    r = replacementForClass([self class]);
    
    /*
     每一个对象, 都在全局表里面, 有一个 GSKVOInfo 对象, 在里面, 存储着所有已经注册的观测项.
     */
    info = (GSKVOInfo*)[self observationInfo];
    if (info == nil)
    {
        info = [[GSKVOInfo alloc] initWithInstance: self];
        [self setObservationInfo: info];
        /*
         在这里, 进行了类的替换工作.
         */
        object_setClass(self, [r replacement]);
    }
    
    /*
     * Now add the observer.
     */
    dot = [aPath rangeOfString:@"."];
    if (dot.location != NSNotFound)
    {
        forwarder = [[NSKeyValueObservationForwarder alloc]
                     initWithKeyPath: aPath
                     ofObject: self
                     withTarget: anObserver
                     context: aContext];
        [info addObserver: anObserver
               forKeyPath: aPath
                  options: options
                  context: forwarder];
    }
    else
    {
        [r overrideSetterFor: aPath];
        [info addObserver: anObserver
               forKeyPath: aPath
                  options: options
                  context: aContext];
    }
    
    [kvoLock unlock];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
    GSKVOInfo	*info;
    id            forwarder;
    
    /*
     * Get the observation information and remove this observation.
     */
    info = (GSKVOInfo*)[self observationInfo];
    forwarder = [info contextForObserver: anObserver ofKeyPath: aPath];
    [info removeObserver: anObserver forKeyPath: aPath];
    if ([info isUnobserved] == YES)
    {
        /*
         * The instance is no longer being observed ... so we can
         * turn off key-value-observing for it.
         */
        object_setClass(self, [self class]);
        IF_NO_GC(AUTORELEASE(info);)
        [self setObservationInfo: nil];
    }
    if ([aPath rangeOfString:@"."].location != NSNotFound)
        [forwarder finalize];
}

@end

/**
 * NSArray objects are not observable, so the registration methods
 * raise an exception.
 */
@implementation NSArray (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext
{
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
     NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) addObserver: (NSObject*)anObserver
  toObjectsAtIndexes: (NSIndexSet*)indexes
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext
{
    NSUInteger i = [indexes firstIndex];
    
    while (i != NSNotFound)
    {
        NSObject *elem = [self objectAtIndex: i];
        
        [elem addObserver: anObserver
               forKeyPath: aPath
                  options: options
                  context: aContext];
        
        i = [indexes indexGreaterThanIndex: i];
    }
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
     NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) removeObserver: (NSObject*)anObserver
   fromObjectsAtIndexes: (NSIndexSet*)indexes
             forKeyPath: (NSString*)aPath
{
    NSUInteger i = [indexes firstIndex];
    
    while (i != NSNotFound)
    {
        NSObject *elem = [self objectAtIndex: i];
        
        [elem removeObserver: anObserver
                  forKeyPath: aPath];
        
        i = [indexes indexGreaterThanIndex: i];
    }
}

@end

/**
 * NSSet objects are not observable, so the registration methods
 * raise an exception.
 */
@implementation NSSet (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext
{
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
     NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
     NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

@end

@implementation NSObject (NSKeyValueObserverNotification)

- (void) willChangeValueForDependentsOfKey: (NSString *)aKey
{
    NSMapTable *keys = NSMapGet(dependentKeyTable, [self class]);
    
    if (keys != nil)
    {
        NSHashTable       *dependents = NSMapGet(keys, aKey);
        
        if (dependents != 0)
        {
            NSString              *dependentKey;
            NSHashEnumerator      dependentKeyEnum;
            
            dependentKeyEnum = NSEnumerateHashTable(dependents);
            while ((dependentKey = NSNextHashEnumeratorItem(&dependentKeyEnum)))
            {
                [self willChangeValueForKey: dependentKey];
            }
            NSEndHashTableEnumeration(&dependentKeyEnum);
        }
    }
}

- (void) didChangeValueForDependentsOfKey: (NSString *)aKey
{
    NSMapTable *keys = NSMapGet(dependentKeyTable, [self class]);
    
    if (keys != nil)
    {
        NSHashTable *dependents = NSMapGet(keys, aKey);
        
        if (dependents != nil)
        {
            NSString              *dependentKey;
            NSHashEnumerator      dependentKeyEnum;
            
            dependentKeyEnum = NSEnumerateHashTable(dependents);
            while ((dependentKey = NSNextHashEnumeratorItem(&dependentKeyEnum)))
            {
                [self didChangeValueForKey: dependentKey];
            }
            NSEndHashTableEnumeration(&dependentKeyEnum);
        }
    }
}

- (void) willChangeValueForKey: (NSString*)aKey
{
    GSKVOPathInfo *pathInfo;
    GSKVOInfo     *info;
    
    info = (GSKVOInfo *)[self observationInfo];
    if (info == nil)
    {
        return;
    }
    
    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil)
    {
        if (pathInfo->recursion++ == 0)
        {
            id    old = [pathInfo->change objectForKey: NSKeyValueChangeNewKey];
            
            if (old != nil)
            {
                /* We have set a value for this key already, so the value
                 * we set must now be the old value and we don't need to
                 * refetch it.
                 */
                [pathInfo->change setObject: old
                                     forKey: NSKeyValueChangeOldKey];
                [pathInfo->change removeObjectForKey: NSKeyValueChangeNewKey];
            }
            else if (pathInfo->allOptions & NSKeyValueObservingOptionOld)
            {
                /* We don't have an old value set, so we must fetch the
                 * existing value because at least one observation wants it.
                 */
                old = [self valueForKey: aKey];
                if (old == nil)
                {
                    old = null;
                }
                [pathInfo->change setObject: old
                                     forKey: NSKeyValueChangeOldKey];
            }
            [pathInfo->change setValue:
             [NSNumber numberWithInt: NSKeyValueChangeSetting]
                                forKey: NSKeyValueChangeKindKey];
            
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: YES];
        }
        [info unlock];
    }
    
    [self willChangeValueForDependentsOfKey: aKey];
}

- (void) didChangeValueForKey: (NSString*)aKey
{
    GSKVOPathInfo *pathInfo;
    GSKVOInfo	*info;
    
    info = (GSKVOInfo *)[self observationInfo];
    if (info == nil)
    {
        return;
    }
    
    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil)
    {
        if (pathInfo->recursion == 1)
        {
            id    value = [self valueForKey: aKey];
            
            if (value == nil)
            {
                value = null;
            }
            [pathInfo->change setValue: value
                                forKey: NSKeyValueChangeNewKey];
            [pathInfo->change setValue:
             [NSNumber numberWithInt: NSKeyValueChangeSetting]
                                forKey: NSKeyValueChangeKindKey];
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: NO];
        }
        if (pathInfo->recursion > 0)
        {
            pathInfo->recursion--;
        }
        [info unlock];
    }
    
    [self didChangeValueForDependentsOfKey: aKey];
}

- (void) didChange: (NSKeyValueChange)changeKind
   valuesAtIndexes: (NSIndexSet*)indexes
            forKey: (NSString*)aKey
{
    GSKVOPathInfo *pathInfo;
    GSKVOInfo	*info;
    
    info = [self observationInfo];
    if (info == nil)
    {
        return;
    }
    
    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil)
    {
        if (pathInfo->recursion == 1)
        {
            NSMutableArray        *array;
            
            array = [self valueForKey: aKey];
            [pathInfo->change setValue: [NSNumber numberWithInt: changeKind]
                                forKey: NSKeyValueChangeKindKey];
            [pathInfo->change setValue: indexes
                                forKey: NSKeyValueChangeIndexesKey];
            
            if (changeKind == NSKeyValueChangeInsertion
                || changeKind == NSKeyValueChangeReplacement)
            {
                [pathInfo->change setValue: [array objectsAtIndexes: indexes]
                                    forKey: NSKeyValueChangeNewKey];
            }
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: NO];
        }
        if (pathInfo->recursion > 0)
        {
            pathInfo->recursion--;
        }
        [info unlock];
    }
    
    [self didChangeValueForDependentsOfKey: aKey];
}

- (void) willChange: (NSKeyValueChange)changeKind
    valuesAtIndexes: (NSIndexSet*)indexes
             forKey: (NSString*)aKey
{
    GSKVOPathInfo *pathInfo;
    GSKVOInfo	*info;
    
    info = [self observationInfo];
    if (info == nil)
    {
        return;
    }
    
    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil)
    {
        if (pathInfo->recursion++ == 0)
        {
            NSMutableArray        *array;
            
            array = [self valueForKey: aKey];
            if (changeKind == NSKeyValueChangeRemoval
                || changeKind == NSKeyValueChangeReplacement)
            {
                [pathInfo->change setValue: [array objectsAtIndexes: indexes]
                                    forKey: NSKeyValueChangeOldKey];
            }
            [pathInfo->change setValue: [NSNumber numberWithInt: changeKind]
                                forKey: NSKeyValueChangeKindKey];
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: YES];
        }
        [info unlock];
    }
    
    [self willChangeValueForDependentsOfKey: aKey];
}

- (void) willChangeValueForKey: (NSString*)aKey
               withSetMutation: (NSKeyValueSetMutationKind)mutationKind
                  usingObjects: (NSSet*)objects
{
    GSKVOPathInfo *pathInfo;
    GSKVOInfo	*info;
    
    info = [self observationInfo];
    if (info == nil)
    {
        return;
    }
    
    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil)
    {
        if (pathInfo->recursion++ == 0)
        {
            id    set = objects;
            
            if (nil == set)
            {
                set = [self valueForKey: aKey];
            }
            [pathInfo->change setValue: [set mutableCopy] forKey: @"oldSet"];
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: YES];
        }
        [info unlock];
    }
    
    [self willChangeValueForDependentsOfKey: aKey];
}

- (void) didChangeValueForKey: (NSString*)aKey
              withSetMutation: (NSKeyValueSetMutationKind)mutationKind
                 usingObjects: (NSSet*)objects
{
    GSKVOPathInfo *pathInfo;
    GSKVOInfo	*info;
    
    info = [self observationInfo];
    if (info == nil)
    {
        return;
    }
    
    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil)
    {
        if (pathInfo->recursion == 1)
        {
            NSMutableSet  *oldSet;
            id            set = objects;
            
            oldSet = [pathInfo->change valueForKey: @"oldSet"];
            if (nil == set)
            {
                set = [self valueForKey: aKey];
            }
            [pathInfo->change removeObjectForKey: @"oldSet"];
            
            if (mutationKind == NSKeyValueUnionSetMutation)
            {
                set = [set mutableCopy];
                [set minusSet: oldSet];
                [pathInfo->change setValue:
                 [NSNumber numberWithInt: NSKeyValueChangeInsertion]
                                    forKey: NSKeyValueChangeKindKey];
                [pathInfo->change setValue: set
                                    forKey: NSKeyValueChangeNewKey];
            }
            else if (mutationKind == NSKeyValueMinusSetMutation
                     || mutationKind == NSKeyValueIntersectSetMutation)
            {
                [oldSet minusSet: set];
                [pathInfo->change setValue:
                 [NSNumber numberWithInt: NSKeyValueChangeRemoval]
                                    forKey: NSKeyValueChangeKindKey];
                [pathInfo->change setValue: oldSet
                                    forKey: NSKeyValueChangeOldKey];
            }
            else if (mutationKind == NSKeyValueSetSetMutation)
            {
                NSMutableSet      *old;
                NSMutableSet      *new;
                
                old = [oldSet mutableCopy];
                [old minusSet: set];
                new = [set mutableCopy];
                [new minusSet: oldSet];
                [pathInfo->change setValue:
                 [NSNumber numberWithInt: NSKeyValueChangeReplacement]
                                    forKey: NSKeyValueChangeKindKey];
                [pathInfo->change setValue: old
                                    forKey: NSKeyValueChangeOldKey];
                [pathInfo->change setValue: new
                                    forKey: NSKeyValueChangeNewKey];
            }
            
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: NO];
        }
        if (pathInfo->recursion > 0)
        {
            pathInfo->recursion--;
        }
        [info unlock];
    }
    [self didChangeValueForDependentsOfKey: aKey];
}

@end

@implementation NSObject (NSKeyValueObservingCustomization)

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)aKey
{
    return YES;
}

+ (void) setKeys: (NSArray*)triggerKeys
triggerChangeNotificationsForDependentKey: (NSString*)dependentKey
{
    NSMapTable    *affectingKeys;
    NSEnumerator  *enumerator;
    NSString      *affectingKey;
    
    setup();
    affectingKeys = NSMapGet(dependentKeyTable, self);
    if (!affectingKeys)
    {
        affectingKeys = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                         NSNonOwnedPointerMapValueCallBacks, 10);
        NSMapInsert(dependentKeyTable, self, affectingKeys);
    }
    enumerator = [triggerKeys objectEnumerator];
    while ((affectingKey = [enumerator nextObject]))
    {
        NSHashTable *dependentKeys = NSMapGet(affectingKeys, affectingKey);
        
        if (!dependentKeys)
        {
            dependentKeys = NSCreateHashTable(NSObjectHashCallBacks, 10);
            NSMapInsert(affectingKeys, affectingKey, dependentKeys);
        }
        NSHashInsert(dependentKeys, dependentKey);
    }
}

+ (NSSet*) keyPathsForValuesAffectingValueForKey: (NSString*)dependentKey
{
    NSString *selString = [NSString stringWithFormat: @"keyPathsForValuesAffecting%@",
                           [dependentKey capitalizedString]];
    SEL sel = NSSelectorFromString(selString);
    NSMapTable *affectingKeys;
    NSEnumerator *enumerator;
    NSString *affectingKey;
    NSMutableSet *keyPaths;
    
    if ([self respondsToSelector: sel])
    {
        return [self performSelector: sel];
    }
    
    affectingKeys = NSMapGet(dependentKeyTable, self);
    keyPaths = [[NSMutableSet alloc] initWithCapacity: [affectingKeys count]];
    enumerator = [affectingKeys keyEnumerator];
    while ((affectingKey = [enumerator nextObject]))
    {
        [keyPaths addObject: affectingKey];
    }
    
    return AUTORELEASE(keyPaths);
}

- (void*)observationInfo
{
    void	*info;
    
    [kvoLock lock];
    info = NSMapGet(infoTable, (void*)self);
    [kvoLock unlock];
    return info;
}

- (void) setObservationInfo: (void*)observationInfo
{
    setup();
    [kvoLock lock];
    if (observationInfo == 0)
    {
        NSMapRemove(infoTable, (void*)self);
    }
    else
    {
        NSMapInsert(infoTable, (void*)self, observationInfo);
    }
    [kvoLock unlock];
}

@end

