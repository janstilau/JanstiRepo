#ifndef __NSUUID_h_GNUSTEP_BASE_INCLUDE
#define __NSUUID_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>
#import	<Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8,GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

typedef uint8_t gsuuid_t[16];

#if	defined(uuid_t)
#undef	uuid_t
#endif
#define	uuid_t	gsuuid_t


@class NSString;

@interface NSUUID : NSObject <NSCopying, NSCoding>
{
  @private
  gsuuid_t uuid;
}

+ (id)UUID;
- (id)initWithUUIDString:(NSString *)string;
- (id)initWithUUIDBytes:(gsuuid_t)bytes;
- (NSString *)UUIDString;
- (void)getUUIDBytes:(gsuuid_t)bytes;

@end

#if     defined(__cplusplus)
}
#endif

#endif

#endif /* __NSUUID_h_GNUSTEP_BASE_INCLUDE */
