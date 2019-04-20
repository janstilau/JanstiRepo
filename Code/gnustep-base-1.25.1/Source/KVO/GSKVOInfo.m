//
//  GSKVOInfo.m
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import "GSKVOInfo.h"

@implementation    GSKVOInfo

- (id) initWithInstance: (NSObject*)i
{
    instance = i;
    paths = NSCreateMapTable(NSObjectMapKeyCallBacks,
                             NSObjectMapValueCallBacks, 8);
    iLock = [GSLazyRecursiveLock new];
    return self;
}

- (NSObject*) instance
{
    return instance;
}

/* Locks receiver and returns path info on success, otherwise leaves
 * receiver unlocked and returns nil.
 * The returned path info is retained and autoreleased in case something
 * removes it from the receiver while it's being used by the caller.
 */
- (GSKVOPathInfo*) lockReturningPathInfoForKey: (NSString*)key
{
    GSKVOPathInfo *pathInfo;
    
    [iLock lock];
    pathInfo = AUTORELEASE(RETAIN((GSKVOPathInfo*)NSMapGet(paths, (void*)key)));
    if (pathInfo == nil)
    {
        [iLock unlock];
    }
    return pathInfo;
}

- (void) unlock
{
    [iLock unlock];
}

/*
 这里, 参数为了和前面的参数 label 区分, 都进行加了一个量词在前面.
 Info addObserver.
 */
- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext
{
    GSKVOPathInfo         *pathInfo;
    GSKVOObservation      *observation;
    unsigned              count;
    
    if ([anObserver respondsToSelector:
         @selector(observeValueForKeyPath:ofObject:change:context:)] == NO)
    {
        return;
    } // 如果, 监听者没有实现 observeValueForKeyPath, 直接不添加.
    
    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath); // 这个里面, 存放的是 path 相关的观察者.
    if (pathInfo == nil)
    {
        pathInfo = [GSKVOPathInfo new];
        // use immutable object for map key
        aPath = [aPath copy];
        NSMapInsert(paths, (void*)aPath, (void*)pathInfo);
        [pathInfo release];
        [aPath release];
    }
    
    observation = nil;
    pathInfo->allOptions = 0;
    count = [pathInfo->observations count];
    while (count-- > 0) // 如果, 这个 Observeration 是之前添加过得, 那么这次就是更新操作.
    {
        GSKVOObservation      *o;
        
        o = [pathInfo->observations objectAtIndex: count];
        if (o->observer == anObserver) // 更新 observer 的属性.
        {
            o->context = aContext;
            o->options = options;
            observation = o;
        }
        pathInfo->allOptions |= o->options;
    }
    if (observation == nil) // 这一次是添加操作.
    {
        observation = [GSKVOObservation new];
        GSAssignZeroingWeakPointer((void**)&observation->observer,
                                   (void*)anObserver);
        observation->context = aContext;
        observation->options = options;
        [pathInfo->observations addObject: observation];
        [observation release];
        pathInfo->allOptions |= options; // 记录一下 GSKVOObservation
    }
    
    //  NSKeyValueObservingOptionInitial --> If specified, a notification should be sent to the observer immediately, before the observer registration method even returns.
    // 如果这个值设置了, 那么在添加方法里面就应该把当前的值传过去, 所以, 可以认为, 当接收到这个通知的时候, 是一个初始值.
    if (options & NSKeyValueObservingOptionInitial)
    {
        /* If the NSKeyValueObservingOptionInitial option is set,
         * we must send an immediate notification containing the
         * existing value in the NSKeyValueChangeNewKey
         */
        [pathInfo->change setObject: [NSNumber numberWithInt: 1]
                             forKey:  NSKeyValueChangeKindKey];
        if (options & NSKeyValueObservingOptionNew)
        {
            id    value;
            
            value = [instance valueForKeyPath: aPath]; // 取得现在的属性状态.
            if (value == nil)
            {
                value = null;
            }
            [pathInfo->change setObject: value
                                 forKey: NSKeyValueChangeNewKey];
        }
        // 这里, 直接调用了 anObserver observeValueForKeyPath. 所以, 其实并不是通过 NSNotification 进行的消息的传递, 而是在KVO 的机制里面, 直接进行的函数调用.
        [anObserver observeValueForKeyPath: aPath
                                  ofObject: instance
                                    change: pathInfo->change
                                   context: aContext];
    }
    [iLock unlock];
}

/*
 * removes the observer
 */
- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath
{
    GSKVOPathInfo    *pathInfo;
    
    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo != nil)
    {
        unsigned  count = [pathInfo->observations count];
        
        pathInfo->allOptions = 0;
        while (count-- > 0)
        {
            GSKVOObservation      *o;
            
            o = [pathInfo->observations objectAtIndex: count];
            if (o->observer == anObserver || o->observer == nil)
            {
                [pathInfo->observations removeObjectAtIndex: count];
                if ([pathInfo->observations count] == 0)
                {
                    NSMapRemove(paths, (void*)aPath);
                }
            }
            else
            {
                pathInfo->allOptions |= o->options;
            }
        }
    }
    [iLock unlock];
}

- (void*) contextForObserver: (NSObject*)anObserver ofKeyPath: (NSString*)aPath
{
    GSKVOPathInfo    *pathInfo;
    void          *context = 0;
    
    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo != nil)
    {
        unsigned  count = [pathInfo->observations count];
        
        while (count-- > 0)
        {
            GSKVOObservation      *o;
            
            o = [pathInfo->observations objectAtIndex: count];
            if (o->observer == anObserver)
            {
                context = o->context;
                break;
            }
        }
    }
    [iLock unlock];
    return context;
}

- (void) dealloc
{
    if (paths != 0) NSFreeMapTable(paths);
    RELEASE(iLock);
    [super dealloc];
}


- (BOOL) isUnobserved
{
    BOOL    result = NO;
    
    [iLock lock];
    if (NSCountMapTable(paths) == 0)
    {
        result = YES;
    }
    [iLock unlock];
    return result;
}

@end
