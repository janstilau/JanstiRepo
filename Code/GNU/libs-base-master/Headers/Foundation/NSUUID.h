#ifndef __NSUUID_h_GNUSTEP_BASE_INCLUDE
#define __NSUUID_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>
#import	<Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8,GS_API_LATEST)

typedef uint8_t gsuuid_t[16];

#if	defined(uuid_t)
#undef	uuid_t
#endif
#define	uuid_t	gsuuid_t


/*
 一个很特殊的算法, 生成不重复字符串. 每次调用, 都会生成新的值.
 */
@class NSString;

@interface NSUUID : NSObject <NSCopying, NSCoding>
{
  @private
  gsuuid_t uuid;
}

+ (instancetype)UUID;
- (instancetype)initWithUUIDString:(NSString *)string;
- (instancetype)initWithUUIDBytes:(gsuuid_t)bytes;
- (NSString *)UUIDString;
- (void)getUUIDBytes:(gsuuid_t)bytes;

@end

#endif

#endif /* __NSUUID_h_GNUSTEP_BASE_INCLUDE */
