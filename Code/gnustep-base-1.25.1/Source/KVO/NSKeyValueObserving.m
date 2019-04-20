#import "common.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
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
#import "KVOClasses.h"

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
static Class		baseClass;
static id               null;

// 这个框架, 总的数据是存放到全局数据里的, 这里就是对于全局数据的存储工作.
static inline void
KVOSetup()
{
    if (nil == kvoLock)
    {
        [gnustep_global_lock lock]; // 这是一个全局锁, 在 NSObject 的 initialize 里面进行了初始化.
        if (nil == kvoLock)
        {
            kvoLock = [GSLazyRecursiveLock new];
            null = [[NSNull null] retain];
            classTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                          NSNonOwnedPointerMapValueCallBacks, 128);
            infoTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                         NSNonOwnedPointerMapValueCallBacks, 1024);
            dependentKeyTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                                 NSOwnedPointerMapValueCallBacks, 128);
            baseClass = NSClassFromString(@"GSKVOBase");
        }
        [gnustep_global_lock unlock];
    }
}

/*
 * Get a key name from a selector (setKey: or _setKey:) by
 * taking the key part and making the first letter lowercase.
 */
static NSString *newKey(SEL _cmd)
{
    const char	*name = sel_getName(_cmd);
    unsigned	len;
    NSString	*key;
    unsigned	i;
    
    if (0 == _cmd || 0 == (name = sel_getName(_cmd)))
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Missing selector name"];
    }
    len = strlen(name);
    if (*name == '_')
    {
        name++;
        len--;
    }
    if (len < 5 || name[len-1] != ':' || strncmp(name, "set", 3) != 0)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Invalid selector name"];
    }
    name += 3;			// Step past 'set'
    len -= 4;			// allow for 'set' and trailing ':'
    for (i = 0; i < len; i++)
    {
        if (name[i] & 0x80)
        {
            break;
        }
    }
    if (i == len)
    {
        char	buf[len];
        
        /* Efficient key creation for ascii keys
         */
        for (i = 0; i < len; i++) buf[i] = name[i];
        if (isupper(buf[0]))
        {
            buf[0] = tolower(buf[0]);
        }
        key = [[NSString alloc] initWithBytes: buf
                                       length: len
                                     encoding: NSASCIIStringEncoding];
    }
    else
    {
        unichar		u;
        NSMutableString	*m;
        NSString		*tmp;
        
        /*
         * Key creation for unicode strings.
         */
        m = [[NSMutableString alloc] initWithBytes: name
                                            length: len
                                          encoding: NSUTF8StringEncoding];
        u = [m characterAtIndex: 0];
        u = uni_tolower(u);
        tmp = [[NSString alloc] initWithCharacters: &u length: 1];
        [m replaceCharactersInRange: NSMakeRange(0, 1) withString: tmp];
        [tmp release];
        key = m;
    }
    return key;
}

// 这是一个全局函数, 为的就是获取一个类对应的 replaceMent.  GSKVOReplacement 是一个工具类.
static GSKVOReplacement *
replacementForClass(Class c)
{
    GSKVOReplacement *r;
    [kvoLock lock];
    r = (GSKVOReplacement*)NSMapGet(classTable, (void*)c);
    if (r == nil)
    {
        r = [[GSKVOReplacement alloc] initWithClass: c];
        NSMapInsert(classTable, (void*)c, (void*)r);
    }
    [kvoLock unlock];
    return r;
}

#if defined(USE_LIBFFI)
static void
cifframe_callback(ffi_cif *cif, void *retp, void **args, void *user)
{
    id            obj;
    SEL           sel;
    NSString	*key;
    Class		c;
    void		(*imp)(id,SEL,void*);
    
    obj = *(id *)args[0];
    sel = *(SEL *)args[1];
    c = [obj class];
    
    imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: sel];
    key = newKey(sel);
    if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
        // pre setting code here
        [obj willChangeValueForKey: key];
        ffi_call(cif, (void*)imp, retp, args);
        // post setting code here
        [obj didChangeValueForKey: key];
    }
    else
    {
        ffi_call(cif, (void*)imp, retp, args);
    }
    RELEASE(key);
}
#endif


@implementation NSObject (NSKeyValueObserving)

- (void) observeValueForKeyPath: (NSString*)aPath
                       ofObject: (id)anObject
                         change: (NSDictionary*)aChange
                        context: (void*)aContext
{
    [NSException raise: NSInvalidArgumentException
                format: @"-%@ cannot be sent to %@ ..."
     @" create an instance overriding this",
     NSStringFromSelector(_cmd), NSStringFromClass([self class])];
    return;
}

@end

@implementation NSObject (NSKeyValueObserverRegistration)

// NSObject addObserver

- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext
{
    GSKVOInfo             *info;
    GSKVOReplacement      *replaceMent;
    NSKeyValueObservationForwarder *forwarder;
    NSRange               dot;
    
    KVOSetup();
    [kvoLock lock]; // 每一次 addObserver, 都是一次全局的 lock. 不过, 这个函数其实调用的频率不太多, 而且一般主要就是在主线程.
    
    // 这里, 返回一个 GSKVOReplacement, 里面存放了 原始类, 生成的原始类的子类.
    // 在 replaceMent 的生成过程中, 其实会生成原始类对应的 kvo 类
    replaceMent = replacementForClass([self class]);
    
    // GSKVOInfo 中包装了监听相关的东西. 从里面可以找到监听对象, 监听路径, 以及监听者的各种信息.
    info = (GSKVOInfo*)[self observationInfo];
    if (info == nil)
    {
        info = [[GSKVOInfo alloc] initWithInstance: self]; // 在这个函数里面,
        [self setObservationInfo: info];
        object_setClass(self, [replaceMent replacement]); // 从这里, self 就变成了子类了.
    }
    
    /*
     * Now add the observer.
     */
    dot = [aPath rangeOfString:@"."]; // 如果添加的是 keyPath, 那么就调用 forwarder
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
        [replaceMent overrideSetterFor: aPath]; // overrideSetterFor 这一步, self 所变成的那个子类, 会添加 willChangeValueForKey setValue didChangeValueForKey 的调用了
        // 然后, 将关系完全传递给了 addObserver
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
        [self setObservationInfo: nil]; // 将自己的  ObservationInfo 设置为 nil, willChange, didChange 里面找不到对应的 info, 也就不会进行KVO了.
    }
    if ([aPath rangeOfString:@"."].location != NSNotFound)
        [forwarder finalize];
}

@end

@implementation NSObject (NSKeyValueObserverNotification)

// 这两个函数的意思就是说, 当一个key 值变化之后, 要通知依赖它的 key 值也进行变化. 依赖它的 key 值, 是专门要用 setKeys:triggerChangeNotificationsForDependentKey: 事先进行确定. 这个实现起来也很简单, 就是便利之后, 调用 willChangeValueForKey 就可以了. 那么这个东西应该怎么用呢. 应该在, setValue 的响应的代码中, 进行相应依赖的成员变量的变化, 这样相应的成员变量的通知的时候, 得到的值才是修改之后的值.
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
    
    info = (GSKVOInfo *)[self observationInfo];// 取出 self 相关的  GSKVOInfo
    if (info == nil)
    {
        return;
    }
    
    pathInfo = [info lockReturningPathInfoForKey: aKey]; // 取出 GSKVOInfo 中akey 相关的 pathinfo
    if (pathInfo != nil) // 在这一步, 仅仅是进行了 old value 的存储工作.
    {
        if (pathInfo->recursion++ == 0)
        {
            id    old = [pathInfo->change objectForKey: NSKeyValueChangeNewKey];
            
            // 这一步, 设置 old, 如果old有值, 代表着 NSKeyValueObservingOptionOld 一定在 allOptions 中.
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
            
            //现在 pathInfo->change 里面NSKeyValueChangeOldKey 的值已经搞定了.
            // 这里, prior 传递的是YES, notifyForKey 的实现中, 发现 NSKeyValueChangeNotificationIsPriorKey 这个key 每一个 observer 都没有注册的话, 就直接返回了. NSKeyValueChangeNotificationIsPriorKey 指的是, willChangeValueForKey 的时候, 就进行通知.
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


// array 相关
- (void) willChange: (NSKeyValueChange)changeKind
    valuesAtIndexes: (NSIndexSet*)indexes
             forKey: (NSString*)aKey
{
    GSKVOPathInfo *pathInfo;
    GSKVOInfo    *info;
    
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

// array 相关
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

// set 相关
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

// set 相关
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

/*
 Deprecated
 Use the method keyPathsForValuesAffectingValueForKey: instead.
 
 Configures the observed object to post change notifications for a given property if any of the properties specified in a given array changes.
 这个其实就是说, 当 dependentKey 修改的时候, triggerKeys 里面的内容, 也会收到响应的通知..
 */

+ (void) setKeys: (NSArray*)triggerKeys
triggerChangeNotificationsForDependentKey: (NSString*)dependentKey
{
    NSMapTable    *affectingKeys;
    NSEnumerator  *enumerator;
    NSString      *affectingKey;
    
    KVOSetup();
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




// 返回 info 数据, 这里也是进行了线程保护, 也有缓存的处理.
// 这里, 在系统的类里面, 有很多这种函数, 看似是类的方法, 实际上是操作的一个全局的内容
// associate 中, manager 的 alloc, dealloc, 仅仅是一个加锁的操作, 实际的是操作一个全局的 map, map 做缓存之用.
- (void*) observationInfo
{
    void	*info;
    
    KVOSetup();
    [kvoLock lock];
    info = NSMapGet(infoTable, (void*)self);
    AUTORELEASE(RETAIN((id)info));
    [kvoLock unlock];
    return info;
}

// 在自己的类里面, 想要实现分类中进行数据的操作, 一定需要一个全局数据进行操作. 这在 associate 也是同样的做法.
- (void) setObservationInfo: (void*)observationInfo
{
    KVOSetup();
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

