#include "objc-private.h"

#undef id
#undef Class

#include <stdlib.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach-o/ldsyms.h>

#include "Protocol.h"
#include "NSObject.h"

/*
 这个类基本没有用, 因为所有的操作, 其实在 Runtime.mm 中实现的.
 */

// __IncompleteProtocol is used as the return type of objc_allocateProtocol().

// Old ABI uses NSObject as the superclass even though Protocol uses Object
// because the R/R implementation for class Protocol is added at runtime
// by CF, so __IncompleteProtocol would be left without an R/R implementation 
// otherwise, which would break ARC.

@interface __IncompleteProtocol : NSObject @end
@implementation __IncompleteProtocol 
#if __OBJC2__
// fixme hack - make __IncompleteProtocol a non-lazy class
+ (void) load { } 
#endif
@end


@implementation Protocol 

#if __OBJC2__
// fixme hack - make Protocol a non-lazy class
+ (void) load { } 
#endif


- (BOOL) conformsTo: (Protocol *)aProtocolObj
{
    return protocol_conformsToProtocol(self, aProtocolObj);
}

- (struct objc_method_description *) descriptionForInstanceMethod:(SEL)aSel
{
#if !__OBJC2__
    return lookup_protocol_method((struct old_protocol *)self, aSel, 
                                  YES/*required*/, YES/*instance*/, 
                                  YES/*recursive*/);
#else
    return method_getDescription(protocol_getMethod((struct protocol_t *)self, 
                                                     aSel, YES, YES, YES));
#endif
}

- (struct objc_method_description *) descriptionForClassMethod:(SEL)aSel
{
#if !__OBJC2__
    return lookup_protocol_method((struct old_protocol *)self, aSel, 
                                  YES/*required*/, NO/*instance*/, 
                                  YES/*recursive*/);
#else
    return method_getDescription(protocol_getMethod((struct protocol_t *)self, 
                                                    aSel, YES, NO, YES));
#endif
}

- (const char *)name
{
    return protocol_getName(self);
}

- (BOOL)isEqual:other
{
#if __OBJC2__
    // check isKindOf:
    Class cls;
    Class protoClass = objc_getClass("Protocol");
    for (cls = object_getClass(other); cls; cls = cls->superclass) {
        if (cls == protoClass) break;
    }
    if (!cls) return NO;
    // check equality
    return protocol_isEqual(self, other);
#else
    return [other isKindOf:[Protocol class]] && [self conformsTo: other] && [other conformsTo: self];
#endif
}

#if __OBJC2__
- (NSUInteger)hash
{
    return 23;
}
#else
- (unsigned)hash
{
    return 23;
}
#endif

@end
