#import "common.h"

#include <ctype.h>

#import "GNUstepBase/NSNumber+GNUstepBase.h"

/**
 * GNUstep specific (non-standard) additions to the NSNumber class.
 */
@implementation NSNumber(GNUstepBase)

+ (NSValue*) valueFromString: (NSString*)string
{
  /* FIXME: implement this better */
  const char *str;

  str = [string UTF8String];
  if (strchr(str, '.') != NULL || strchr(str, 'e') != NULL
    || strchr(str, 'E') != NULL)
    return [NSNumber numberWithDouble: atof(str)];
  else if (strchr(str, '-') >= 0)
    return [NSNumber numberWithInt: atoi(str)];
  else
    return [NSNumber numberWithUnsignedInt: atoi(str)];
}

@end
