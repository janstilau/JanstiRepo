#import <AppKit/NSGestureRecognizer.h>

@implementation NSGestureRecognizer
- (id)initWithCoder: (NSCoder *)coder
{
  return nil; 
}

- (void)encodeWithCoder: (NSCoder *)coder
{
  return;
}

- (NSPoint)locationInView:(NSView *)view
{
  return NSZeroPoint;
}
@end
