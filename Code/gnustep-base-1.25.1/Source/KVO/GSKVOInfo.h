//
//  GSKVOInfo.h
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Instances of this class are created to hold information about the
 * observers monitoring a particular object which is being observed.
 */
@interface    GSKVOInfo : NSObject
{
    NSObject            *instance;    // 监听的对象
    GSLazyRecursiveLock            *iLock;
    NSMapTable            *paths; // 监听的 path
}
- (GSKVOPathInfo *) lockReturningPathInfoForKey: (NSString *)key;
- (void*) contextForObserver: (NSObject*)anObserver ofKeyPath: (NSString*)aPath;
- (id) initWithInstance: (NSObject*)i;
- (NSObject*) instance;
- (BOOL) isUnobserved;
- (void) unlock;

NS_ASSUME_NONNULL_END
