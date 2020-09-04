#ifndef __GSInvocation_h_GNUSTEP_BASE_INCLUDE
#define __GSInvocation_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSInvocation.h>

@class	NSMutableData;

typedef struct	{
    int		offset;
    unsigned	size;
    const char	*type;
    const char	*qtype;
    unsigned	align;
    unsigned	qual;
    BOOL		isReg;
} NSArgumentInfo;


@interface GSFFIInvocation : NSInvocation
{
@public
    uint8_t	_retbuf[32];	// Store return values of up to 32 bytes here.
    NSMutableData	*_frame;
}
@end

@interface GSFFCallInvocation : NSInvocation
{
}
@end

@interface GSDummyInvocation : NSInvocation
{
}
@end

@interface NSInvocation (DistantCoding)
- (BOOL) encodeWithDistantCoder: (NSCoder*)coder passPointers: (BOOL)passp;
@end

@interface NSMethodSignature (GNUstep)
- (const char*) methodType;
- (NSArgumentInfo*) methodInfo;
@end

extern void
GSFFCallInvokeWithTargetAndImp(NSInvocation *inv, id anObject, IMP imp);

extern void
GSFFIInvokeWithTargetAndImp(NSInvocation *inv, id anObject, IMP imp);

#define CLEAR_RETURN_VALUE_IF_OBJECT \
do {\
if (_validReturn && *_inf[0].type == _C_ID) \
{ \
RELEASE (*(id*) _retval); \
*(id*) _retval = nil; \
_validReturn = NO; \
}\
} while (0)

#define RETAIN_RETURN_VALUE IF_NO_GC(do { if (*_inf[0].type == _C_ID) RETAIN (*(id*) _retval);} while (0))                                         

#define	_inf	((NSArgumentInfo*)_info)

#endif
