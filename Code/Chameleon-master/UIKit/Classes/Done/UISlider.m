#import "UISlider.h"


@implementation UISlider

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; frame = (%.0f %.0f; %.0f %.0f); opaque = %@; layer = %@; value = %f>", [self className], self, self.frame.origin.x, self.frame.origin.y, self.frame.size.width, self.frame.size.height, (self.opaque ? @"YES" : @"NO"), self.layer, self.value];
}

- (UIImage *)minimumTrackImageForState:(UIControlState)state
{
    return nil;
}

- (void)setMinimumTrackImage:(UIImage *)image forState:(UIControlState)state
{
}

- (UIImage *)maximumTrackImageForState:(UIControlState)state
{
    return nil;
}

- (void)setMaximumTrackImage:(UIImage *)image forState:(UIControlState)state
{
}

- (UIImage *)thumbImageForState:(UIControlState)state
{
    return nil;
}

- (void)setThumbImage:(UIImage *)image forState:(UIControlState)state
{
}

- (UIImage *)currentMinimumTrackImage
{
    return nil;
}

- (UIImage *)currentMaximumTrackImage
{
    return nil;
}

- (UIImage *)currentThumbImage
{
    return nil;
}

@end
