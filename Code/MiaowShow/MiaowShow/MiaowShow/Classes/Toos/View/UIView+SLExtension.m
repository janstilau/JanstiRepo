//
//  UIView+SLExtension.m
//
//  Created by Alin on 15/12/31.
//  Copyright © 2015年 Alin. All rights reserved.
//

#import "UIView+SLExtension.h"
#import <objc/runtime.h>

@implementation UIView (SLExtension)
- (void)setX:(CGFloat)x
{
    CGRect frame = self.frame;
    frame.origin.x = x;
    self.frame = frame;
}

- (void)setY:(CGFloat)y
{
    CGRect frame = self.frame;
    frame.origin.y = y;
    self.frame= frame;
}

- (void)setWidth:(CGFloat)width
{
    CGRect frame = self.frame;
    frame.size.width = width;
    self.frame = frame;
}

- (void)setHeight:(CGFloat)height
{
    CGRect frame = self.frame;
    frame.size.height = height;
    self.frame = frame;
}

- (void)setSize:(CGSize)size
{
    CGRect frame = self.frame;
    frame.size = size;
    self.frame = frame;
}

- (CGFloat)x
{
    return self.frame.origin.x;
}

- (CGFloat)y
{
    return self.frame.origin.y;
}

- (CGFloat)width
{
    return self.frame.size.width;
}

- (CGFloat)height
{
    return self.frame.size.height;
}

- (CGSize)size
{
    return self.frame.size;
}

- (CGFloat)centerX
{
    return self.center.x;
}

- (CGFloat)centerY
{
    return self.center.y;
}

- (void)setCenterX:(CGFloat)centerX
{
    CGPoint center = self.center;
    center.x = centerX;
    self.center = center;
}

- (void)setCenterY:(CGFloat)centerY
{
    CGPoint center = self.center;
    center.y = centerY;
    self.center = center;
}

- (BOOL)isShowingOnKeyWindow
{
    // 主窗口
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
    // 以主窗口左上角为坐标原点, 计算self的矩形框
    CGRect newFrame = [keyWindow convertRect:self.frame fromView:self.superview];
    CGRect winBounds = keyWindow.bounds;
    
    // 主窗口的bounds 和 self的矩形框 是否有重叠
    BOOL intersects = CGRectIntersectsRect(newFrame, winBounds);
    
    return !self.isHidden && self.alpha > 0.01 && self.window == keyWindow && intersects;
}

#pragma mark - 添加一个string的tag属性

static void *TagStrKey = &TagStrKey;
- (NSString *)tagStr
{
    return objc_getAssociatedObject(self, TagStrKey);
}

- (void)setTagStr:(NSString *)tagStr
{
    objc_setAssociatedObject(self, TagStrKey, tagStr, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)addHint:(NSString *)text {
    static int const hintTag = 90129;
    __block UILabel *hintLabel = nil;
    [self.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.tag == hintTag) {
            hintLabel = obj;
            *stop = YES;
        }
    }];
    
    if (hintLabel) {
        hintLabel.text = text;
        [hintLabel sizeToFit];
        return;
    }
    
    hintLabel = [[UILabel alloc] init];
    hintLabel.tag = hintTag;
    hintLabel.font = [UIFont systemFontOfSize:12];
    hintLabel.textColor = [UIColor redColor];
    hintLabel.text = text;
    hintLabel.x = 0;
    hintLabel.y = 0;
    [hintLabel sizeToFit];
    [self addSubview:hintLabel];
    
    self.layer.borderWidth = 1;
    self.layer.borderColor = [[UIColor colorWithRed:(arc4random() % 255) / 255.0 green:(arc4random() % 255) / 255.0 blue:(arc4random() % 255) / 255.0 alpha:1] CGColor];
}
@end
