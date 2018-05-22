//
//  MCRedBadge.m
//  MCFriends
//
//  Created by bob on 14/11/15.
//  Copyright (c) 2014年 marujun. All rights reserved.
//

#import "MCRedBadge.h"

@implementation MCRedBadge

//code
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initWithBadgeLabel];
    }
    return self;
}

//XIB
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initWithBadgeLabel];
    }
    return self;
}

- (void)initWithBadgeLabel
{
    self.layer.masksToBounds = YES;
    self.backgroundColor = [UIColor redColor];
    self.userInteractionEnabled = false;
    
    _badgeNumLabel = [[UILabel alloc] init];
    _badgeNumLabel.font = [UIFont systemFontOfSize:12];
    _badgeNumLabel.textColor = [UIColor whiteColor];
    _badgeNumLabel.textAlignment = NSTextAlignmentCenter;
    _badgeNumLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:_badgeNumLabel];
}

- (void)setBadgeNum:(NSInteger)badgeNum
{
    float height = self.frame.size.height;
    self.layer.cornerRadius = height/2.0f;
    [_badgeNumLabel autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
    _badgeNumLabel.text = [NSString stringWithFormat:@"%@", @(badgeNum)];
    
    if (badgeNum > 0) {
        self.hidden = NO;
        if (badgeNum < 10) {
            [self autoSetDimension:ALDimensionWidth toSize:height];
        } else {
            float width = [_badgeNumLabel.text stringWidthWithFont:_badgeNumLabel.font height:height];
            
            [self autoSetDimension:ALDimensionWidth toSize:width + 8];
        }
    } else {
        self.hidden = YES;
    }
}

@end
