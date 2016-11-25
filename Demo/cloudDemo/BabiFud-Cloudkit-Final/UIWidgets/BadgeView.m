/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "BadgeView.h"

@implementation BadgeView

- (void)setBadges:(NSArray *)badgeImages {
  for (UIView* v in self.subviews) {
    [v removeFromSuperview];
  }
  
  for (UIImage* image in badgeImages) {
    UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
    [self addSubview: imageView];
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  static CGSize badgeSize = {32., 45.};
  static CGFloat distance = 0.;
  
  CGRect f = CGRectMake(self.frame.size.width - badgeSize.width, 0, badgeSize.width, badgeSize.height);
  
  for (UIView* v in self.subviews) {
    v.frame = f;
    f.origin.x -= f.size.width + distance;
  }
}

- (void)prepareForInterfaceBuilder {
  [self setBadges: @[[UIImage imageNamed: @"man"], [UIImage imageNamed: @"woman"]]];
}

@end
