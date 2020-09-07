#ifndef _OBJC_PROTOCOL_H_
#define _OBJC_PROTOCOL_H_

#if !__OBJC__

// typedef Protocol is here:
#include <objc/runtime.h>


#elif __OBJC2__

#include <objc/NSObject.h>

// All methods of class Protocol are unavailable. 
// Use the functions in objc/runtime.h instead.

OBJC_AVAILABLE(10.0, 2.0, 9.0, 1.0, 2.0)
@interface Protocol : NSObject
@end


#else

#include <objc/Object.h>

OBJC_AVAILABLE(10.0, 2.0, 9.0, 1.0, 2.0)
@interface Protocol : Object
{
@private
    char *protocol_name OBJC2_UNAVAILABLE;
    struct objc_protocol_list *protocol_list OBJC2_UNAVAILABLE;
    struct objc_method_description_list *instance_methods OBJC2_UNAVAILABLE;
    struct objc_method_description_list *class_methods OBJC2_UNAVAILABLE;
}

/* Obtaining attributes intrinsic to the protocol */

- (const char *)name OBJC2_UNAVAILABLE;

/* Testing protocol conformance */

- (BOOL) conformsTo: (Protocol *)aProtocolObject OBJC2_UNAVAILABLE;

@end

#endif

#endif /* _OBJC_PROTOCOL_H_ */
