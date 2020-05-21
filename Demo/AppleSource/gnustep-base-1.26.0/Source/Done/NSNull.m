#import "common.h"
#import "Foundation/NSNull.h"

/**
    一个简简单单的对象 , 一个唯一标识, 作为 OC 里面的对于 NULL 的指示.
 */
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


