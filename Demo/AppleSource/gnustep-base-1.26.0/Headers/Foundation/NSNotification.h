#ifndef __NSNotification_h_GNUSTEP_BASE_INCLUDE
#define __NSNotification_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSMapTable.h>
#import <GNUstepBase/GSBlocks.h>

@class NSString;
@class NSDictionary;
@class NSLock;
@class NSOperationQueue;

@interface NSNotification : NSObject <NSCopying, NSCoding>

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

#endif /*__NSNotification_h_GNUSTEP_BASE_INCLUDE */
