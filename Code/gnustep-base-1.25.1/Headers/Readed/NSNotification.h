#ifndef __NSNotification_h_GNUSTEP_BASE_INCLUDE
#define __NSNotification_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSMapTable.h>
#import <GNUstepBase/GSBlocks.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;
@class NSDictionary;
@class NSLock;
@class NSOperationQueue;

@interface NSNotification : NSObject <NSCopying, NSCoding>

/*
 其实, NSNotification, 仅仅是一个包装体. 里面的元素很少, name, object, userInfo. 并且说, object 并不是说哪个对象发出了这个通知, 仅仅是 notificationCenter 就把那个object对象组装到这个 notification 的对象内的 object 属性而已. 不过从理解的角度上来说, 或者从 Apple 的文档描述来说, 这个 object 就是发送者, 而观察者仅仅在指定的发送者发送通知的时候, 才会进行回调的处理.
 */

/* Creating a Notification Object */
+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object;

+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object
			        userInfo: (NSDictionary*)info;

/* Querying a Notification Object */

- (NSString*) name;
- (id) object;
- (NSDictionary*) userInfo;

@end


#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
DEFINE_BLOCK_TYPE(GSNotificationBlock, void, NSNotification *);
#endif

@interface NSNotificationCenter : NSObject
{
#if	GS_EXPOSE(NSNotificationCenter)
@private
  void	*_table;
#endif
}

/*
 这个 NSNotificationCenter 这里实现的太复杂, 简单的说一下 Cocoa design pattern 的实现方式.
 在那本书里面, 用了一个字典存储所有的 observer, key 就是用的 notificationName, value 是 observer 为元素的可变数组.
 这样, 在 post 的时候, 相当于是首先根据 name, 读取到所有这个 name 相对应的 observer, 然后遍历, 如果这个 observer 中设置了监听某个特定的 object, 那么就做 object 的校验工作, 如果校验通过, 或者是不需要校验 object, 那么 observer 里面, 存储了 target 和 action, 直接通过 performSelector 进行方法的调用. NSNotification 作为方法的参数进行传递.
 这个实现简单, 并且能够符合现在文档里面对于 Notificaiton 机制的描述, 所以可以这样理解 center 内部的实现.
 */

+ (NSNotificationCenter*) defaultCenter;

- (void) addObserver: (id)observer
            selector: (SEL)selector
                name: (NSString*)name
              object: (id)object;

- (id) addObserverForName: (NSString *)name
                   object: (id)object 
                    queue: (NSOperationQueue *)queue 
               usingBlock: (GSNotificationBlock)block;
#endif

- (void) removeObserver: (id)observer;
- (void) removeObserver: (id)observer
                   name: (NSString*)name
                 object: (id)object;

- (void) postNotification: (NSNotification*)notification;
- (void) postNotificationName: (NSString*)name
                       object: (id)object;

- (void) postNotificationName: (NSString*)name
                       object: (id)object
                     userInfo: (NSDictionary*)info;

@end

#if	defined(__cplusplus)
}
#endif

#endif /*__NSNotification_h_GNUSTEP_BASE_INCLUDE */
