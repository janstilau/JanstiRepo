#import "common.h"
#define	EXPOSE_NSNotification_IVARS	1
#import "Foundation/NSNotification.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"

@class	GSNotification;
@interface GSNotification : NSObject	// Help the compiler
@end

@implementation NSNotification

static Class	abstractClass = 0;
static Class	concreteClass = 0;
+ (NSNotification*) notificationWithName: (NSString*)name
                                  object: (id)object
                                userInfo: (NSDictionary*)info
{
    return [concreteClass notificationWithName: name
                                        object: object
                                      userInfo: info];
}

+ (NSNotification*) notificationWithName: (NSString*)name
                                  object: (id)object
{
    return [concreteClass notificationWithName: name
                                        object: object
                                      userInfo: nil];
}

- (NSUInteger) hash
{
    return [[self name] hash] ^ [[self object] hash];
}

- (id) init
{
    if ([self class] == abstractClass)
    {
        NSZone	*z = [self zone];
        
        DESTROY(self);
        self = (id)NSAllocateObject (concreteClass, 0, z);
    }
    return self;
}

- (BOOL) isEqual: (id)other
{
    NSNotification	*o;
    NSObject		*v1;
    NSObject		*v2;
    
    if (NO == [(o = other) isKindOfClass: [NSNotification class]]
        || ((v1 = [self name]) != (v2 = [o name]) && ![v1 isEqual: v2])
        || ((v1 = [self object]) != (v2 = [o object]) && ![v1 isEqual: v2])
        || ((v1 = [self userInfo]) != (v2 = [o userInfo]) && ![v1 isEqual: v2]))
    {
        return NO;
    }
    return YES;
}

/**
 *  Returns the notification name.
 */
- (NSString*) name
{
    [self subclassResponsibility: _cmd];
    return nil;
}

/**
 *  Returns the notification object.
 */
- (id) object
{
    [self subclassResponsibility: _cmd];
    return nil;
}

/**
 * Returns the notification user information.
 */
- (NSDictionary*) userInfo
{
    [self subclassResponsibility: _cmd];
    return nil;
}

@end
