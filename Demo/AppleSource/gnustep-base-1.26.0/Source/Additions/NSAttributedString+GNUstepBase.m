#import "common.h"
#import "Foundation/NSDebug.h"
#import "Foundation/NSException.h"
#import "GNUstepBase/NSAttributedString+GNUstepBase.h"
#import "GNUstepBase/NSDebug+GNUstepBase.h"

@implementation	NSAttributedString (GNUstepBase)
- (NSAttributedString*) attributedSubstringWithRange: (NSRange)aRange
{
    GSOnceMLog(@"This method is deprecated, use -attributedSubstringFromRange:");
    return [self attributedSubstringFromRange: aRange];
}
@end
