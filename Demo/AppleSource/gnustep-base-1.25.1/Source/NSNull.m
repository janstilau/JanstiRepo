#import "common.h"
#import "Foundation/NSNull.h"

/**
 * An object to use as a placeholder - in collections for instance.
 */
// 一个单例, 表示 nil 状态.
@implementation	NSNull

static NSNull	*null = 0;

+ (id) allocWithZone: (NSZone*)z
{
    return null;
}

+ (id) alloc
{
    return null;
}

+ (void) initialize
{
    if (null == 0)
    {
        null = (NSNull*)NSAllocateObject(self, 0, NSDefaultMallocZone());
        [[NSObject leakAt: &null] release];
    }
}

/**
 * Return an object that can be used as a placeholder in a collection.
 * This method always returns the same object.
 */
+ (NSNull*) null
{
    return null;
}

- (id) autorelease
{
    return self;
}

- (id) copyWithZone: (NSZone*)z
{
    return self;
}

- (id) copy
{
    return self;
}

- (void) dealloc
{
}

- (NSString*) description
{
    return @"<null>";
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    return self;
}

- (BOOL) isEqual: (id)other
{
    if (other == self)
        return YES;
    else
        return NO;
}

- (oneway void) release
{
}

- (id) retain
{
    return self;
}
@end


