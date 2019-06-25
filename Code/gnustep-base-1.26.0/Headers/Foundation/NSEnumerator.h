#ifndef __NSEnumerator_h_GNUSTEP_BASE_INCLUDE
#define __NSEnumerator_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>


#if	defined(__cplusplus)
extern "C" {
#endif

@class GS_GENERIC_CLASS(NSArray, ElementT);

typedef struct
{
  unsigned long	state;
  __unsafe_unretained id		*itemsPtr;
  unsigned long	*mutationsPtr;
  unsigned long	extra[5];
} NSFastEnumerationState;

@protocol NSFastEnumeration
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *)state
				   objects: (__unsafe_unretained id[])stackbuf
				     count: (NSUInteger)len;
@end

@interface GS_GENERIC_CLASS(NSEnumerator, IterT) : NSObject <NSFastEnumeration>
- (GS_GENERIC_CLASS(NSArray, IterT) *) allObjects;
- (GS_GENERIC_TYPE(IterT)) nextObject;
@end

#if	defined(__cplusplus)
}
#endif

#endif /* __NSEnumerator_h_GNUSTEP_BASE_INCLUDE */
