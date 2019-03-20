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
 其实, NSNotification, 仅仅是一个包装体. 里面的元素很少, name, object, userInfo. 并且说, object 并不是说哪个对象发出了这个通知, 仅仅是 notificationCenter 就把那个object对象组装到这个 notification 的对象内的 object 属性而已.
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

+ (NSNotificationCenter*) defaultCenter;

- (void) addObserver: (id)observer
            selector: (SEL)selector
                name: (NSString*)name
              object: (id)object;
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
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
