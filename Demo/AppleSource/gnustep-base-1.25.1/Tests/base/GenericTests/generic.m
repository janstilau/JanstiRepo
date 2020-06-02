#import "generic.h"

@interface NSObject (PretendToBeNSString)
- (int)length;
@end

@implementation NSObject(TestAdditions)
-(BOOL)testEquals:(id)anObject
{
  return ([self isEqual:anObject] && [anObject isEqual:self]);
}
- (int) length
{
  return 0;
}
-(BOOL)testForString
{
  return ([self isKindOfClass:[NSString class]] && [self length]);
}
@end